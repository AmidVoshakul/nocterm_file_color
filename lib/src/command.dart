import 'file_config.dart';
import 'file_text_field_suggestion.dart';
import 'prompt_index_core.dart' show expandPromptTokens;

/// A slash command discovered from a project's command conventions
/// (`.claude/commands`, `.agents/commands`).
///
/// The package only reads the files; executing a command — permissions,
/// argument parsing, side effects — stays in the host application.
class CommandInfo {
  const CommandInfo({
    required this.name,
    required this.description,
    this.body,
    this.path,
  });

  /// Command name without the leading `/`; nested commands read `ns:name`
  /// (`sub/plan.md` → `sub:plan`).
  final String name;

  /// One-line summary from the frontmatter.
  final String description;

  /// Markdown body of the command file, when loaded: the prompt template the
  /// host runs after its own `$ARGUMENTS` substitution.
  final String? body;

  /// Path of the `*.md` file the command was read from.
  final String? path;

  /// Maps the command onto a menu suggestion with the package's default
  /// command style, or your own [style].
  ///
  /// The suggestion carries no `path`: only folder rows navigate, and a path
  /// here would drop the command from the menu while a folder is browsed.
  /// Read [CommandInfo.path] yourself to run the command.
  FileTextFieldSuggestion toSuggestion({FileStyle? style}) =>
      FileTextFieldSuggestion.command(
        name: name,
        description: description,
        style: style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          body == other.body &&
          path == other.path;

  @override
  int get hashCode => Object.hash(name, description, body, path);

  @override
  String toString() =>
      'CommandInfo(name: $name, description: $description, path: $path)';
}

/// Replaces every command token in [text] with the command's body.
///
/// Mirrors [expandSkillTokens]: the host calls this in `onSubmitted` before
/// running the prompt. A `$ARGUMENTS` in the body receives [arguments] — by
/// default the text typed after the last command token, so `/review fix auth`
/// fills `Scope: $ARGUMENTS` and consumes the typed tail; a body without the
/// placeholder keeps that tail appended (Gemini-CLI style). Pass [arguments]
/// explicitly to override, or `autoArguments: false` to substitute nothing.
/// Tokens without a command (or with an empty body) stay untouched, and the
/// `[tag]` delimiters the field inserts are consumed with the token.
String expandCommandTokens(
  String text,
  List<CommandInfo> commands, {
  String? arguments,
  bool autoArguments = true,
}) {
  final bodies = <String, String>{
    for (final command in commands)
      if (command.body != null && command.body!.trim().isNotEmpty)
        command.name: command.body!,
  };
  if (bodies.isEmpty) return text;
  return expandPromptTokens(
    text,
    bodies,
    const {},
    arguments: arguments ?? (autoArguments ? null : ''),
  );
}
