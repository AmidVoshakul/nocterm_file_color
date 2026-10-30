import 'package:nocterm/nocterm.dart';

import 'inline_token.dart';
import 'token_spans.dart';

/// Renders a plain [String] with arbitrary inline tokens colored.
///
/// This is a stateless, non-editable preview of colored token text. It has no
/// cursor, no selection, and no editing behavior. Use it to render colored
/// preview lines, for example in a read-only transcript or suggestion list.
///
/// Every occurrence of each [InlineToken.token] is painted with its
/// [InlineToken.style] over the base [style].
class TokenText extends StatelessComponent {
  /// Creates a colored token text preview.
  ///
  /// [text] is required. [tokens] are colored inline; every occurrence of each
  /// token string is painted with its style. [style] is the base text style.
  const TokenText({
    super.key,
    required this.text,
    this.tokens = const [],
    this.style,
    this.width,
    this.height,
    this.textAlign = TextAlign.left,
    this.softWrap = true,
    this.maxLines,
  });

  /// The text to render.
  final String text;

  /// Tokens to color inline. Every occurrence of each [InlineToken.token] is
  /// painted with its [InlineToken.style].
  final List<InlineToken> tokens;

  /// Base text style applied to the whole run; token styles override it for
  /// matching occurrences.
  final TextStyle? style;

  final double? width;
  final double? height;
  final TextAlign textAlign;
  final bool softWrap;
  final int? maxLines;

  @override
  Component build(BuildContext context) {
    final baseStyle = style ?? const TextStyle();
    return SizedBox(
      width: width,
      height: height,
      child: RichText(
        text: TextSpan(
          children: buildInlineSpans(
            text: text,
            tokens: tokens,
            selectionStart: 0,
            selectionEnd: 0,
            cursorOffset: null,
            cursorColor: Colors.black,
            baseStyle: baseStyle,
            selectionColor: Colors.black,
            cursorStyle: CursorStyle.block,
          ),
        ),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: TextOverflow.clip,
        maxLines: maxLines,
      ),
    );
  }
}
