import 'file_text_field_suggestion.dart';

/// One titled section of the `@`/`/` suggestion menu.
///
/// Several kinds may share a section, so files and folders can sit under a
/// single "Files & folders" heading.
class SuggestionMenuGroup {
  const SuggestionMenuGroup(
    this.title,
    this.kinds, {
    this.headerWhileBrowsed = true,
  });

  /// Heading text. Never shown when the menu has only one section, or when
  /// [SuggestionMenuGrouping.showHeaders] is off.
  final String title;

  /// Kinds this section collects, in the order they should appear.
  final List<FileTextFieldSuggestionKind> kinds;

  /// Whether the heading is drawn while the menu browses inside a directory.
  ///
  /// Off by default for the file/folder section, where the directory
  /// breadcrumb already occupies that line.
  final bool headerWhileBrowsed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuggestionMenuGroup &&
        other.title == title &&
        other.headerWhileBrowsed == headerWhileBrowsed &&
        _sameKinds(other.kinds, kinds);
  }

  @override
  int get hashCode =>
      Object.hash(title, headerWhileBrowsed, Object.hashAllUnordered(kinds));

  bool _sameKinds(
    List<FileTextFieldSuggestionKind> a,
    List<FileTextFieldSuggestionKind> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Order and headings of the suggestion menu sections.
///
/// The package ships no hardcoded layout: reorder, rename, merge or drop
/// sections freely. Kinds that no section lists are kept under
/// [ungroupedTitle] so nothing the host provides ever disappears.
class SuggestionMenuGrouping {
  const SuggestionMenuGrouping({
    this.groups = defaultGroups,
    this.showHeaders = true,
    this.ungroupedTitle = 'Other',
  });

  /// Built-in sections: files and folders, then agents, sessions, commands
  /// and skills.
  static const List<SuggestionMenuGroup> defaultGroups = [
    SuggestionMenuGroup('Files & folders', [
      FileTextFieldSuggestionKind.file,
      FileTextFieldSuggestionKind.folder,
    ], headerWhileBrowsed: false),
    SuggestionMenuGroup('Agents', [FileTextFieldSuggestionKind.agent]),
    SuggestionMenuGroup('Sessions', [FileTextFieldSuggestionKind.session]),
    SuggestionMenuGroup('Commands', [FileTextFieldSuggestionKind.command]),
    SuggestionMenuGroup('Skills', [FileTextFieldSuggestionKind.skill]),
  ];

  /// Sections in render order. A section with no visible items is skipped.
  final List<SuggestionMenuGroup> groups;

  /// Whether section headings are drawn at all.
  final bool showHeaders;

  /// Heading for kinds that no section claims.
  final String ungroupedTitle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuggestionMenuGrouping &&
        other.showHeaders == showHeaders &&
        other.ungroupedTitle == ungroupedTitle &&
        _sameGroups(other.groups, groups);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(groups), showHeaders, ungroupedTitle);

  bool _sameGroups(List<SuggestionMenuGroup> a, List<SuggestionMenuGroup> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A rendered section of the menu: its heading (or `null` when none is drawn)
/// and the items that belong to it, in order.
class SuggestionMenuGroupView {
  const SuggestionMenuGroupView(this.title, this.items);

  /// Heading text, or `null` when this section renders without one.
  final String? title;

  /// Items of this section.
  final List<FileTextFieldSuggestion> items;
}
