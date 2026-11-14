import 'command.dart';
import 'prompt_index_core.dart'
    show
        assetBody,
        firstWins,
        isMarkdownFile,
        mdNamespace,
        mdStem,
        AssetScanner,
        PromptAsset;
import 'skill_index.dart' show SkillFrontmatter, SkillFrontmatterParser;

/// Directories scanned for slash commands relative to `Directory.current`,
/// following the open agents convention: `<project>/.agents/commands`.
///
/// The package stays vendor-neutral — `.claude/`, `.opencode/`, `.chatorai/`
/// and global or home-based roots are the host's policy, added through the
/// `extraRoots` of any index or [PromptIndex.load].
const List<String> defaultCommandRoots = ['.agents/commands'];

/// Read-only discovery of slash commands from markdown files on disk.
///
/// One `*.md` file is one command: `review.md` is `/review`, and a nested
/// `sub/plan.md` is `/sub:plan` — the way Claude Code namespaces commands.
/// The file's frontmatter `description` (when present) feeds the menu and
/// query filtering; the body is the prompt template the host runs.
///
/// Mirrors [SkillIndex]: cached per root for [ttl], best-effort, no file
/// watching and no lifecycle management — the host owns the files.
class CommandIndex {
  CommandIndex({
    this.ttl = const Duration(minutes: 5),
    this.parser = SkillFrontmatter.parse,
  }) : _scanner = AssetScanner(ttl: ttl);

  /// How long a directory's listing stays cached.
  final Duration ttl;

  /// Frontmatter parser override; pass a `package:yaml` wrapper for full
  /// YAML, the default understands the common fields. A file without a
  /// frontmatter fence falls back to its raw text as the body; a fenced file
  /// the parser rejects yields no body.
  final SkillFrontmatterParser parser;

  final AssetScanner _scanner;

  /// Discovers commands under [root] plus [extraRoots], deduplicated by name
  /// with the first source winning.
  ///
  /// [root] is usually one of [defaultCommandRoots] (relative to the working
  /// directory); [extraRoots] may hold absolute paths. Returns an empty list
  /// when nothing is found — never throws.
  Future<List<CommandInfo>> commandsIn(
    String root, {
    List<String> extraRoots = const [],
    bool recursive = true,
  }) => firstWins(
    <String>[root, ...extraRoots],
    (dir) => _commandsInRoot(dir, recursive: recursive),
    (command) => command.name,
  );

  Future<List<CommandInfo>> _commandsInRoot(
    String root, {
    required bool recursive,
  }) async {
    final commands = <CommandInfo>[];
    for (final asset in await _scanner.scan(
      root,
      match: isMarkdownFile,
      recursive: recursive,
    )) {
      final command = _commandFrom(asset);
      if (command != null) commands.add(command);
    }
    return commands;
  }

  /// Drops every cached listing; the next [commandsIn] rescans the disk.
  void clear() => _scanner.clear();

  CommandInfo? _commandFrom(PromptAsset asset) {
    final parsed = parser(asset.path, asset.content);
    // The name comes from the path — `sub/plan.md` namespaces to `sub:plan` —
    // never from frontmatter, which command files conventionally omit.
    final base = mdStem(asset.relativePath);
    if (base.isEmpty) return null;
    return CommandInfo(
      name: '${mdNamespace(asset.relativePath)}$base',
      description: parsed?.description ?? '',
      body: assetBody(asset.content, parsed?.body),
      path: asset.path,
    );
  }
}
