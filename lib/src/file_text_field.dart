import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';
import 'file_opener.dart';
import 'file_tag.dart';

/// A [TextField] wrapper that displays attached files as colored inline tags.
///
/// Files can be attached via paste or programmatically. Their tokens (for
/// example, `[image 1]` or `[lib/main.dart]`) remain in the editing controller
/// and are rendered with per-file colors directly in the input line.
///
/// The host application retrieves the current attachments via
/// [FileTextFieldState.getAttachedFiles] (typically through a [GlobalKey]) and
/// receives change notifications through the `onFilesChanged` callback.
class FileTextField extends StatefulComponent {
  /// Creates a file-aware text field.
  ///
  /// All [TextField] parameters are forwarded to the internal [TextField].
  /// Additional file-specific parameters:
  /// - [fileConfig]: color scheme for file tags (defaults to [FileConfig.defaultConfig]).
  /// - [onFileClick]: called when a tag is tapped; defaults to opening the file location in the OS file manager.
  /// - [onFilesChanged]: called whenever the attachment list changes.
  const FileTextField({
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
    this.fileConfig,
    this.onFileClick,
    this.onFilesChanged,
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

  // File-specific parameters
  final FileConfig? fileConfig;
  final ValueChanged<FileInfo>? onFileClick;
  final ValueChanged<List<FileInfo>>? onFilesChanged;

  @override
  State<FileTextField> createState() => FileTextFieldState();
}

/// Mutable state for [FileTextField], exposed via [GlobalKey] for [getAttachedFiles].
class FileTextFieldState extends State<FileTextField> {
  late TextEditingController _controller;
  bool _controllerIsInternal = false;
  final List<FileInfo> _attachedFiles = [];
  int _imageCounter = 0;

  /// Returns the current list of attached files.
  ///
  /// Call this before sending the message to the AI model to include all
  /// attachments in the context.
  List<FileInfo> getAttachedFiles() => List.unmodifiable(_attachedFiles);

  /// Adds a file to the attachment list and inserts its token into the text.
  void attachFile(FileInfo file) {
    setState(() {
      if (file.type == FileType.image) {
        _imageCounter++;
        final style = _styleFor(file);
        file = file.copyWith(name: '${style.prefix ?? 'image'} $_imageCounter');
      }
      _attachedFiles.add(file);
      _insertToken(file);
      _notifyFilesChanged();
    });
  }

  /// Removes a file from the attachment list and its token from the text.
  void detachFile(FileInfo file) {
    setState(() {
      _attachedFiles.remove(file);
      _removeToken(file);
      _notifyFilesChanged();
    });
  }

  /// Clears all attachments and their tokens.
  void clearAttachments() {
    setState(() {
      _attachedFiles.clear();
      _imageCounter = 0;
      _controller.clear();
      _notifyFilesChanged();
    });
  }

  void _insertToken(FileInfo file) {
    final token = FileTag.tokenFor(file, _styleFor(file));
    final text = _controller.text;
    final insertOffset = _controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, insertOffset);
    final after = text.substring(insertOffset);
    final needsLeadingSpace =
        before.isNotEmpty && before.characters.last.trim().isNotEmpty;
    final needsTrailingSpace =
        after.isEmpty || after.characters.first.trim().isNotEmpty;
    final insertion =
        '${needsLeadingSpace ? ' ' : ''}$token${needsTrailingSpace ? ' ' : ''}';
    final newText = '$before$insertion$after';
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: insertOffset + insertion.length,
    );
  }

  void _removeToken(FileInfo file) {
    final token = FileTag.tokenFor(file, _styleFor(file));
    final text = _controller.text;
    final index = text.indexOf(token);
    if (index < 0) return;

    final range = _attachmentRemovalRange(text, index, index + token.length);
    final newText = text.substring(0, range.$1) + text.substring(range.$2);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: range.$1.clamp(0, newText.length),
    );
  }

  (int, int) _attachmentRemovalRange(String text, int start, int end) {
    if (start > 0 && text[start - 1].trim().isEmpty) {
      return (start - 1, end);
    }
    if (end < text.length && text[end].trim().isEmpty) {
      return (start, end + 1);
    }
    return (start, end);
  }

  FileStyle _styleFor(FileInfo file) =>
      component.fileConfig?.styleFor(file) ??
      FileConfig.defaultConfig().styleFor(file);

  void _notifyFilesChanged() {
    component.onFilesChanged?.call(List.unmodifiable(_attachedFiles));
  }

  void _syncAttachmentsFromText() {
    final text = _controller.text;
    final toRemove = _attachedFiles
        .where(
          (file) => !text.contains(FileTag.tokenFor(file, _styleFor(file))),
        )
        .toList();
    if (toRemove.isEmpty) return;

    _attachedFiles.removeWhere(toRemove.contains);
    _notifyFilesChanged();
  }

  void _handleControllerChanged() {
    component.onChanged?.call(_controller.text);
    _syncAttachmentsFromText();
    setState(() {});
  }

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
  void didUpdateComponent(FileTextField oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.controller != oldComponent.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_controllerIsInternal) _controller.dispose();
      _controllerIsInternal = component.controller == null;
      _controller = component.controller ?? TextEditingController();
      _controller.addListener(_handleControllerChanged);
      _syncAttachmentsFromText();
    }
  }

  /// Handles paste events: intercepts file paths and attaches them.
  bool _handlePaste(String pastedText) {
    final paths = _extractPaths(pastedText);
    if (paths.isNotEmpty) {
      for (final path in paths) {
        attachFile(FileInfo.fromPath(path));
      }
      return true; // Handled
    }
    return false; // Let TextField handle normal text paste
  }

  /// Handles key events: intercepts `@` for file mention and Ctrl+V for paste.
  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.backspace ||
        event.logicalKey == LogicalKey.delete) {
      if (_removeAttachmentAtSelection(
        backwards: event.logicalKey == LogicalKey.backspace,
      )) {
        return true;
      }
    }

    // @ key - trigger file mention (placeholder for future @-menu)
    if (event.logicalKey == LogicalKey.at && !event.isShiftPressed) {
      // TODO: Show @-menu for file picking
      return true;
    }
    // Ctrl+V - let TextField handle paste (which calls onPaste)
    if (event.logicalKey == LogicalKey.keyV && event.isControlPressed) {
      return false; // Let TextField handle it
    }
    return false;
  }

  bool _removeAttachmentAtSelection({required bool backwards}) {
    final text = _controller.text;
    final selection = _controller.selection;
    for (final file in _attachedFiles.toList()) {
      final token = FileTag.tokenFor(file, _styleFor(file));
      final tokenStart = text.indexOf(token);
      if (tokenStart < 0) continue;
      final tokenEnd = tokenStart + token.length;
      final touchesToken = selection.isCollapsed
          ? backwards
                ? selection.extentOffset > tokenStart &&
                      selection.extentOffset <= tokenEnd + 1
                : selection.extentOffset >= tokenStart &&
                      selection.extentOffset < tokenEnd
          : selection.start < tokenEnd && selection.end > tokenStart;
      if (!touchesToken) continue;

      final range = _attachmentRemovalRange(text, tokenStart, tokenEnd);
      final newText = text.substring(0, range.$1) + text.substring(range.$2);
      setState(() {
        _attachedFiles.remove(file);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: range.$1.clamp(0, newText.length),
        );
        _notifyFilesChanged();
      });
      return true;
    }
    return false;
  }

  /// Extracts file paths from pasted text (one per line or space-separated).
  List<String> _extractPaths(String text) {
    final lines = text.split('\n');
    final paths = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && _looksLikePath(trimmed)) {
        paths.add(trimmed);
      }
    }
    return paths;
  }

  bool _looksLikePath(String s) {
    // Heuristic: contains path separator or looks like a file with extension
    return s.contains('/') ||
        s.contains('\\') ||
        RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(s);
  }

  /// Attaches a file by path string (for programmatic use).
  void attachFilePath(String path) {
    attachFile(FileInfo.fromPath(path));
  }

  @override
  Component build(BuildContext context) {
    final showInlineTags = _attachedFiles.isNotEmpty && !component.obscureText;
    final textField = TextField(
      controller: _controller,
      focused: component.focused,
      onFocusChange: component.onFocusChange,
      decoration: component.decoration,
      style: showInlineTags
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
      onChanged: null, // Handled via controller listener
      onEditingComplete: component.onEditingComplete,
      onSubmitted: component.onSubmitted,
      onPaste: _handlePaste,
      onKeyEvent: _handleKeyEvent,
      enabled: component.enabled,
      cursorColor: component.cursorColor,
      cursorStyle: component.cursorStyle,
      cursorBlinkRate: component.cursorBlinkRate,
      selectionColor: component.selectionColor,
      showCursor: showInlineTags ? false : component.showCursor,
      width: component.width,
      height: component.height,
    );

    if (!showInlineTags) return textField;

    return Stack(
      children: [
        textField,
        GestureDetector(
          onTapDown: _handleInlineTapDown,
          child: RichText(
            text: TextSpan(children: _buildInlineSpans(context)),
            textAlign: component.textAlign,
            softWrap: component.maxLines != 1,
            overflow: TextOverflow.clip,
            maxLines: component.maxLines,
          ),
        ),
      ],
    );
  }

  void _handleInlineTapDown(TapDownDetails details) {
    final text = _controller.text;
    final contentPadding = component.decoration?.contentPadding;
    final hasDecoration =
        component.decoration?.border != null ||
        component.decoration?.fillColor != null;
    final leftInset = hasDecoration ? 1 + (contentPadding?.left ?? 1) : 0;
    final targetColumn = (details.localPosition.dx - leftInset).floor().clamp(
      0,
      text.length,
    );
    var column = 0;
    var offset = 0;

    for (final grapheme in text.characters) {
      if (column >= targetColumn) break;
      column += _terminalWidth(grapheme);
      offset += grapheme.length;
    }
    offset = offset.clamp(0, text.length);

    for (final file in _attachedFiles) {
      final token = FileTag.tokenFor(file, _styleFor(file));
      final tokenStart = text.indexOf(token);
      if (tokenStart >= 0 &&
          offset >= tokenStart &&
          offset < tokenStart + token.length) {
        if (component.onFileClick != null) {
          component.onFileClick!(file);
        } else {
          FileOpener.openLocation(file.path);
        }
        return;
      }
    }

    _controller.selection = TextSelection.collapsed(offset: offset);
    if (!component.focused) component.onFocusChange?.call(true);
  }

  int _terminalWidth(String grapheme) {
    final rune = grapheme.runes.first;
    if (rune >= 0x1100 &&
        (rune <= 0x115f ||
            rune == 0x2329 ||
            rune == 0x232a ||
            (rune >= 0x2e80 && rune <= 0xa4cf) ||
            (rune >= 0xac00 && rune <= 0xd7a3) ||
            (rune >= 0xf900 && rune <= 0xfaff) ||
            (rune >= 0xfe10 && rune <= 0xfe6f) ||
            (rune >= 0xff00 && rune <= 0xff60) ||
            (rune >= 0xffe0 && rune <= 0xffe6) ||
            (rune >= 0x1f300 && rune <= 0x1faff))) {
      return 2;
    }
    return 1;
  }

  List<InlineSpan> _buildInlineSpans(BuildContext context) {
    final text = _controller.text;
    final selection = _controller.selection;
    final selectionStart = selection.start.clamp(0, text.length);
    final selectionEnd = selection.end.clamp(0, text.length);
    final cursorOffset = component.focused && component.showCursor
        ? selection.extentOffset.clamp(0, text.length)
        : null;
    final cursorColor = component.cursorColor ?? TuiTheme.of(context).primary;
    final unstyledText = component.style ?? const TextStyle();
    final selectionColor =
        component.selectionColor ?? cursorColor.withOpacity(0.4);
    final attachments = _attachedFiles.map((file) {
      final style = _styleFor(file);
      return (token: FileTag.tokenFor(file, style), style: style.toTextStyle());
    }).toList();
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
          unstyledText,
          selectionStart,
          selectionEnd,
          selectionColor,
          cursorOffset,
          cursorColor,
        );
        offset = text.length;
      } else {
        if (nextIndex > offset) {
          _appendStyledText(
            spans,
            text.substring(offset, nextIndex),
            offset,
            unstyledText,
            selectionStart,
            selectionEnd,
            selectionColor,
            cursorOffset,
            cursorColor,
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
        );
        offset = nextIndex + attachment.token.length;
      }
    }

    if (text.isEmpty && cursorOffset == 0) {
      spans.add(
        TextSpan(text: ' ', style: _cursorTextStyle(unstyledText, cursorColor)),
      );
    } else if (cursorOffset == text.length) {
      spans.add(
        TextSpan(text: ' ', style: _cursorTextStyle(unstyledText, cursorColor)),
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
    Color selectionColor,
    int? cursorOffset,
    Color cursorColor,
  ) {
    var offset = startOffset;
    for (final grapheme in value.characters) {
      final selected =
          selectionStart < offset + grapheme.length && selectionEnd > offset;
      final style = selected
          ? baseStyle.copyWith(backgroundColor: selectionColor)
          : baseStyle;
      final displayStyle = cursorOffset == offset
          ? _cursorTextStyle(style, cursorColor)
          : style;
      spans.add(TextSpan(text: grapheme, style: displayStyle));
      offset += grapheme.length;
    }
  }

  TextStyle _cursorTextStyle(TextStyle style, Color cursorColor) {
    if (component.cursorStyle == CursorStyle.underline) {
      return TextStyle(
        color: style.color,
        backgroundColor: style.backgroundColor,
        fontWeight: style.fontWeight,
        decoration: TextDecoration.underline,
      );
    }
    if (component.cursorStyle == CursorStyle.blockOutline) {
      return TextStyle(
        color: style.color,
        backgroundColor: style.backgroundColor,
        fontWeight: style.fontWeight,
        decoration: TextDecoration.underline,
      );
    }
    return TextStyle(color: Colors.black, backgroundColor: cursorColor);
  }
}
