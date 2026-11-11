/// Readline-style cursor edge stepping for prompt inputs, shared by
/// multi-line fields.
///
/// Pressing Up/Down inside a draft must first snap the cursor to the text
/// edge before history navigation takes over — the same behavior readline
/// (zsh/bash) uses. Snapping applies only when the cursor sits on the first
/// (Up) or last (Down) physical line; otherwise `null` is returned so the
/// underlying text field performs a normal vertical move.
library;

/// Returns the offset to move the cursor to on an Up press, or `null` when
/// the gesture must fall through: offset 0 (or an empty text) means history
/// navigation owns the key, while a cursor below the first line means the
/// text field moves it up.
int? promptEdgeStepUp(String text, int cursorOffset) {
  if (cursorOffset <= 0) return null;
  final firstNewline = text.indexOf('\n');
  if (firstNewline != -1 && cursorOffset > firstNewline) return null;
  return 0;
}

/// Returns the offset to move the cursor to on a Down press, or `null` when
/// the gesture must fall through: offset at the text end means history
/// navigation owns the key, while a cursor above the last line means the
/// text field moves it down.
int? promptEdgeStepDown(String text, int cursorOffset) {
  if (cursorOffset >= text.length) return null;
  final lastNewline = text.lastIndexOf('\n');
  if (lastNewline != -1 && cursorOffset <= lastNewline) return null;
  return text.length;
}
