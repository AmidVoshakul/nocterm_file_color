import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';

/// The category of a suggestion shown by `FileTextField`.
///
/// The category describes how the selected item is represented. It does not
/// imply that the package executes agents or commands.
enum FileTextFieldSuggestionKind { file, folder, agent, command, session }

/// An item supplied by the host application for the `@` or `/` suggestion menu.
///
/// Files are added to `FileTextFieldState.getAttachedFiles()` when selected.
/// Folders, agents, and commands are inserted as colored tokens and remain the
/// host application's responsibility.
class FileTextFieldSuggestion {
  /// Creates a file suggestion. Selecting it attaches [file].
  ///
  /// [style] colors the inserted token; pass `config.styleFor(file)` from a
  /// `FileConfig` to reuse your application's file palette.
  factory FileTextFieldSuggestion.file(
    FileInfo file, {
    required FileStyle style,
    String? searchText,
    String? path,
  }) {
    return FileTextFieldSuggestion._(
      kind: FileTextFieldSuggestionKind.file,
      name: file.name,
      style: style,
      searchText: searchText ?? '${file.name} ${file.path}',
      file: file,
      prefix: null,
      path: path,
    );
  }

  /// Creates a folder suggestion. [name] should include its trailing `/`.
  ///
  /// [style] defaults to [defaultFolderStyle].
  const FileTextFieldSuggestion.folder({
    required this.name,
    FileStyle? style,
    this.searchText,
    this.prefix,
    this.path,
  }) : kind = FileTextFieldSuggestionKind.folder,
       style = style ?? defaultFolderStyle,
       file = null;

  /// Creates an agent suggestion. [name] omits the leading `@`.
  ///
  /// [style] defaults to [defaultAgentStyle].
  /// [prefix] allows customizing the inserted token prefix, e.g. '@', 'AI:', ''.
  /// When null, defaults to '@'.
  const FileTextFieldSuggestion.agent({
    required this.name,
    FileStyle? style,
    this.searchText,
    this.prefix,
    this.path,
  }) : kind = FileTextFieldSuggestionKind.agent,
       style = style ?? defaultAgentStyle,
       file = null;

  /// Creates a slash-command suggestion. [name] omits the leading `/`.
  ///
  /// [style] defaults to [defaultCommandStyle].
  const FileTextFieldSuggestion.command({
    required this.name,
    FileStyle? style,
    this.searchText,
    this.path,
  }) : kind = FileTextFieldSuggestionKind.command,
       style = style ?? defaultCommandStyle,
       file = null,
       prefix = null;

  /// Creates a session suggestion. [name] is the session identifier.
  ///
  /// [style] defaults to [defaultSessionStyle].
  /// [prefix] allows customizing the inserted token prefix, e.g. '@', '@session ', ''.
  /// When null, defaults to '@session '.
  const FileTextFieldSuggestion.session({
    required this.name,
    this.prefix,
    FileStyle? style,
    this.searchText,
    this.path,
  }) : kind = FileTextFieldSuggestionKind.session,
       style = style ?? defaultSessionStyle,
       file = null;
  const FileTextFieldSuggestion._({
    required this.kind,
    required this.name,
    required this.style,
    this.searchText,
    this.file,
    this.prefix,
    this.path,
  });

  /// Fallback token colors for suggestions that pass no [style].
  ///
  /// These mirror the palette `FileConfig.defaultConfig()` uses for file types,
  /// so a suggestion token and an attachment token look alike. Override per
  /// suggestion with the `style` argument.
  static const FileStyle defaultFolderStyle = FileStyle(
    text: Colors.brightYellow,
    background: Colors.yellow,
  );

  static const FileStyle defaultAgentStyle = FileStyle(
    text: Colors.brightCyan,
    background: Colors.cyan,
  );

  static const FileStyle defaultCommandStyle = FileStyle(
    text: Colors.brightMagenta,
    background: Colors.magenta,
  );

  static const FileStyle defaultSessionStyle = FileStyle(
    text: Colors.black,
    background: Colors.green,
  );

  /// Category of the suggestion.
  final FileTextFieldSuggestionKind kind;

  /// Name used for display and to build the inserted token.
  final String name;

  /// Style used for the inserted inline token.
  ///
  /// The host application owns menu styling; this style colors the token the
  /// package inserts, not the menu row. Defaults per kind, overridable.
  final FileStyle style;

  /// Optional additional searchable text. Defaults to [name].
  final String? searchText;

  /// Present only for file suggestions.
  final FileInfo? file;

  /// Optional prefix for the inserted token, used for session suggestions.
  /// When null, a default prefix for the kind is used.
  final String? prefix;

  /// Optional path for navigation, used to identify folder hierarchy.
  final String? path;

  /// Text shown in the menu.
  String get displayLabel {
    if (prefix != null) {
      return '$prefix$name';
    }
    return switch (kind) {
      FileTextFieldSuggestionKind.file => name,
      FileTextFieldSuggestionKind.folder => name,
      FileTextFieldSuggestionKind.agent => '@$name',
      FileTextFieldSuggestionKind.command => '/$name',
      FileTextFieldSuggestionKind.session => '@session $name',
    };
  }

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
