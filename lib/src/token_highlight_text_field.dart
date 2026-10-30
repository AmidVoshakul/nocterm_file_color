import 'package:nocterm/nocterm.dart';

import 'inline_token.dart';
import 'token_spans.dart';

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

class _TokenHighlightTextFieldState extends State<TokenHighlightTextField> {
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
    }
  }

  void _handleControllerChanged() {
    // Do not re-emit component.onChanged here: the inner TextField already
    // invokes it exactly once per controller change. This listener only
    // repaints the transparent overlay.
    setState(() {});
  }

  @override
  Component build(BuildContext context) {
    final showInlineTokens =
        component.tokens.isNotEmpty && !component.obscureText;
    final textField = TextField(
      controller: _controller,
      focused: component.focused,
      onFocusChange: component.onFocusChange,
      decoration: component.decoration,
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
      onEditingComplete: component.onEditingComplete,
      onSubmitted: component.onSubmitted,
      enabled: component.enabled,
      cursorColor: component.cursorColor,
      cursorStyle: component.cursorStyle,
      cursorBlinkRate: component.cursorBlinkRate,
      selectionColor: component.selectionColor,
      showCursor: showInlineTokens ? false : component.showCursor,
      width: component.width,
      height: component.height,
    );

    Component input = textField;
    if (showInlineTokens) {
      final text = _controller.text;
      final selection = _controller.selection;
      final cursorColor = component.cursorColor ?? TuiTheme.of(context).primary;
      final baseStyle = component.style ?? const TextStyle();
      final selectionColor =
          component.selectionColor ?? cursorColor.withOpacity(0.4);
      final cursorOffset = component.focused && component.showCursor
          ? selection.extentOffset.clamp(0, text.length)
          : null;

      input = Stack(
        children: [
          textField,
          RichText(
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
          ),
        ],
      );
    }

    return input;
  }
}
