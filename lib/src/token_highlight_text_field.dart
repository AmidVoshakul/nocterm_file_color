import 'package:nocterm/nocterm.dart';

import 'inline_token.dart';
import 'token_spans.dart';
import 'cursor_blink_mixin.dart';
import 'terminal_colors.dart';
import 'text_viewport.dart';

/// A [TextField] wrapper that colors arbitrary inline tokens.
///
/// Unlike [FileTextField], this component has no file-attachment bookkeeping,
/// no suggestion menu, and no paste handling. It only colors the supplied
/// [tokens] inline while leaving the controller's plain text and the inner
/// [TextField]'s behavior untouched. Each token entry colors one occurrence of
/// its token string; register one entry per colored label.
///
/// When [tokens] is empty or [obscureText] is true, the field renders as a
/// plain forwarded [TextField] with no overlay. Otherwise a transparent inner
/// [TextField] is overlaid with [RichText] so each token entry paints one
/// occurrence of its token with its [InlineToken.style], including selection
/// highlighting and cursor emulation when focused.
///
/// [onChanged] follows the plain [TextField] contract: it is invoked exactly
/// once per controller change (by the inner field, both for user edits and
/// programmatic controller updates). The wrapper's own controller listener
/// only repaints the inline overlay, so it does not re-emit the callback.
class TokenHighlightTextField extends StatefulComponent {
  /// Creates a token-highlighting text field.
  ///
  /// All [TextField] parameters are forwarded to the internal [TextField].
  /// Additional parameters:
  /// - [tokens]: the inline tokens to color; each entry colors one occurrence
  ///   of its token string.
  const TokenHighlightTextField({
    super.key,
    this.controller,
    this.focused = false,
    this.onFocusChange,
    this.decoration,
    this.style,
    this.placeholder,
    this.placeholderStyle,
    this.textAlign = TextAlign.left,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.maxLines = 1,
    this.minLines,
    this.maxLinesVisible = 8,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled = true,
    this.cursorColor,
    this.cursorStyle = CursorStyle.block,
    this.cursorBlinkRate,
    this.selectionColor,
    this.showCursor = true,
    this.width,
    this.height,
    this.tokens = const [],
  }) : assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(maxLinesVisible > 0, 'maxLinesVisible must be greater than 0'),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       ),
       assert(
         !obscureText || maxLines == 1,
         'Obscured fields cannot be multiline.',
       ),
       assert(maxLength == null || maxLength > 0);

  // TextField parameters (forwarded)
  final TextEditingController? controller;
  final bool focused;
  final ValueChanged<bool>? onFocusChange;
  final InputDecoration? decoration;
  final TextStyle? style;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final TextAlign textAlign;
  final bool readOnly;
  final bool obscureText;
  final String obscuringCharacter;
  final int? maxLines;
  final int? minLines;

  /// How many rows the input grows to before it scrolls.
  ///
  /// The field starts at a single row and grows with its content up to this
  /// many rows; beyond that the text scrolls and the caret is kept in view,
  /// so the field never grows without bound and breaks the surrounding
  /// layout. Only applies while [height] is unset — an explicit [height]
  /// governs the box instead.
  final int maxLinesVisible;

  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Color? cursorColor;
  final CursorStyle cursorStyle;
  final Duration? cursorBlinkRate;
  final Color? selectionColor;
  final bool showCursor;
  final double? width;
  final double? height;

  /// Tokens to color inline. Each entry colors one occurrence of its
  /// [InlineToken.token]: the leftmost match in the text not yet colored.
  /// Register one entry per colored label.
  final List<InlineToken> tokens;

  @override
  State<TokenHighlightTextField> createState() =>
      _TokenHighlightTextFieldState();
}

class _TokenHighlightTextFieldState extends State<TokenHighlightTextField>
    with
        CursorBlinkMixin<TokenHighlightTextField>,
        TextViewportMixin<TokenHighlightTextField> {
  late TextEditingController _controller;
  bool _controllerIsInternal = false;

  @override
  void initState() {
    super.initState();

    if (component.controller == null) {
      _controller = TextEditingController();
      _controllerIsInternal = true;
    } else {
      _controller = component.controller!;
    }

    _controller.addListener(_handleControllerChanged);
    _syncCursorBlink();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_controllerIsInternal) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateComponent(TokenHighlightTextField oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.controller != oldComponent.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_controllerIsInternal) _controller.dispose();
      _controllerIsInternal = component.controller == null;
      _controller = component.controller ?? TextEditingController();
      _controller.addListener(_handleControllerChanged);
      _syncCursorBlink();
      placeCaretInView();
    }
    _syncCursorBlink();
  }

  void _handleControllerChanged() {
    // Do not re-emit component.onChanged here: the inner TextField already
    // invokes it exactly once per controller change. This listener only
    // repaints the transparent overlay.
    _syncCursorBlink();
    setState(() {});
    placeCaretInView();
    resetViewportTargetColumn();
  }

  @override
  String get viewportText => _controller.text;

  @override
  TextSelection get viewportSelection => _controller.selection;

  @override
  set viewportSelection(TextSelection selection) =>
      _controller.selection = selection;

  @override
  int get viewportMaxLinesVisible => component.maxLinesVisible;

  @override
  bool get viewportFocused => component.focused;

  /// The boundary rows act like Home and End; mid-text arrows stay with
  /// Nocterm's own caret movement.
  bool _handleKeyEvent(KeyboardEvent event) {
    if (component.maxLines == 1) return false;
    return viewportHandleBoundaryArrow(event);
  }

  void _syncCursorBlink() {
    final showInlineTokens =
        component.tokens.isNotEmpty && !component.obscureText;
    syncCursorBlink(
      hasTokens: showInlineTokens,
      obscureText: component.obscureText,
      focused: component.focused,
      showCursor: component.showCursor,
      cursorBlinkRate: component.cursorBlinkRate,
    );
  }

  @override
  Component build(BuildContext context) {
    final showInlineTokens =
        component.tokens.isNotEmpty && !component.obscureText;
    // An explicit height governs the box; without one the field sizes
    // itself, and maxLinesVisible caps the growth.
    return component.height == null
        ? _buildViewportInput(showInlineTokens)
        : _buildFixedInput(showInlineTokens);
  }

  /// The inner field, shared by both input layouts.
  TextField _buildInnerTextField({
    required bool showInlineTokens,
    required double? width,
    required double? height,
    required InputDecoration? decoration,
  }) {
    return TextField(
      controller: _controller,
      focused: component.focused,
      onFocusChange: component.onFocusChange,
      decoration: decoration,
      style: showInlineTokens
          ? (component.style ?? const TextStyle()).copyWith(
              color: const Color.fromARGB(0, 0, 0, 0),
            )
          : component.style,
      placeholder: component.placeholder,
      placeholderStyle: component.placeholderStyle,
      textAlign: component.textAlign,
      readOnly: component.readOnly,
      obscureText: component.obscureText,
      obscuringCharacter: component.obscuringCharacter,
      maxLines: component.maxLines,
      minLines: component.minLines,
      maxLength: component.maxLength,
      onChanged: component.onChanged,
      onKeyEvent: _handleKeyEvent,
      onEditingComplete: component.onEditingComplete,
      onSubmitted: component.onSubmitted,
      enabled: component.enabled,
      cursorColor: TerminalColors.resolve(component.cursorColor),
      cursorStyle: component.cursorStyle,
      cursorBlinkRate: component.cursorBlinkRate,
      selectionColor: TerminalColors.resolve(component.selectionColor),
      showCursor: showInlineTokens ? false : component.showCursor,
      width: width,
      height: height,
    );
  }

  /// The layout for a host that sized the field itself.
  Component _buildFixedInput(bool showInlineTokens) {
    final textField = _buildInnerTextField(
      showInlineTokens: showInlineTokens,
      width: component.width,
      height: component.height,
      decoration: component.decoration,
    );
    if (!showInlineTokens) return textField;
    return Stack(
      children: [
        textField,
        if (component.width != null)
          SizedBox(width: component.width! - 1, child: _buildOverlayRichText())
        else
          _buildOverlayRichText(),
      ],
    );
  }

  /// The self-sizing layout: the field and its overlay scroll together inside
  /// a box capped at [maxLinesVisible] rows. The box itself comes from
  /// [TextViewportMixin]; here only the two layers are built.
  Component _buildViewportInput(bool showInlineTokens) {
    return buildViewportBox(
      width: component.width,
      decoration: component.decoration,
      focused: component.focused,
      maxLines: component.maxLines,
      layers: (fieldWidth, textWidth) {
        final overlay = showInlineTokens ? _buildOverlayRichText() : null;
        return (
          _buildInnerTextField(
            showInlineTokens: showInlineTokens,
            width: fieldWidth,
            height: null,
            decoration: null,
          ),
          overlay,
        );
      },
    );
  }

  /// The colored overlay, shared by both layouts.
  RichText _buildOverlayRichText() {
    final text = _controller.text;
    final selection = _controller.selection;
    // The overlay draws the package's own caret and selection, so both go
    // through the colour probe like every other colour the package emits.
    final cursorColor = TerminalColors.resolve(
      component.cursorColor ?? TuiTheme.of(context).primary,
    );
    final baseStyle = component.style ?? const TextStyle();
    final selectionColor =
        TerminalColors.resolve(component.selectionColor) ??
        cursorColor?.withOpacity(0.4);
    final cursorOffset =
        component.focused && component.showCursor && cursorVisible
        ? selection.extentOffset.clamp(0, text.length)
        : null;

    return RichText(
      // The key rides the paragraph: Nocterm's element exposes a render
      // object only on render object elements, and the tap origin is
      // measured from this box.
      key: viewportOverlayKey,
      text: TextSpan(
        children: buildInlineSpans(
          text: text,
          tokens: component.tokens,
          selectionStart: selection.start.clamp(0, text.length),
          selectionEnd: selection.end.clamp(0, text.length),
          cursorOffset: cursorOffset,
          cursorColor: cursorColor,
          baseStyle: baseStyle,
          selectionColor: selectionColor,
          cursorStyle: component.cursorStyle,
        ),
      ),
      textAlign: component.textAlign,
      softWrap: component.maxLines != 1,
      overflow: TextOverflow.clip,
      maxLines: component.maxLines,
    );
  }
}
