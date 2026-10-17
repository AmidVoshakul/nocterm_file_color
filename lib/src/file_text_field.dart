import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';
import 'file_opener.dart';
import 'file_tag.dart';

/// A [TextField] wrapper that displays attached files as colored inline tags.
///
/// Files can be attached via paste, `@`-mention, drag & drop, or programmatically.
/// Attached files are shown as clickable [FileTag]s in a tray above the text field
/// and are also inserted as tokens (e.g. `[image 1]`, `[lib/main.dart]`) into the
/// editing controller so the plain text reflects the attachments.
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
        file = file.copyWith(name: 'image $_imageCounter');
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
    final style =
        component.fileConfig?.styleFor(file) ??
        FileConfig.defaultConfig().styleFor(file);
    final token = FileTag.labelFor(file, style);
    final text = _controller.text;
    final selection = _controller.selection;
    final insertOffset = selection.start.clamp(0, text.length);
    final newText =
        '${text.substring(0, insertOffset)}[$token]${text.substring(insertOffset)}';
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: insertOffset + token.length + 2,
    );
  }

  void _removeToken(FileInfo file) {
    final style =
        component.fileConfig?.styleFor(file) ??
        FileConfig.defaultConfig().styleFor(file);
    final token = FileTag.labelFor(file, style);
    final text = _controller.text;
    final tokenWithBrackets = '[$token]';
    final index = text.indexOf(tokenWithBrackets);
    if (index >= 0) {
      final newText =
          text.substring(0, index) +
          text.substring(index + tokenWithBrackets.length);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: index.clamp(0, newText.length),
      );
    }
  }

  void _notifyFilesChanged() {
    component.onFilesChanged?.call(List.unmodifiable(_attachedFiles));
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

  void _handleControllerChanged() {
    component.onChanged?.call(_controller.text);
  }

  @override
  void didUpdateComponent(FileTextField oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.controller != oldComponent.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (component.controller == null) {
        _controller = TextEditingController();
        _controllerIsInternal = true;
      } else {
        _controller = component.controller!;
        _controllerIsInternal = false;
      }
      _controller.addListener(_handleControllerChanged);
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
    final config = component.fileConfig ?? FileConfig.defaultConfig();
    final tags = _attachedFiles.asMap().entries.map((entry) {
      final index = entry.key;
      final file = entry.value;
      final style = config.styleFor(file);
      return FileTag(
        key: ValueKey(file.path),
        file: file,
        style: style,
        index: file.type == FileType.image ? index + 1 : null,
        onTap: (f) => _handleTagTap(f),
      );
    }).toList();

    final tray = tags.isEmpty
        ? const SizedBox.shrink()
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: tags),
              const SizedBox(height: 4),
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tray,
        TextField(
          controller: _controller,
          focused: component.focused,
          onFocusChange: component.onFocusChange,
          decoration: component.decoration,
          style: component.style,
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
          showCursor: component.showCursor,
          width: component.width,
          height: component.height,
        ),
      ],
    );
  }

  void _handleTagTap(FileInfo file) {
    if (component.onFileClick != null) {
      component.onFileClick!(file);
    } else {
      FileOpener.openLocation(file.path);
    }
  }
}
