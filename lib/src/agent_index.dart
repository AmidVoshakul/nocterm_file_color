import 'agent.dart';
import 'prompt_index_core.dart'
    show
        assetBody,
        firstWins,
        isMarkdownFile,
        mdStem,
        AssetScanner,
        PromptAsset;
import 'skill_index.dart' show SkillFrontmatter, SkillFrontmatterParser;

/// Directories scanned for subagents relative to `Directory.current`,
/// following the open agents convention: `<project>/.agents/agents`.
///
/// The package stays vendor-neutral — `.claude/`, `.opencode/`, `.chatorai/`
/// and global or home-based roots are the host's policy, added through the
/// `extraRoots` of any index or [PromptIndex.load].
const List<String> defaultAgentRoots = ['.agents/agents'];

/// Read-only discovery of subagents from markdown files on disk.
///
/// One `*.md` file is one agent: `reviewer.md` is `@reviewer`. The frontmatter
/// `name` (when present) wins over the file stem; `description` feeds the menu
/// and query filtering; the body is the system prompt the host runs. Agent
/// frontmatter commonly carries host-specific fields (`tools:`, `model:`) —
/// the default parser reads what it knows and ignores the rest, and a host
/// with stricter needs passes its own `parser`.
///
/// Mirrors [SkillIndex]: cached per root for [ttl], best-effort, no file
/// watching and no lifecycle management — the host owns the files.
class AgentIndex {
  AgentIndex({
    this.ttl = const Duration(minutes: 5),
    this.parser = SkillFrontmatter.parse,
  }) : _scanner = AssetScanner(ttl: ttl);

  /// How long a directory's listing stays cached.
  final Duration ttl;

  /// Frontmatter parser override; pass a `package:yaml` wrapper for full
  /// YAML, the default understands the common fields. A file without a
  /// frontmatter fence falls back to its stem and raw text as the body; a
  /// fenced file the parser rejects yields the stem and no body.
  final SkillFrontmatterParser parser;

  final AssetScanner _scanner;

  /// Discovers agents under [root] plus [extraRoots], deduplicated by name
  /// with the first source winning.
  ///
  /// [root] is usually one of [defaultAgentRoots] (relative to the working
  /// directory); [extraRoots] may hold absolute paths. Returns an empty list
  /// when nothing is found — never throws.
  Future<List<AgentInfo>> agentsIn(
    String root, {
    List<String> extraRoots = const [],
    bool recursive = true,
  }) => firstWins(
    <String>[root, ...extraRoots],
    (dir) => _agentsInRoot(dir, recursive: recursive),
    (agent) => agent.name,
  );

  Future<List<AgentInfo>> _agentsInRoot(
    String root, {
    required bool recursive,
  }) async {
    final agents = <AgentInfo>[];
    for (final asset in await _scanner.scan(
      root,
      match: isMarkdownFile,
      recursive: recursive,
    )) {
      final agent = _agentFrom(asset);
      if (agent != null) agents.add(agent);
    }
    return agents;
  }

  /// Drops every cached listing; the next [agentsIn] rescans the disk.
  void clear() => _scanner.clear();

  AgentInfo? _agentFrom(PromptAsset asset) {
    final parsed = parser(asset.path, asset.content);
    // The explicit frontmatter `name` wins; the file stem is the fallback —
    // the skill parser's directory-name fallback does not apply here. An
    // agent without a description is still listed; its menu row simply shows
    // no summary.
    final name =
        SkillFrontmatter.frontmatterName(asset.content) ??
        mdStem(asset.relativePath);
    if (name.isEmpty) return null;
    return AgentInfo(
      name: name,
      description: parsed?.description ?? '',
      body: assetBody(asset.content, parsed?.body),
      path: asset.path,
    );
  }
}
