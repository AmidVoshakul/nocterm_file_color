import 'package:nocterm/nocterm.dart';

import 'inline_token.dart';
import 'terminal_colors.dart';
import 'token_spans.dart';

/// Renders a plain [String] with arbitrary inline tokens colored.
///
/// This is a stateless, non-editable preview of colored token text. It has no
/// cursor, no selection, and no editing behavior. Use it to render colored
/// preview lines, for example in a read-only transcript or suggestion list.
///
/// Each [InlineToken] entry colors one occurrence of its token string with
/// its [InlineToken.style] over the base [style]; register one entry per
/// colored label.
class TokenText extends StatelessComponent {
  /// Creates a colored token text preview.
  ///
  /// [text] is required. [tokens] are colored inline; each entry colors one
  /// occurrence of its token string. [style] is the base text style.
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

  /// Tokens to color inline. Each entry colors one occurrence of its
  /// [InlineToken.token]: the leftmost match in the text not yet colored.
  /// Register one entry per colored label.
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
            cursorColor: TerminalColors.resolve(Colors.black),
            baseStyle: baseStyle,
            selectionColor: TerminalColors.resolve(Colors.black),
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
