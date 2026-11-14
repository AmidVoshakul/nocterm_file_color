import 'file_config.dart';
import 'file_text_field_suggestion.dart';

/// A subagent discovered from a project's agent conventions
/// (`.claude/agents`, `.agents/agents`).
///
/// The package only reads the files; running an agent — permissions, tools,
/// model selection — stays in the host application.
class AgentInfo {
  const AgentInfo({
    required this.name,
    required this.description,
    this.body,
    this.path,
  });

  /// Agent name without the leading `@`, as the frontmatter spells it; the
  /// file's stem is the fallback.
  final String name;

  /// One-line summary from the frontmatter.
  final String description;

  /// Markdown body of the agent file, when loaded: the system prompt the host
  /// runs.
  final String? body;

  /// Path of the `*.md` file the agent was read from.
  final String? path;

  /// Maps the agent onto a menu suggestion with the package's default agent
  /// style, or your own [style].
  ///
  /// The suggestion carries no `path`: only folder rows navigate, and a path
  /// here would drop the agent from the menu while a folder is browsed. Read
  /// [AgentInfo.path] yourself to run the agent.
  FileTextFieldSuggestion toSuggestion({FileStyle? style}) =>
      FileTextFieldSuggestion.agent(
        name: name,
        description: description,
        style: style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          body == other.body &&
          path == other.path;

  @override
  int get hashCode => Object.hash(name, description, body, path);

  @override
  String toString() =>
      'AgentInfo(name: $name, description: $description, path: $path)';
}
