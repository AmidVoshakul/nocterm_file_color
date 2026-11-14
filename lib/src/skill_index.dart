import 'prompt_index_core.dart' show AssetScanner, firstWins;
import 'skill.dart';

/// The open `SKILL.md` standard (agentskills.io): `<project>/.agents/skills`,
/// scanned relative to `Directory.current`.
///
/// The package stays vendor-neutral — `.claude/`, `.opencode/`, `.chatorai/`
/// and global or home-based roots are the host's policy, added through the
/// `extraRoots` of any index or [PromptIndex.load].
const List<String> defaultSkillRoots = ['.agents/skills'];

/// Parses a `SKILL.md` file into a [SkillInfo].
///
/// Receives the file's path and full content, returns `null` when the file
/// carries no usable skill (missing frontmatter, missing `name`/`description`)
/// so discovery can skip it silently.
typedef SkillFrontmatterParser = SkillInfo? Function(
  String path,
  String content,
);

/// Zero-dependency `SKILL.md` frontmatter parser.
///
/// Understands the fields of the skill convention — `name`, `description`
/// (single-line, quoted, folded `>` and literal `|` blocks, plain multi-line
/// scalars) with `when_to_use` appended to the summary, and
/// `disable-model-invocation` in the YAML 1.1 truthy family — and degrades to
/// plain strings for anything fancier. Hosts wanting full YAML pass their own
/// parser to [SkillIndex].
class SkillFrontmatter {
  const SkillFrontmatter._();

  /// The frontmatter `name` field of [content], or `null` when it is absent.
  ///
  /// [parse] falls back to the directory name for skills (whose folder is
  /// the skill's identity); agent and command files name themselves by their
  /// file stem instead, so their indexes read the explicit field only.
  static String? frontmatterName(String content) {
    final fields = _fieldsOf(content);
    return fields?['name'];
  }

  /// Parses [content] of the `SKILL.md` at [path]; `null` when unusable.
  static SkillInfo? parse(String path, String content) {
    // Normalize line endings first: a CRLF file would otherwise carry `\r`
    // into every line, and straight into the body handed to the model.
    final lines = _normalizedLines(content);

    final fenced = _fencedLines(lines);
    if (fenced == null) return null;
    final (fmLines, body) = fenced;
    final fields = _parseFields(fmLines);
    final directory = _parentOf(path);
    final fallbackName = directory
        ?.split(RegExp(r'[/\\]'))
        .lastWhere((segment) => segment.isNotEmpty, orElse: () => directory);
    final name = fields['name']?.trim();
    final resolvedName = (name == null || name.isEmpty)
        ? fallbackName?.trim()
        : name;
    final description = fields['description']?.trim();
    if (resolvedName == null || resolvedName.isEmpty) return null;
    if (description == null || description.isEmpty) return null;

    return SkillInfo(
      name: resolvedName,
      // `when_to_use` extends the summary, the way Claude Code lists skills.
      description: _withWhenToUse(description, fields['when_to_use']),
      directory: directory,
      body: body.isEmpty ? null : body,
      disableModelInvocation: _isTruthy(fields['disable-model-invocation']),
    );
  }

  /// Appends the `when_to_use` hint to [description] when the frontmatter
  /// carries one; the combined text is what the menus show and filter on.
  static String _withWhenToUse(String description, String? whenToUse) {
    final hint = whenToUse?.trim();
    if (hint == null || hint.isEmpty) return description;
    return '$description $hint';
  }

  /// YAML 1.1 truthiness for the fields that carry it: `true` plus the
  /// `yes`/`on`/`1` family, in any letter case. Full YAML stays with a host's
  /// own parser.
  static bool _isTruthy(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null) return false;
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on' ||
        normalized == '1';
  }

  /// Directory holding the `SKILL.md`, or `null` when [path] has no parent.
  static String? _parentOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final cut = normalized.lastIndexOf('/');
    if (cut < 0) return null;
    return cut == 0 ? '/' : normalized.substring(0, cut);
  }

  /// Line endings normalized away, so a CRLF file never carries `\r` into a
  /// line — or straight into the body handed to the model.
  static List<String> _normalizedLines(String content) =>
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  /// The frontmatter lines and body of [lines], or `null` when the first two
  /// `---` fences are missing.
  static (List<String>, String)? _fencedLines(List<String> lines) {
    var fenceStart = -1;
    var fenceEnd = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() != '---') continue;
      if (fenceStart < 0) {
        fenceStart = i;
      } else {
        fenceEnd = i;
        break;
      }
    }
    if (fenceStart < 0 || fenceEnd < 0) return null;
    return (
      lines.sublist(fenceStart + 1, fenceEnd),
      lines.sublist(fenceEnd + 1).join('\n').trim(),
    );
  }

  /// The parsed flat fields of [content], or `null` when it is not fenced.
  static Map<String, String>? _fieldsOf(String content) {
    final fenced = _fencedLines(_normalizedLines(content));
    return fenced == null ? null : _parseFields(fenced.$1);
  }

  /// Reads flat `key: value` fields, joining indented continuation lines into
  /// the previous key (folded/literal blocks and plain multi-line scalars).
  static Map<String, String> _parseFields(List<String> lines) {
    final fields = <String, String>{};
    String? currentKey;
    final buffer = StringBuffer();
    var blockIndent = -1;

    void flush() {
      final key = currentKey;
      if (key == null) return;
      final value = _unquote(buffer.toString().trim());
      if (value.isNotEmpty) fields[key] = value;
      buffer.clear();
      currentKey = null;
      blockIndent = -1;
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final indent = line.length - line.trimLeft().length;

      // Inside a block scalar every deeper-indented (or blank) line is a
      // continuation — even when it looks like `key: something`, which is
      // how URLs and prose inside a folded description survive intact.
      final insideBlock =
          currentKey != null &&
          blockIndent >= 0 &&
          (indent >= blockIndent || trimmed.isEmpty);

      final isKey =
          !insideBlock &&
          !trimmed.startsWith('-') &&
          !trimmed.startsWith('#') &&
          RegExp(r'^[A-Za-z0-9_-]+:').hasMatch(trimmed);

      if (isKey) {
        flush();
        final colon = trimmed.indexOf(':');
        currentKey = trimmed.substring(0, colon).toLowerCase();
        final value = trimmed.substring(colon + 1).trim();
        // A block indicator or an empty value means the value lives on the
        // following, deeper-indented lines.
        if (_opensBlock(value)) {
          blockIndent = indent + 1;
        } else {
          blockIndent = -1;
          buffer.write(value);
        }
        continue;
      }

      if (currentKey == null) continue;
      if (insideBlock || trimmed.isEmpty) {
        if (buffer.isNotEmpty && trimmed.isNotEmpty) buffer.write(' ');
        buffer.write(trimmed);
      }
    }
    flush();
    return fields;
  }

  /// Whether a key's value opens a block scalar — an explicit indicator or an
  /// empty value, so the content follows on later indented lines.
  static bool _opensBlock(String value) =>
      value.isEmpty ||
      value == '>' ||
      value == '|' ||
      value == '>-' ||
      value == '>+' ||
      value == '|+';

  /// Strips a matching pair of surrounding single or double quotes.
  static String _unquote(String value) {
    if (value.length < 2) return value;
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}

/// Read-only discovery of skills from `SKILL.md` files on disk.
///
/// Mirrors [FileSystemCache]'s posture: every listing is cached for [ttl],
/// failures never propagate, and broken or empty files are skipped rather
/// than surfaced. The package does not watch directories or manage skill
/// files — the host owns their lifecycle.
class SkillIndex {
  SkillIndex({
    this.ttl = const Duration(minutes: 5),
    this.parser = SkillFrontmatter.parse,
  }) : _scanner = AssetScanner(ttl: ttl);

  /// How long a directory's listing stays cached.
  final Duration ttl;

  /// Frontmatter parser override; the zero-dependency default understands the
  /// common fields. Pass a `package:yaml` wrapper for full YAML.
  final SkillFrontmatterParser parser;

  final AssetScanner _scanner;

  /// Discovers skills under [root] plus [extraRoots], deduplicated by name
  /// with the first source winning.
  ///
  /// [root] is usually one of [defaultSkillRoots] (relative to the working
  /// directory); [extraRoots] may hold absolute paths (global config dirs).
  /// Returns an empty list when nothing is found — never throws.
  Future<List<SkillInfo>> skillsIn(
    String root, {
    List<String> extraRoots = const [],
    bool recursive = true,
  }) => firstWins(
    <String>[root, ...extraRoots],
    (dir) => _skillsInRoot(dir, recursive: recursive),
    (skill) => skill.name,
  );

  Future<List<SkillInfo>> _skillsInRoot(
    String root, {
    required bool recursive,
  }) async {
    final skills = <SkillInfo>[];
    for (final asset in await _scanner.scan(
      root,
      match: (path) => path.endsWith('SKILL.md'),
      recursive: recursive,
    )) {
      final skill = parser(asset.path, asset.content);
      if (skill != null) skills.add(skill);
    }
    return skills;
  }

  /// Drops every cached listing; the next [skillsIn] rescans the disk.
  void clear() => _scanner.clear();
}
