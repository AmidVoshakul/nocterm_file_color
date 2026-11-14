import 'file_config.dart';
import 'file_text_field_suggestion.dart';
import 'prompt_index_core.dart' show expandPromptTokens;

/// A skill: a named instruction pack, the `SKILL.md` convention used by
/// coding agents.
///
/// The package only reads skill metadata and (optionally) its markdown body;
/// execution stays in the host application. Build instances yourself, or let
/// [SkillIndex] discover them from disk (see `skill_index.dart`).
class SkillInfo {
  const SkillInfo({
    required this.name,
    required this.description,
    this.directory,
    this.body,
    this.disableModelInvocation = false,
  });

  /// Skill name, as written in the frontmatter and used by the `/name` token.
  final String name;

  /// One-line summary from the frontmatter; shown in suggestion menus and
  /// used for filtering.
  final String description;

  /// Absolute path of the directory holding `SKILL.md`, when discovered from
  /// disk.
  final String? directory;

  /// Markdown body of `SKILL.md` without its frontmatter, when loaded.
  ///
  /// Pass it to [expandSkillTokens] to substitute skill bodies into the sent
  /// prompt.
  final String? body;

  /// When true the skill is excluded from automatic model invocation; the
  /// host decides what that means for its guidance.
  final bool disableModelInvocation;

  /// Maps the skill onto a menu suggestion with the package's default skill
  /// style, or your own [style].
  ///
  /// The suggestion carries no `path`: only folder rows navigate, and a path
  /// here would drop the skill from the menu while a folder is browsed.
  FileTextFieldSuggestion toSuggestion({FileStyle? style}) =>
      FileTextFieldSuggestion.skill(
        name: name,
        description: description,
        style: style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          directory == other.directory &&
          body == other.body &&
          disableModelInvocation == other.disableModelInvocation;

  @override
  int get hashCode =>
      Object.hash(name, description, directory, body, disableModelInvocation);

  @override
  String toString() =>
      'SkillInfo(name: $name, description: $description, '
      'directory: $directory, disableModelInvocation: $disableModelInvocation)';
}

/// Replaces every `/name` token in [text] with the matching skill's [body].
///
/// Mirrors [getExpandedText] of collapsed pastes: the host calls this in
/// `onSubmitted` before sending the prompt, so the user typed `/skill` while
/// the model receives the full instructions. A `$ARGUMENTS` in the body
/// receives [arguments] — by default the text typed after the last skill
/// token, so `/plan fix auth` fills `Focus: $ARGUMENTS` and consumes the
/// typed tail; a body without the placeholder keeps that tail appended. Pass
/// [arguments] explicitly to override, or `autoArguments: false` to substitute
/// nothing. Tokens without a skill (or with an empty body) stay literal, and
/// names match on whitespace (or start/end of text) boundaries only, so
/// `/planning` never matches inside `/planning-notes`.
String expandSkillTokens(
  String text,
  List<SkillInfo> skills, {
  String? arguments,
  bool autoArguments = true,
}) {
  final bodies = <String, String>{
    for (final skill in skills)
      if (skill.body != null && skill.body!.trim().isNotEmpty)
        skill.name: skill.body!,
  };
  if (bodies.isEmpty) return text;
  return expandPromptTokens(
    text,
    const {},
    bodies,
    arguments: arguments ?? (autoArguments ? null : ''),
  );
}
