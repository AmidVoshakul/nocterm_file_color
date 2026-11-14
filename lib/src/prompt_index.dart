import 'agent.dart';
import 'agent_index.dart';
import 'command.dart';
import 'command_index.dart';
import 'file_config.dart';
import 'file_text_field_suggestion.dart';
import 'inline_token.dart';
import 'prompt_index_core.dart'
    show expandPromptTokens, findPromptTokens, firstWins, trailingTextAfter;
import 'skill.dart';
import 'skill_index.dart';

/// One index over every prompt asset family a coding-agent project may carry:
/// skills, commands and agents.
///
/// [load] scans the open `.agents/` standard once — TTL-cached and best-effort,
/// so a project without conventions simply loads nothing — plus whatever
/// roots the host adds through `extra*Roots` (`.claude/`, `.opencode/`, your
/// own vendor, global or plugin directories). Roots scan in the given order
/// and the first source defining a name wins. Afterwards [suggestionsFor]
/// feeds the `@`/`/` menus and [expandTokens] substitutes the picked token
/// bodies (with `$ARGUMENTS` for commands) before the prompt is sent:
///
/// ```dart
/// final index = PromptIndex();
/// await index.load(extraCommandRoots: ['.claude/commands']);
///
/// FileTextField(
///   onSuggestionsRequested: (trigger, query) =>
///       index.suggestionsFor(trigger),
///   onSubmitted: (text) => send(index.expandTokens(text)),
/// );
/// ```
///
/// File and folder suggestions stay with the host
/// (`FileSystemCache` + `FileTextFieldSuggestion.file`); this index owns the
/// text conventions only. Execution — running a command or an agent —
/// remains the host's business; the package only reads the files.
class PromptIndex {
  PromptIndex({
    this.ttl = const Duration(minutes: 5),
    this.parser = SkillFrontmatter.parse,
  }) : _skills = SkillIndex(ttl: ttl, parser: parser),
       _commands = CommandIndex(ttl: ttl, parser: parser),
       _agents = AgentIndex(ttl: ttl, parser: parser);

  /// How long each root's listing stays cached.
  final Duration ttl;

  /// Frontmatter parser override shared by the three indexes; pass a
  /// `package:yaml` wrapper for full YAML.
  final SkillFrontmatterParser parser;

  final SkillIndex _skills;
  final CommandIndex _commands;
  final AgentIndex _agents;

  /// Skills discovered by the last [load].
  List<SkillInfo> skills = [];

  /// Commands discovered by the last [load].
  List<CommandInfo> commands = [];

  /// Agents discovered by the last [load].
  List<AgentInfo> agents = [];

  /// Scans the open `.agents/` default roots — plus the per-family
  /// [extraSkillRoots], [extraCommandRoots] and [extraAgentRoots] a host adds
  /// (`.claude/`, `.opencode/`, its own vendor, global or plugin directories) —
  /// and populates [skills], [commands] and [agents]. Each extra list feeds
  /// one family only, so a shared plugin root never leaks its commands into
  /// the skill list. Never throws: a project without conventions loads empty
  /// lists.
  Future<void> load({
    List<String> extraSkillRoots = const [],
    List<String> extraCommandRoots = const [],
    List<String> extraAgentRoots = const [],
  }) async {
    skills = await firstWins(
      [...defaultSkillRoots, ...extraSkillRoots],
      (dir) => _skills.skillsIn(dir),
      (skill) => skill.name,
    );
    commands = await firstWins(
      [...defaultCommandRoots, ...extraCommandRoots],
      (dir) => _commands.commandsIn(dir),
      (command) => command.name,
    );
    agents = await firstWins(
      [...defaultAgentRoots, ...extraAgentRoots],
      (dir) => _agents.agentsIn(dir),
      (agent) => agent.name,
    );
  }

  /// Menu candidates for [trigger]: commands and skills for `/`, agents for
  /// `@`, nothing else. Merge your own file/folder suggestions into the
  /// result — the package filters by the query afterwards.
  List<FileTextFieldSuggestion> suggestionsFor(String trigger) {
    if (trigger == '/') {
      return [
        for (final command in commands) command.toSuggestion(),
        for (final skill in skills) skill.toSuggestion(),
      ];
    }
    if (trigger == '@') {
      return [for (final agent in agents) agent.toSuggestion()];
    }
    return const [];
  }

  /// Expands every command and skill token in [text] into its body, ready to
  /// send — commands additionally substitute `$ARGUMENTS`.
  ///
  /// With [autoArguments] (the default) a command's `$ARGUMENTS` becomes the
  /// text typed after the last command token — `/plan fix the auth bug` fills
  /// the body of `/plan` with `fix the auth bug`, the way Claude Code does it.
  /// Pass [arguments] explicitly to override that, or `autoArguments: false`
  /// to substitute nothing unless told.
  String expandTokens(
    String text, {
    String? arguments,
    bool autoArguments = true,
  }) {
    final commandBodies = <String, String>{
      for (final command in commands)
        if (command.body != null && command.body!.trim().isNotEmpty)
          command.name: command.body!,
    };
    final skillBodies = <String, String>{
      for (final skill in skills)
        if (skill.body != null && skill.body!.trim().isNotEmpty)
          skill.name: skill.body!,
    };
    // One pass over both families — a command's arguments can never swallow
    // a skill token typed after it, and each token captures its own tail.
    return expandPromptTokens(
      text,
      commandBodies,
      skillBodies,
      arguments: arguments ?? (autoArguments ? null : ''),
    );
  }

  /// The text typed after the last command token in [text], trimmed — what a
  /// command's `$ARGUMENTS` stands for under [expandTokens]' auto mode.
  String trailingArguments(String text) => trailingTextAfter(text, [
    for (final command in commands) command.name,
    for (final skill in skills) skill.name,
  ]);

  /// The command and skill tokens of [text] as [InlineToken]s, styled the way
  /// the field styles them — so a transcript can render a submitted prompt
  /// with the same colored tags the composer showed (`copilot` display),
  /// while [expandTokens] still hands the model the expanded prompt.
  ///
  /// Styles default to the package's per-kind plates; pass the styles your
  /// `onSuggestionsRequested` uses to keep the transcript identical to the
  /// input.
  List<InlineToken> inlineTokensFor(
    String text, {
    FileStyle? commandStyle,
    FileStyle? skillStyle,
  }) {
    // Commands win a cross-family name clash — the same precedence
    // [expandTokens] applies — so the plate and the expansion agree.
    final styles = <String, FileStyle>{};
    for (final command in commands) {
      styles.putIfAbsent(
        command.name,
        () => commandStyle ?? FileTextFieldSuggestion.defaultCommandStyle,
      );
    }
    for (final skill in skills) {
      styles.putIfAbsent(
        skill.name,
        () => skillStyle ?? FileTextFieldSuggestion.defaultSkillStyle,
      );
    }
    return [
      for (final match in findPromptTokens(text, styles.keys.toList()))
        InlineToken(token: match.full, style: styles[match.name]!),
    ];
  }

  /// Drops every cached listing; the next [load] rescans the disk.
  void clear() {
    _skills.clear();
    _commands.clear();
    _agents.clear();
  }
}
