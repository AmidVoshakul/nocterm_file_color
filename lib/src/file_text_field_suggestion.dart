import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';

/// The category of a suggestion shown by `FileTextField`.
///
/// The category describes how the selected item is represented. It does not
/// imply that the package executes agents or commands.
enum FileTextFieldSuggestionKind { file, folder, agent, command }

/// An item supplied by the host application for the `@` or `/` suggestion menu.
///
/// Files are added to `FileTextFieldState.getAttachedFiles()` when selected.
/// Folders, agents, and commands are inserted as colored tokens and remain the
/// host application's responsibility.
class FileTextFieldSuggestion {
  const FileTextFieldSuggestion._({
    required this.kind,
    required this.name,
    required this.style,
    this.searchText,
    this.file,
  });

  /// Creates a file suggestion. Selecting it attaches [file].
  factory FileTextFieldSuggestion.file(
    FileInfo file, {
    required FileStyle style,
    String? searchText,
  }) {
    return FileTextFieldSuggestion._(
      kind: FileTextFieldSuggestionKind.file,
      name: file.name,
      style: style,
      searchText: searchText ?? '${file.name} ${file.path}',
      file: file,
    );
  }

  /// Creates a folder suggestion. [name] should include its trailing `/`.
  const FileTextFieldSuggestion.folder({
    required this.name,
    required this.style,
    this.searchText,
  }) : kind = FileTextFieldSuggestionKind.folder,
       file = null;

  /// Creates an agent suggestion. [name] omits the leading `@`.
  const FileTextFieldSuggestion.agent({
    required this.name,
    required this.style,
    this.searchText,
  }) : kind = FileTextFieldSuggestionKind.agent,
       file = null;

  /// Creates a slash-command suggestion. [name] omits the leading `/`.
  const FileTextFieldSuggestion.command({
    required this.name,
    required this.style,
    this.searchText,
  }) : kind = FileTextFieldSuggestionKind.command,
       file = null;

  /// Category of the suggestion.
  final FileTextFieldSuggestionKind kind;

  /// Name used for display and to build the inserted token.
  final String name;

  /// Style used for the inserted inline token. The host application owns menu styling.
  final FileStyle style;

  /// Optional additional searchable text. Defaults to [name].
  final String? searchText;

  /// Present only for file suggestions.
  final FileInfo? file;

  /// Text shown in the menu.
  String get displayLabel => switch (kind) {
    FileTextFieldSuggestionKind.file => name,
    FileTextFieldSuggestionKind.folder => name,
    FileTextFieldSuggestionKind.agent => '@$name',
    FileTextFieldSuggestionKind.command => '/$name',
  };

  /// Text used by the package's case-insensitive query filter.
  String get searchableText =>
      '${searchText ?? name} $displayLabel'.toLowerCase();
}

/// Supplies suggestions for a trigger (`@` or `/`) and the current query.
///
/// Return the candidates available to the current application context. The
/// package filters the result by the query as well, so providers may return a
/// full list or a pre-filtered subset.
typedef FileTextFieldSuggestionProvider =
    List<FileTextFieldSuggestion> Function(String trigger, String query);

/// Builds an application-customized menu for the current suggestions.
///
/// The returned component is displayed above the input. Call [onSelected] when
/// the user chooses an item. The default menu is neutral and uncolored.
typedef FileTextFieldSuggestionMenuBuilder = Component Function(
  BuildContext context,
  List<FileTextFieldSuggestion> suggestions,
  int selectedIndex,
  ValueChanged<FileTextFieldSuggestion> onSelected,
);
