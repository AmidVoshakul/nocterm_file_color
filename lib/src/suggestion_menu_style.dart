import 'package:nocterm/nocterm.dart';

/// Visual style for the built-in `@`/`/` suggestion menu rendered by
/// [FileTextField].
///
/// Every field is optional and falls back to a sensible default, so a style
/// can override only what it needs. Pass `null` for [border] to render the
/// menu without a border, or build a [BoxBorder] with only the sides you want
/// (left, right, top, bottom, or any combination).
class SuggestionMenuStyle {
  const SuggestionMenuStyle({
    this.backgroundColor,
    this.border = defaultBorder,
    this.selectedBackgroundColor = Colors.cyan,
    this.selectedTextColor = Colors.black,
    this.itemTextColor = Colors.white,
    this.descriptionColor,
    this.highlightMarker = '',
    this.highlightMarkerColor,
    this.groupHeaderTextColor,
    this.groupHeaderBackgroundColor,
    this.padding = const EdgeInsets.symmetric(vertical: 1),
  });

  /// Default border: a gray box on all four sides (matches the previous
  /// built-in menu appearance).
  static const BoxBorder defaultBorder = BoxBorder(
    top: BorderSide(color: Colors.gray),
    right: BorderSide(color: Colors.gray),
    bottom: BorderSide(color: Colors.gray),
    left: BorderSide(color: Colors.gray),
  );

  /// Background color of the menu panel. `null` keeps the terminal default.
  final Color? backgroundColor;

  /// Border drawn around the menu panel. `null` renders no border; use
  /// [BoxBorder] sides to draw only left/right/both (or any combination).
  final BoxBorder? border;

  /// Background color of the highlighted row.
  final Color selectedBackgroundColor;

  /// Text color of the highlighted row.
  final Color selectedTextColor;

  /// Text color of non-highlighted rows.
  final Color itemTextColor;

  /// Text color for the optional description column (host-rendered menus).
  final Color? descriptionColor;

  /// Marker drawn before the highlighted row's label. Empty (default) draws
  /// nothing, keeping rows aligned without a leading glyph.
  final String highlightMarker;

  /// Color of [highlightMarker]. Defaults to [selectedTextColor].
  final Color? highlightMarkerColor;

  /// Text color of a section heading. `null` falls back to gray.
  final Color? groupHeaderTextColor;

  /// Background color of a section heading. `null` keeps the menu background.
  final Color? groupHeaderBackgroundColor;

  /// Inner padding of the menu panel. `EdgeInsets.zero` removes padding.
  final EdgeInsets padding;

  SuggestionMenuStyle copyWith({
    Color? backgroundColor,
    BoxBorder? border,
    bool clearBorder = false,
    Color? selectedBackgroundColor,
    Color? selectedTextColor,
    Color? itemTextColor,
    Color? descriptionColor,
    String? highlightMarker,
    Color? highlightMarkerColor,
    Color? groupHeaderTextColor,
    Color? groupHeaderBackgroundColor,
    EdgeInsets? padding,
  }) {
    return SuggestionMenuStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: clearBorder ? null : (border ?? this.border),
      selectedBackgroundColor:
          selectedBackgroundColor ?? this.selectedBackgroundColor,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      itemTextColor: itemTextColor ?? this.itemTextColor,
      descriptionColor: descriptionColor ?? this.descriptionColor,
      highlightMarker: highlightMarker ?? this.highlightMarker,
      highlightMarkerColor: highlightMarkerColor ?? this.highlightMarkerColor,
      padding: padding ?? this.padding,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuggestionMenuStyle &&
        other.backgroundColor == backgroundColor &&
        other.border == border &&
        other.selectedBackgroundColor == selectedBackgroundColor &&
        other.selectedTextColor == selectedTextColor &&
        other.itemTextColor == itemTextColor &&
        other.descriptionColor == descriptionColor &&
        other.highlightMarker == highlightMarker &&
        other.highlightMarkerColor == highlightMarkerColor &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    border,
    selectedBackgroundColor,
    selectedTextColor,
    itemTextColor,
    descriptionColor,
    highlightMarker,
    highlightMarkerColor,
    padding,
  );
}
