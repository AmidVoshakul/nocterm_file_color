/// Shared machinery behind the prompt-asset indexes ([SkillIndex],
/// [CommandIndex], [AgentIndex]): best-effort disk scanning with a TTL cache
/// and a symlink guard, plus the token-expansion regex all of them reuse.
///
/// Internal — not part of the public API.
library;

import 'dart:io';

/// One markdown file found under a scanned root.
class PromptAsset {
  const PromptAsset({
    required this.path,
    required this.content,
    required this.relativePath,
  });

  /// Path as the file system reported it.
  final String path;

  /// Full file text, unparsed.
  final String content;

  /// Path relative to the scanned root, with `/` separators — the namespace
  /// of nested assets (`sub/name.md` → `sub/name.md`).
  final String relativePath;
}

/// Scans a root for markdown assets, caching each listing for [ttl].
///
/// Every failure mode degrades to "nothing found": missing roots, unreadable
/// directories and unreadable files never throw into the caller. Symlinks
/// resolving outside the scanned root are skipped, and sibling directories
/// whose name merely starts with the root's never pass as "inside".
class AssetScanner {
  AssetScanner({this.ttl = const Duration(minutes: 5)});

  /// How long a root's listing stays cached.
  final Duration ttl;

  final Map<String, (DateTime, List<PromptAsset>)> _cache = {};

  /// Capped so a host scanning many differently-spelled roots cannot grow
  /// the cache without bound; the oldest listing is dropped first.
  static const _maxCacheEntries = 32;

  /// Cache key: the same root scanned recursively and shallowly are two
  /// different listings.
  String _cacheKey(String root, bool recursive) => '$root|$recursive';

  /// The real path of [directory] when that can be resolved, the literal
  /// path otherwise. Candidates are compared against the resolved root, so a
  /// symlinked component of the root (macOS temp dirs, a symlinked home
  /// directory, plugin roots behind a link) cannot smuggle a match through.
  String _resolvePath(Directory directory) {
    try {
      return directory.resolveSymbolicLinksSync();
    } on FileSystemException {
      return directory.absolute.path;
    }
  }

  /// Lists every file under [root] accepted by [match], reading each one.
  ///
  /// [match] decides which files are assets, seeing the path as the file
  /// system reported it.
  Future<List<PromptAsset>> scan(
    String root, {
    required bool Function(String path) match,
    bool recursive = true,
  }) async {
    final key = _cacheKey(root, recursive);
    final cached = _cache[key];
    final now = DateTime.now();
    if (cached != null && now.difference(cached.$1) < ttl) {
      return cached.$2;
    }

    final assets = <PromptAsset>[];
    try {
      final directory = Directory(root);
      if (!directory.existsSync()) return assets;
      final rootPath = _resolvePath(directory);
      // Compare against the root plus a separator, so a sibling directory
      // whose name merely starts with the root's (`skills_evil`) never
      // passes as "inside".
      final rootPrefix = rootPath.endsWith(Platform.pathSeparator)
          ? rootPath
          : '$rootPath${Platform.pathSeparator}';
      // Listed paths are prefixed with the root exactly as it was spelled
      // (relative roots stay relative), so the relative path comes from that
      // prefix — an absolute-path length would silently mismatch a relative
      // root and strip every nested directory.
      final listPrefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      await for (final entity in directory.list(recursive: recursive)) {
        if (entity is! File) continue;
        // Never follow a symlink out of the scanned root.
        if (!entity.resolveSymbolicLinksSync().startsWith(rootPrefix)) continue;
        // Relative path for namespacing. A direct child matches the prefix
        // and yields a bare name; the fallback only fires for a listed path
        // that does not start with the root as spelled.
        final relative = entity.path.startsWith(listPrefix)
            ? entity.path.substring(listPrefix.length).replaceAll('\\', '/')
            : entity.path.split(RegExp(r'[/\\]')).last;
        if (!match(entity.path)) continue;
        assets.add(
          PromptAsset(
            path: entity.path,
            content: await entity.readAsString(),
            relativePath: relative,
          ),
        );
      }
    } on Exception {
      // Best-effort discovery: a missing or unreadable root yields nothing.
      return assets;
    }

    if (_cache.length >= _maxCacheEntries && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = (now, assets);
    return assets;
  }

  /// Drops every cached listing; the next [scan] rescans the disk.
  void clear() => _cache.clear();
}

/// The alternation pattern matching `/name` tokens of [names] (already
/// longest-first) with optional `[tag]` delimiters.
RegExp _tokenPattern(List<String> names) => RegExp(
  '(?<=^|\\s)\\[?/(${names.map(RegExp.escape).join('|')})\\]?(?=\\s|\$)',
);

/// One `/name` token occurrence found in a prompt.
class PromptTokenMatch {
  const PromptTokenMatch({
    required this.name,
    required this.full,
    required this.start,
    required this.end,
  });

  /// The asset name the token refers to (`plan`).
  final String name;

  /// The token as it appears in the text, tag delimiters included
  /// (`[/plan]` or `/plan`).
  final String full;

  /// Where the token starts in the text.
  final int start;

  /// Where the token ends in the text.
  final int end;
}

/// Every `/name` token occurrence of [names] in [text], longest name first so
/// `/plan` never shadows `/planning-toolkit`. The shared matcher behind token
/// expansion and token coloring: a token counts only at whitespace or the
/// start/end of the text — so `/planning` never matches inside
/// `/planning-notes` — and the `[...]` tag delimiters the field inserts are
/// part of the match.
List<PromptTokenMatch> findPromptTokens(String text, List<String> names) {
  final usable = names.where((name) => name.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (text.isEmpty || usable.isEmpty) return const [];

  return [
    for (final match in _tokenPattern(usable).allMatches(text))
      PromptTokenMatch(
        name: match.group(1)!,
        full: match.group(0)!,
        start: match.start,
        end: match.end,
      ),
  ];
}

/// Replaces the `/name` tokens of [text] in one pass, substituting
/// `$ARGUMENTS` inside a body with [arguments].
///
/// The shared expansion behind [expandSkillTokens] and [expandCommandTokens]:
/// prompt-asset tokens of both families are matched together, so a command's
/// arguments can never swallow a skill token typed after it. A body that uses
/// `$ARGUMENTS` *consumes* the text typed after its token — `/plan fix auth`
/// with a `Focus: $ARGUMENTS` body expands to `Focus: fix auth`, the typed
/// text appearing once. When no body asks for the placeholder and
/// [appendUnmatchedArguments] is set, the typed tail joins the last body after
/// a blank line — the Gemini-CLI convention for argument-less command prompts
/// — so `/plan fix auth` still reaches the model as the plan body, a blank
/// line, then `fix auth`.
/// Only non-empty bodies replace; tokens without one stay literal. A name both
/// families claim takes the command's body.
String expandPromptTokens(
  String text,
  Map<String, String> commandBodies,
  Map<String, String> skillBodies, {
  String? arguments,
}) {
  final bodies = <String, String>{};
  for (final entry in commandBodies.entries) {
    if (entry.value.trim().isEmpty) continue;
    bodies[entry.key] = entry.value;
  }
  for (final entry in skillBodies.entries) {
    if (entry.value.trim().isEmpty) continue;
    bodies.putIfAbsent(entry.key, () => entry.value);
  }
  if (text.isEmpty || bodies.isEmpty) return text;

  final matches = findPromptTokens(text, bodies.keys.toList());
  if (matches.isEmpty) return text;

  // `arguments == null` is auto mode: each token captures the text typed
  // after it (up to the next token or the end of the prompt). An explicit
  // string applies to every body instead; the empty string from
  // `autoArguments: false` means "substitute nothing, capture nothing".
  final auto = arguments == null;
  final buffer = StringBuffer();
  var cursor = 0;
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    buffer.write(text.substring(cursor, match.start));
    final body = bodies[match.name]!;
    final spanEnd = i + 1 < matches.length ? matches[i + 1].start : text.length;
    final typed = text.substring(match.end, spanEnd).trim();
    var replacement = body.replaceAll(r'$ARGUMENTS', arguments ?? typed);
    cursor = match.end;
    if (body.contains(r'$ARGUMENTS')) {
      // The typed arguments belong inside the body: drop the span from the
      // token up to the next one (or the end of the prompt).
      cursor = spanEnd;
    } else if (auto && i == matches.length - 1 && typed.isNotEmpty) {
      // No body asks for `$ARGUMENTS`: the typed tail joins the last body
      // after a blank line — the Gemini-CLI convention for argument-less
      // command prompts — instead of dangling behind it.
      replacement = '$replacement\n\n$typed';
      cursor = text.length;
    }
    buffer.write(replacement);
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// The text typed after the last token of [names], trimmed — what a body's
/// `$ARGUMENTS` stands for under auto mode. Shared by the public expanders
/// so they cannot drift from the engine.
String trailingTextAfter(String text, List<String> names) {
  final matches = findPromptTokens(text, names);
  if (matches.isEmpty) return '';
  return text.substring(matches.last.end).trim();
}

/// Whether [path] names a markdown file — the asset test of every flat-file
/// family (commands, agents) the package indexes.
bool isMarkdownFile(String path) => path.endsWith('.md');

/// The file name of [relativePath] without its `.md` extension
/// (`sub/plan.md` → `plan`). Naming an asset after its file is the convention
/// of every markdown family the package indexes.
String mdStem(String relativePath) {
  final fileName = relativePath.split('/').last;
  return fileName.endsWith('.md')
      ? fileName.substring(0, fileName.length - 3)
      : fileName;
}

/// The `sub:` prefix a nested [relativePath] implies, or `''` at a root —
/// how a nested file namespaces its token (`sub/plan.md` → `/sub:plan`).
String mdNamespace(String relativePath) {
  final segments = relativePath.split('/');
  return segments.length > 1 ? '${segments.first}:' : '';
}

/// The body of a flat markdown asset: [parsedBody] when the file's frontmatter
/// parsed, or the whole [content] when it carries no fence at all (a plain
/// markdown prompt). A fenced-but-unparsable file yields `null`.
String? assetBody(String content, String? parsedBody) {
  if (parsedBody != null) return parsedBody;
  return content.trimLeft().startsWith('---') ? null : content.trim();
}

/// Scans [dirs] in order through [scan] and keeps the first asset per
/// [nameOf] — the single precedence rule every index family shares: earlier
/// roots win a name clash, later duplicates are dropped, empty paths skipped.
Future<List<T>> firstWins<T>(
  List<String> dirs,
  Future<List<T>> Function(String dir) scan,
  String Function(T) nameOf,
) async {
  final found = <String, T>{};
  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    for (final item in await scan(dir)) {
      found.putIfAbsent(nameOf(item), () => item);
    }
  }
  return found.values.toList();
}
