import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'inline_token.dart';
import 'terminal_colors.dart';

/// Builds inline spans for [text], coloring the text occurrences matched by
/// [tokens] with their [FileStyle]. Each [InlineToken] entry colors exactly
/// one occurrence: leftmost match wins and the entry is consumed. Register
/// one entry per colored label. Selection highlighting and block/underline
/// cursor emulation are applied on top of the token colors.
///
/// This is an internal implementation detail shared by
/// [TokenHighlightTextField], [TokenText], and [FileTextField]. It is not part
/// of the package's public API.
List<InlineSpan> buildInlineSpans({
  required String text,
  required List<InlineToken> tokens,
  required int selectionStart,
  required int selectionEnd,
  required int? cursorOffset,
  required Color? cursorColor,
  required TextStyle baseStyle,
  required Color? selectionColor,
  required CursorStyle cursorStyle,
}) {
  final attachments = tokens
      .map((token) => (token: token.token, style: token.style.toTextStyle()))
      .toList(growable: true);
  final spans = <InlineSpan>[];
  var offset = 0;

  while (offset < text.length) {
    var nextIndex = text.length;
    var nextAttachment = -1;
    for (var index = 0; index < attachments.length; index++) {
      final found = text.indexOf(attachments[index].token, offset);
      if (found >= 0 && found < nextIndex) {
        nextIndex = found;
        nextAttachment = index;
      }
    }

    if (nextAttachment == -1) {
      _appendStyledText(
        spans,
        text.substring(offset),
        offset,
        baseStyle,
        selectionStart,
        selectionEnd,
        selectionColor,
        cursorOffset,
        cursorColor,
        cursorStyle,
      );
      offset = text.length;
    } else {
      if (nextIndex > offset) {
        _appendStyledText(
          spans,
          text.substring(offset, nextIndex),
          offset,
          baseStyle,
          selectionStart,
          selectionEnd,
          selectionColor,
          cursorOffset,
          cursorColor,
          cursorStyle,
        );
      }
      final attachment = attachments.removeAt(nextAttachment);
      _appendStyledText(
        spans,
        attachment.token,
        nextIndex,
        attachment.style,
        selectionStart,
        selectionEnd,
        selectionColor,
        cursorOffset,
        cursorColor,
        cursorStyle,
      );
      offset = nextIndex + attachment.token.length;
    }
  }

  if (text.isEmpty && cursorOffset == 0) {
    spans.add(
      TextSpan(
        text: ' ',
        style: _cursorTextStyle(baseStyle, cursorColor, cursorStyle),
      ),
    );
  } else if (cursorOffset == text.length) {
    spans.add(
      TextSpan(
        text: ' ',
        style: _cursorTextStyle(baseStyle, cursorColor, cursorStyle),
      ),
    );
  }
  return spans;
}

void _appendStyledText(
  List<InlineSpan> spans,
  String value,
  int startOffset,
  TextStyle baseStyle,
  int selectionStart,
  int selectionEnd,
  Color? selectionColor,
  int? cursorOffset,
  Color? cursorColor,
  CursorStyle cursorStyle,
) {
  var offset = startOffset;
  for (final grapheme in value.characters) {
    final selected =
        selectionStart < offset + grapheme.length && selectionEnd > offset;
    final style = selected
        ? baseStyle.copyWith(
            backgroundColor:
                selectionColor ?? TerminalColors.resolve(Colors.grey),
          )
        : baseStyle;
    final displayStyle = cursorOffset == offset
        ? _cursorTextStyle(style, cursorColor, cursorStyle)
        : style;
    spans.add(TextSpan(text: grapheme, style: displayStyle));
    offset += grapheme.length;
  }
}

TextStyle _cursorTextStyle(
  TextStyle style,
  Color? cursorColor,
  CursorStyle cursorStyle,
) {
  if (cursorStyle == CursorStyle.underline) {
    return TextStyle(
      color: style.color ?? TerminalColors.resolve(Colors.white),
      backgroundColor: style.backgroundColor,
      fontWeight: style.fontWeight,
      decoration: TextDecoration.underline,
    );
  }
  // Block and block-outline cursors match Nocterm's own field cursor: dark
  // glyph over the caret color.
  if (cursorColor == null) {
    // No caret colour resolves — NO_COLOR. Reverse video keeps the caret
    // visible without emitting a colour.
    return TextStyle(
      color: style.color,
      backgroundColor: style.backgroundColor,
      reverse: true,
    );
  }
  return TextStyle(
    color: TerminalColors.resolve(Colors.black),
    backgroundColor: cursorColor,
  );
}
