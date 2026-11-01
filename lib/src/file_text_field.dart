import 'dart:async';

import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';
import 'file_opener.dart';
import 'file_tag.dart';
import 'file_text_field_suggestion.dart';
import 'suggestion_menu_style.dart';
import 'inline_token.dart';
import 'token_spans.dart';

// ---------------------------------------------------------------------------
// Internal token model
// ---------------------------------------------------------------------------

/// Where the `@`/`/` suggestion menu is rendered.
enum SuggestionMenuPlacement {
  /// Rendered by `FileTextField` directly above the input (default).
  inline,

  /// Not rendered by `FileTextField` at all: the host draws it wherever its
  /// layout needs it, from [FileTextFieldState.visibleSuggestions].
  host,
}

class _InlineToken {
  const _InlineToken({required this.token, required this.style, this.file});

  final String token;
  final FileStyle style;
  final FileInfo? file;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Where the `/` command menu may open inside a [FileTextField].
enum SlashAnchor {
  /// `/` opens the menu at any word boundary in the text. Default; matches
  /// 0.0.1 behavior.
  anywhere,

  /// `/` opens the menu only when the cursor is at the very start of the
  /// field text (offset 0), the way most chat apps treat commands.
  startOnly,
}

/// A [TextField] wrapper that displays attached files as colored inline tags.
///
/// Files can be attached via paste, an application-provided suggestion menu,
/// or programmatically. Their tokens (for example, `[image 1]` or
/// `[lib/main.dart]`) remain in the editing controller and are rendered with
/// per-file colors directly in the input line.
///
/// The host application retrieves the current attachments via
/// [FileTextFieldState.getAttachedFiles] (typically through a [GlobalKey]) and
/// receives change notifications through the `onFilesChanged` callback.
///
/// The `@`/`/` menu can be styled two ways. Pass [suggestionMenuBuilder] to
/// restyle the in-place menu, or set [suggestionMenuPlacement] to
/// [SuggestionMenuPlacement.host] and draw the menu wherever your layout needs
/// it — for instance as a separate panel above your own prompt container — from
/// [FileTextFieldState.visibleSuggestions] and
/// [FileTextFieldState.selectedSuggestionIndex]. Either way the widget keeps
/// owning trigger detection, filtering, keyboard navigation and token insertion.
class FileTextField extends StatefulComponent {
  /// Creates a file-aware text field.
  ///
  /// All [TextField] parameters are forwarded to the internal [TextField].
  /// Additional file-specific parameters:
  /// - [fileConfig]: color scheme for file tags (defaults to [FileConfig.defaultConfig]).
  /// - [onFileClick]: called when a tag is tapped; defaults to opening the file location in the OS file manager.
  /// - [onFilesChanged]: called whenever the attachment list changes.
  /// - [onSuggestionsRequested]: provides app-owned candidates for `@` and `/`.
  /// - [onSuggestionSelected]: reports the selected candidate to the host app.
  /// - [suggestionMenuBuilder]: optionally replaces the neutral default menu.
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
    this.onSuggestionsRequested,
    this.onSuggestionSelected,
    this.onSuggestionMenuChanged,
    this.suggestionMenuPlacement = SuggestionMenuPlacement.inline,
    this.suggestionMenuBuilder,
    this.slashAnchor = SlashAnchor.anywhere,
    this.suggestionMenuStyle = const SuggestionMenuStyle(),
    this.suggestionPageSize = 8,
    this.suggestionCyclicScroll = true,
    this.suggestionScrollThreshold = 1,
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
  final FileTextFieldSuggestionProvider? onSuggestionsRequested;
  final ValueChanged<FileTextFieldSuggestion>? onSuggestionSelected;

  /// Called whenever the `@`/`/` menu state changes: the menu opens or closes,
  /// its query changes, or the highlighted row moves.
  ///
  /// Pair it with [FileTextFieldState.visibleSuggestions] and
  /// [FileTextFieldState.selectedSuggestionIndex] to keep a menu rendered
  /// outside this widget in sync. Arrow-key navigation moves the highlight
  /// without editing the text, so [onChanged] alone is not enough.
  final VoidCallback? onSuggestionMenuChanged;

  /// Where the `@`/`/` menu is rendered.
  ///
  /// Defaults to [SuggestionMenuPlacement.inline], painted by the widget above
  /// the input. Set [SuggestionMenuPlacement.host] to draw it yourself from
  /// [FileTextFieldState.visibleSuggestions] — for instance as a separate panel
  /// above your own prompt container — while the widget keeps owning trigger
  /// detection, filtering, keyboard navigation and token insertion.
  final SuggestionMenuPlacement suggestionMenuPlacement;

  final FileTextFieldSuggestionMenuBuilder? suggestionMenuBuilder;

  /// Where the `/` command menu may open. Only affects the `/` trigger; the
  /// `@` mention trigger always works at word boundaries. Defaults to
  /// [SlashAnchor.anywhere], preserving 0.0.1 behavior.
  final SlashAnchor slashAnchor;

  /// Visual style for the built-in suggestion menu.
  final SuggestionMenuStyle suggestionMenuStyle;

  /// Maximum number of suggestion rows painted at once in the built-in menu.
  final int suggestionPageSize;

  /// Whether arrow-key navigation wraps around at the ends of the list.
  final bool suggestionCyclicScroll;

  /// How many rows from an edge the selection must reach before the visible
  /// window scrolls. `1` (default) means the window scrolls once the selection
  /// reaches the second-to-last / second-from-top row; `0` scrolls only when
  /// the selection leaves the window entirely.
  final int suggestionScrollThreshold;

  @override
  State<FileTextField> createState() => FileTextFieldState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Mutable state for [FileTextField], exposed via [GlobalKey] for [getAttachedFiles].
class FileTextFieldState extends State<FileTextField> {
  late TextEditingController _controller;
  bool _controllerIsInternal = false;
  final List<FileInfo> _attachedFiles = [];
  final List<_InlineToken> _inlineTokens = [];
  Timer? _cursorBlinkTimer;
  bool _cursorBlinkActive = false;
  Duration? _cursorBlinkRate;
  bool _cursorVisible = true;
  String? _activeTrigger;
  String _suggestionQuery = '';
  int _suggestionStartOffset = 0;
  List<FileTextFieldSuggestion> _providedSuggestions = const [];
  int _selectedSuggestionIndex = 0;
  int _suggestionScrollOffset = 0;

  // -- Public API: attachments ----------------------------------------------

  /// Returns the current list of attached files.
  ///
  /// Call this before sending the message to the AI model to include all
  /// attachments in the context.
  List<FileInfo> getAttachedFiles() => List.unmodifiable(_attachedFiles);

  /// Adds a file to the attachment list and inserts its token into the text.
  void attachFile(FileInfo file, {FileStyle? style}) {
    setState(() {
      final fileStyle = style ?? _styleFor(file);
      if (file.type == FileType.image) {
        file = file.copyWith(
          name: '${fileStyle.prefix ?? 'image'} ${_nextImageIndex(fileStyle)}',
        );
      }
      _attachedFiles.add(file);
      _insertToken(file, style: fileStyle);
      _notifyFilesChanged();
    });
  }

  /// The lowest image label number not yet taken by an attached image.
  ///
  /// Numbers come from what is actually attached rather than from a counter
  /// that only ever grew: deleting a token frees its number, so re-adding an
  /// image reuses `[image 2]` instead of skipping ahead to `[image 3]`. The
  /// label is the name `FileTag.labelFor` already falls back to, so no extra
  /// field is needed to carry the number.
  int _nextImageIndex(FileStyle fileStyle) {
    final prefix = fileStyle.prefix ?? 'image';
    final taken = _attachedFiles
        .where((attached) => attached.type == FileType.image)
        .map((attached) => attached.name)
        .where((name) => name.startsWith('$prefix '))
        .map((name) => int.tryParse(name.substring(prefix.length + 1)))
        .whereType<int>()
        .toSet();

    var index = 1;
    while (taken.contains(index)) {
      index++;
    }
    return index;
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
    _setSuggestionState(() {
      _attachedFiles.clear();
      _inlineTokens.clear();
      _activeTrigger = null;
      _suggestionQuery = '';
      _providedSuggestions = const [];
      _selectedSuggestionIndex = 0;
      _controller.clear();
      _notifyFilesChanged();
    });
  }

  /// Attaches a file by path string (for programmatic use).
  void attachFilePath(String path) {
    attachFile(FileInfo.fromPath(path));
  }

  // -- Public API: suggestion menu ------------------------------------------

  /// The suggestions currently visible for the open `@`/`/` menu.
  ///
  /// Empty when no menu is open. Read this together with
  /// [selectedSuggestionIndex] to render your own menu outside of this widget
  /// (for example above your own prompt container) instead of passing
  /// [FileTextField.suggestionMenuBuilder].
  List<FileTextFieldSuggestion> get visibleSuggestions =>
      List.unmodifiable(_visibleSuggestions);

  /// Index of the highlighted row in [visibleSuggestions], or -1 when no menu
  /// is open.
  ///
  /// Kept in sync by the widget's own keyboard handling, so a host-rendered
  /// menu highlights exactly the row the caret keys would accept.
  int get selectedSuggestionIndex =>
      _activeTrigger == null ? -1 : _selectedSuggestionIndex;

  /// First index of the currently visible window into [visibleSuggestions].
  ///
  /// The built-in inline menu uses this together with [suggestionPageSize] to
  /// paint only a slice of the suggestions; a host-rendered menu can mirror
  /// the same window or ignore it and scroll on its own.
  int get suggestionScrollOffset {
    final count = _visibleSuggestions.length;
    if (count == 0) return 0;
    final pageSize = _effectiveSuggestionPageSize(count);
    final maxOffset = (count - pageSize).clamp(0, count);
    return _suggestionScrollOffset.clamp(0, maxOffset);
  }

  /// Configured page size for the suggestion menu (see
  /// [FileTextField.suggestionPageSize]).
  int get suggestionPageSize => component.suggestionPageSize;

  /// Visual style for the built-in suggestion menu.
  SuggestionMenuStyle get suggestionMenuStyle => component.suggestionMenuStyle;

  /// Moves the highlighted suggestion by [delta] rows, applying the configured
  /// cyclic/linear policy and scroll threshold. Intended for host-rendered
  /// menus that want to drive highlighting from mouse or custom keys.
  void moveSuggestionHighlight(int delta) {
    final suggestions = _visibleSuggestions;
    if (suggestions.isEmpty) return;
    final count = suggestions.length;
    _setSuggestionState(() {
      if (component.suggestionCyclicScroll) {
        _selectedSuggestionIndex =
            (_selectedSuggestionIndex + delta + count) % count;
      } else {
        _selectedSuggestionIndex = (_selectedSuggestionIndex + delta).clamp(
          0,
          count - 1,
        );
      }
      _adjustSuggestionScrollOffset();
    });
  }

  /// Whether the `@`/`/` suggestion menu is currently open.
  bool get isSuggestionMenuOpen =>
      _activeTrigger != null && _visibleSuggestions.isNotEmpty;

  /// Selects [suggestion] as if it were picked from the menu: removes the
  /// trigger and query, inserts the suggestion's token (or attaches the file
  /// for file suggestions) and closes the menu.
  ///
  /// No-op when [visibleSuggestions] does not contain [suggestion].
  void selectSuggestion(FileTextFieldSuggestion suggestion) {
    if (!_visibleSuggestions.contains(suggestion)) return;
    _selectSuggestion(suggestion);
  }

  // -- Token bookkeeping ----------------------------------------------------
  // Tokens live in the controller text and are re-derived from it, so the
  // attachment list and the painted spans can never drift apart.

  void _insertToken(FileInfo file, {required FileStyle style}) {
    _insertInlineToken(
      _InlineToken(
        token: FileTag.tokenFor(file, style),
        style: style,
        file: file,
      ),
    );
  }

  void _insertSpecialToken(String token, FileStyle style) {
    _insertInlineToken(_InlineToken(token: token, style: style));
  }

  void _insertInlineToken(_InlineToken inlineToken) {
    final text = _controller.text;
    final insertOffset = _controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, insertOffset);
    final after = text.substring(insertOffset);
    final needsLeadingSpace =
        before.isNotEmpty && before.characters.last.trim().isNotEmpty;
    final needsTrailingSpace =
        after.isEmpty || after.characters.first.trim().isNotEmpty;
    final insertion =
        '${needsLeadingSpace ? ' ' : ''}${inlineToken.token}${needsTrailingSpace ? ' ' : ''}';
    final newText = '$before$insertion$after';
    _inlineTokens.add(inlineToken);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: insertOffset + insertion.length,
    );
  }

  void _removeToken(FileInfo file) {
    final tokenIndex = _inlineTokens.indexWhere(
      (inlineToken) => inlineToken.file == file,
    );
    if (tokenIndex < 0) return;
    final inlineToken = _inlineTokens.removeAt(tokenIndex);
    final token = inlineToken.token;
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

  void _syncCursorBlink() {
    final showInlineTags = _inlineTokens.isNotEmpty && !component.obscureText;
    final want = showInlineTags && component.focused && component.showCursor;
    if (want == _cursorBlinkActive &&
        component.cursorBlinkRate == _cursorBlinkRate) {
      return;
    }
    _cursorBlinkActive = want;
    _cursorBlinkRate = component.cursorBlinkRate;
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;
    if (want) {
      _cursorVisible = true;
      if (component.cursorBlinkRate != null) {
        _cursorBlinkTimer = Timer.periodic(component.cursorBlinkRate!, (_) {
          if (mounted) setState(() => _cursorVisible = !_cursorVisible);
        });
      }
    } else {
      _cursorVisible = false;
    }
  }

  void _syncAttachmentsFromText() {
    final text = _controller.text;
    _inlineTokens.removeWhere(
      (inlineToken) => !text.contains(inlineToken.token),
    );
    final toRemove = _attachedFiles.where((file) {
      return !_inlineTokens.any(
        (inlineToken) =>
            inlineToken.file == file && text.contains(inlineToken.token),
      );
    }).toList();
    if (toRemove.isEmpty) return;

    _attachedFiles.removeWhere(toRemove.contains);
    _notifyFilesChanged();
  }

  // -- Lifecycle ------------------------------------------------------------

  void _handleControllerChanged() {
    component.onChanged?.call(_controller.text);
    _syncAttachmentsFromText();
    _syncCursorBlink();
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
    _syncCursorBlink();
  }

  @override
  void dispose() {
    _cursorBlinkTimer?.cancel();
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
      _syncCursorBlink();
    }
    if (component.onSuggestionsRequested !=
            oldComponent.onSuggestionsRequested &&
        _activeTrigger != null) {
      setState(_refreshSuggestions);
      _syncCursorBlink();
    }
    _syncCursorBlink();
  }

  // -- Input ----------------------------------------------------------------
  // Paste drops paths in as attachments; keys are intercepted only while a
  // suggestion menu is open, so ordinary typing stays with Nocterm's TextField.

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
    if (!component.enabled || component.readOnly) return false;
    if (_activeTrigger != null) return _handleSuggestionKeyEvent(event);

    if (event.logicalKey == LogicalKey.backspace ||
        event.logicalKey == LogicalKey.delete) {
      if (_removeAttachmentAtSelection(
        backwards: event.logicalKey == LogicalKey.backspace,
      )) {
        return true;
      }
    }

    if ((event.logicalKey == LogicalKey.at || event.character == '@') &&
        component.onSuggestionsRequested != null &&
        _isTriggerBoundary()) {
      _openSuggestions('@');
      return true;
    }

    if ((event.logicalKey == LogicalKey.slash || event.character == '/') &&
        component.onSuggestionsRequested != null &&
        _isSlashTriggerActive()) {
      _openSuggestions('/');
      return true;
    }
    // Ctrl+V - let TextField handle paste (which calls onPaste)
    if (event.logicalKey == LogicalKey.keyV && event.isControlPressed) {
      return false; // Let TextField handle it
    }
    return false;
  }

  bool _isTriggerBoundary() {
    final offset = _controller.selection.extentOffset.clamp(
      0,
      _controller.text.length,
    );
    return offset == 0 || _controller.text[offset - 1].trim().isEmpty;
  }

  bool _isSlashTriggerActive() {
    switch (component.slashAnchor) {
      case SlashAnchor.anywhere:
        return _isTriggerBoundary();
      case SlashAnchor.startOnly:
        return _controller.selection.extentOffset.clamp(
              0,
              _controller.text.length,
            ) ==
            0;
    }
  }

  // -- Suggestion menu internals --------------------------------------------
  // Everything here runs behind the public menu API above: detection, query
  // bookkeeping, filtering, keyboard navigation and token insertion.

  void _openSuggestions(String trigger) {
    final text = _controller.text;
    _suggestionStartOffset = _controller.selection.extentOffset.clamp(
      0,
      text.length,
    );
    _setSuggestionState(() {
      _activeTrigger = trigger;
      _suggestionQuery = '';
      _selectedSuggestionIndex = 0;
      _suggestionScrollOffset = 0;
      _refreshSuggestions();
    });
    _replaceSuggestionInput('');
  }

  /// Applies a suggestion-menu state change and notifies the host, so a menu
  /// rendered outside this widget stays in sync.
  void _setSuggestionState(VoidCallback update) {
    setState(update);
    component.onSuggestionMenuChanged?.call();
  }

  bool _handleSuggestionKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      _closeSuggestions();
      return true;
    }
    // A modified Enter or Ctrl+J is a line-break intent, not a menu pick:
    // close the menu and pass the event on, so Nocterm's TextField inserts
    // the newline with its own selection/limit handling.
    final isModifierEnter =
        event.logicalKey == LogicalKey.enter &&
        (event.isControlPressed || event.isShiftPressed || event.isAltPressed);
    if ((isModifierEnter || event.matches(LogicalKey.keyJ, ctrl: true)) &&
        component.maxLines != 1) {
      _closeSuggestions();
      return false;
    }
    if (event.logicalKey == LogicalKey.pageDown ||
        event.logicalKey == LogicalKey.pageUp) {
      final suggestions = _visibleSuggestions;
      if (suggestions.isNotEmpty) {
        final count = suggestions.length;
        final pageSize = _effectiveSuggestionPageSize(count);
        final direction = event.logicalKey == LogicalKey.pageDown ? 1 : -1;
        _setSuggestionState(() {
          if (component.suggestionCyclicScroll) {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + direction * pageSize + count) %
                count;
          } else {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + direction * pageSize).clamp(
                  0,
                  count - 1,
                );
          }
          _adjustSuggestionScrollOffset();
        });
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.home ||
        event.logicalKey == LogicalKey.end) {
      final suggestions = _visibleSuggestions;
      if (suggestions.isNotEmpty) {
        _setSuggestionState(() {
          _selectedSuggestionIndex = event.logicalKey == LogicalKey.home
              ? 0
              : suggestions.length - 1;
          _adjustSuggestionScrollOffset();
        });
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.arrowDown) {
      final suggestions = _visibleSuggestions;
      if (suggestions.isNotEmpty) {
        final direction = event.logicalKey == LogicalKey.arrowDown ? 1 : -1;
        _setSuggestionState(() {
          final count = suggestions.length;
          if (component.suggestionCyclicScroll) {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + direction + count) % count;
          } else {
            _selectedSuggestionIndex = (_selectedSuggestionIndex + direction)
                .clamp(0, count - 1);
          }
          _adjustSuggestionScrollOffset();
        });
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      final suggestions = _visibleSuggestions;
      if (suggestions.isNotEmpty) {
        _selectSuggestion(suggestions[_selectedSuggestionIndex]);
      } else {
        _closeSuggestions();
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace) {
      if (_suggestionQuery.isEmpty) {
        _removeSuggestionInput();
        _closeSuggestions();
      } else {
        final query = _suggestionQuery.characters.skipLast(1).toString();
        _replaceSuggestionInput(query);
        _setSuggestionState(() {
          _suggestionQuery = query;
          _suggestionScrollOffset = 0;
          _refreshSuggestions();
          _selectedSuggestionIndex = 0;
          _adjustSuggestionScrollOffset();
        });
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.delete) return true;
    if (event.character != null && !event.isControlPressed) {
      if (event.character!.trim().isEmpty) {
        _closeSuggestions();
        return false;
      }
      final query = '$_suggestionQuery${event.character!}';
      _replaceSuggestionInput(query);
      _setSuggestionState(() {
        _suggestionQuery = query;
        _suggestionScrollOffset = 0;
        _refreshSuggestions();
        _selectedSuggestionIndex = 0;
        _adjustSuggestionScrollOffset();
      });
      if (_activeTrigger == '/' && query.contains('/')) {
        _closeSuggestions();
        return true;
      }
      return true;
    }
    return false;
  }

  void _closeSuggestions() {
    _setSuggestionState(() {
      _activeTrigger = null;
      _suggestionQuery = '';
      _providedSuggestions = const [];
      _selectedSuggestionIndex = 0;
      _suggestionScrollOffset = 0;
    });
  }

  void _replaceSuggestionInput(String query) {
    final text = _controller.text;
    final start = _suggestionStartOffset.clamp(0, text.length);
    final oldEnd = (start + 1 + _suggestionQuery.length).clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(oldEnd);
    final replacement = '$_activeTrigger$query';
    _controller.text = '$before$replacement$after';
    _controller.selection = TextSelection.collapsed(
      offset: start + replacement.length,
    );
  }

  void _removeSuggestionInput() {
    final text = _controller.text;
    final start = _suggestionStartOffset.clamp(0, text.length);
    final end = (start + 1 + _suggestionQuery.length).clamp(0, text.length);
    final newText = text.substring(0, start) + text.substring(end);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: start);
  }

  void _refreshSuggestions() {
    final trigger = _activeTrigger;
    final provider = component.onSuggestionsRequested;
    _providedSuggestions = trigger == null || provider == null
        ? const []
        : List.unmodifiable(provider(trigger, _suggestionQuery));
    _selectedSuggestionIndex = 0;
    _suggestionScrollOffset = 0;
  }

  List<FileTextFieldSuggestion> get _visibleSuggestions {
    final query = _suggestionQuery.toLowerCase();
    return _providedSuggestions
        .where((suggestion) => suggestion.searchableText.contains(query))
        .toList();
  }

  int _effectiveSuggestionPageSize(int itemCount) {
    if (itemCount <= 0) return 1;
    final size = component.suggestionPageSize.clamp(1, itemCount);
    return size;
  }

  void _adjustSuggestionScrollOffset() {
    final suggestions = _visibleSuggestions;
    final count = suggestions.length;
    if (count == 0) {
      _suggestionScrollOffset = 0;
      return;
    }
    final pageSize = _effectiveSuggestionPageSize(count);
    if (count <= pageSize) {
      _suggestionScrollOffset = 0;
      return;
    }
    final threshold = component.suggestionScrollThreshold.clamp(
      0,
      pageSize - 1,
    );
    final maxOffset = count - pageSize;
    _suggestionScrollOffset = _suggestionScrollOffset.clamp(0, maxOffset);
    var position = _selectedSuggestionIndex - _suggestionScrollOffset;
    // Scroll down when the selection reaches the (threshold+1)-th from bottom.
    while (position >= pageSize - threshold - 1 &&
        _suggestionScrollOffset < maxOffset) {
      _suggestionScrollOffset++;
      position = _selectedSuggestionIndex - _suggestionScrollOffset;
    }
    // Scroll up when the selection reaches the (threshold+1)-th from top.
    while (position <= threshold && _suggestionScrollOffset > 0) {
      _suggestionScrollOffset--;
      position = _selectedSuggestionIndex - _suggestionScrollOffset;
    }
    _suggestionScrollOffset = _suggestionScrollOffset.clamp(0, maxOffset);
  }

  void _selectSuggestion(FileTextFieldSuggestion suggestion) {
    final text = _controller.text;
    final start = _suggestionStartOffset.clamp(0, text.length);
    final end = (start + 1 + _suggestionQuery.length).clamp(0, text.length);
    final withoutQuery = text.substring(0, start) + text.substring(end);
    _controller.text = withoutQuery;
    _controller.selection = TextSelection.collapsed(offset: start);
    _closeSuggestions();
    final file = suggestion.file;
    if (file != null) {
      attachFile(file, style: suggestion.style);
    } else {
      final label = switch (suggestion.kind) {
        FileTextFieldSuggestionKind.folder => suggestion.name,
        FileTextFieldSuggestionKind.agent => '@${suggestion.name}',
        FileTextFieldSuggestionKind.command => '/${suggestion.name}',
        FileTextFieldSuggestionKind.file => throw StateError(
          'File suggestions must include a FileInfo.',
        ),
      };
      final token =
          '${suggestion.style.openingDelimiter}$label${suggestion.style.closingDelimiter}';
      setState(() {
        _insertSpecialToken(token, suggestion.style);
      });
    }
    component.onSuggestionSelected?.call(suggestion);
  }

  // -- Attachment editing ---------------------------------------------------
  // Backspace/Delete remove a touched token as one unit, and pasted paths are
  // recognized here before the text ever reaches the controller.

  bool _removeAttachmentAtSelection({required bool backwards}) {
    final text = _controller.text;
    final selection = _controller.selection;
    for (final inlineToken in _inlineTokens.toList()) {
      final tokenStart = text.indexOf(inlineToken.token);
      if (tokenStart < 0) continue;
      final tokenEnd = tokenStart + inlineToken.token.length;
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
        _inlineTokens.remove(inlineToken);
        final file = inlineToken.file;
        if (file != null) _attachedFiles.remove(file);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: range.$1.clamp(0, newText.length),
        );
        if (file != null) _notifyFilesChanged();
      });
      return true;
    }
    return false;
  }

  /// Extracts file paths from pasted text: one per line, or several on a line
  /// separated by spaces.
  ///
  /// A line is only split on spaces when *every* token ends in a file
  /// extension, so a path that legitimately contains a space
  /// (`/home/user/My Docs/a.txt`) stays whole instead of being torn into
  /// fragments.
  List<String> _extractPaths(String text) {
    final paths = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final tokens = trimmed.split(RegExp(r'\s+'));
      if (tokens.length > 1 && tokens.every((token) => _hasExtension(token))) {
        paths.addAll(tokens);
      } else if (_looksLikePath(trimmed)) {
        paths.add(trimmed);
      }
    }
    return paths;
  }

  bool _hasExtension(String path) => RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(path);

  bool _looksLikePath(String s) {
    // Heuristic: contains path separator or looks like a file with extension
    return s.contains('/') ||
        s.contains('\\') ||
        RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(s);
  }

  // -- Rendering ------------------------------------------------------------
  // The field paints through Nocterm's public RichText so tokens can carry
  // their own colors; the caret and selection are emulated on that overlay.

  @override
  Component build(BuildContext context) {
    final showInlineTags = _inlineTokens.isNotEmpty && !component.obscureText;
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

    Component input = textField;
    if (showInlineTags) {
      final text = _controller.text;
      final selection = _controller.selection;
      final cursorColor = component.cursorColor ?? TuiTheme.of(context).primary;
      input = Stack(
        children: [
          textField,
          GestureDetector(
            onTapDown: _handleInlineTapDown,
            child: RichText(
              text: TextSpan(
                children: buildInlineSpans(
                  text: text,
                  tokens: _inlineTokens
                      .map(
                        (inlineToken) => InlineToken(
                          token: inlineToken.token,
                          style: inlineToken.style,
                        ),
                      )
                      .toList(),
                  selectionStart: selection.start.clamp(0, text.length),
                  selectionEnd: selection.end.clamp(0, text.length),
                  cursorOffset:
                      component.focused &&
                          component.showCursor &&
                          _cursorVisible
                      ? selection.extentOffset.clamp(0, text.length)
                      : null,
                  cursorColor: cursorColor,
                  baseStyle: component.style ?? const TextStyle(),
                  selectionColor:
                      component.selectionColor ?? cursorColor.withOpacity(0.4),
                  cursorStyle: component.cursorStyle,
                ),
              ),
              textAlign: component.textAlign,
              softWrap: component.maxLines != 1,
              overflow: TextOverflow.clip,
              maxLines: component.maxLines,
            ),
          ),
        ],
      );
    }

    if (_activeTrigger == null) return input;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildSuggestionMenu(), input],
    );
  }

  Component _buildSuggestionMenu() {
    final suggestions = _visibleSuggestions;
    final menuBuilder = component.suggestionMenuBuilder;
    if (menuBuilder != null) {
      return menuBuilder(
        context,
        List.unmodifiable(suggestions),
        _selectedSuggestionIndex,
        _selectSuggestion,
      );
    }
    if (component.suggestionMenuPlacement == SuggestionMenuPlacement.host) {
      return const SizedBox.shrink();
    }

    return _buildDefaultSuggestionMenu(suggestions);
  }

  Component _buildDefaultSuggestionMenu(
    List<FileTextFieldSuggestion> suggestions,
  ) {
    final style = component.suggestionMenuStyle;
    final pageSize = suggestions.isEmpty
        ? 1
        : _effectiveSuggestionPageSize(suggestions.length);
    final maxOffset = suggestions.isEmpty
        ? 0
        : (suggestions.length - pageSize).clamp(0, suggestions.length);
    final offset = _suggestionScrollOffset.clamp(0, maxOffset);
    final windowEnd = (offset + pageSize).clamp(0, suggestions.length);
    final visible = suggestions.isEmpty
        ? const <FileTextFieldSuggestion>[]
        : suggestions.sublist(offset, windowEnd);

    final marker = style.highlightMarker;
    final markerPrefix = marker.isEmpty ? '' : '$marker ';
    final markerWidth = markerPrefix.length;
    final unselectedPrefix = marker.isEmpty ? '' : ' ' * markerWidth;

    return MouseRegion(
      onHover: (event) {
        if (event.button == MouseButton.wheelUp) {
          _handleSuggestionWheel(-1);
        } else if (event.button == MouseButton.wheelDown) {
          _handleSuggestionWheel(1);
        }
      },
      child: Container(
        width: component.width,
        padding: style.padding,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          border: style.border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: suggestions.isEmpty
              ? [Text('No matches', style: TextStyle(color: Colors.gray))]
              : [
                  for (var i = 0; i < visible.length; i++)
                    GestureDetector(
                      onTap: () => _selectSuggestion(visible[i]),
                      child: Container(
                        color: offset + i == _selectedSuggestionIndex
                            ? style.selectedBackgroundColor
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: RichText(
                          text: TextSpan(
                            children: _highlightedSuggestionRow(
                              prefix: offset + i == _selectedSuggestionIndex
                                  ? markerPrefix
                                  : unselectedPrefix,
                              label: visible[i].displayLabel,
                              query: _suggestionQuery,
                              selected: offset + i == _selectedSuggestionIndex,
                              selectedTextColor: style.selectedTextColor,
                              itemTextColor: style.itemTextColor,
                              highlightMarkerColor:
                                  style.highlightMarkerColor ??
                                  style.selectedTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightedSuggestionRow({
    required String prefix,
    required String label,
    required String query,
    required bool selected,
    required Color selectedTextColor,
    required Color itemTextColor,
    required Color highlightMarkerColor,
  }) {
    final baseColor = selected ? selectedTextColor : itemTextColor;
    final baseStyle = TextStyle(color: baseColor);
    final highlightStyle = TextStyle(
      color: baseColor,
      fontWeight: FontWeight.bold,
    );
    final prefixStyle = TextStyle(
      color: selected ? highlightMarkerColor : itemTextColor,
    );
    final spans = <TextSpan>[TextSpan(text: prefix, style: prefixStyle)];
    if (query.isEmpty) {
      spans.add(TextSpan(text: label, style: baseStyle));
      return spans;
    }
    final lowerLabel = label.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    var index = lowerLabel.indexOf(lowerQuery, start);
    while (index >= 0) {
      if (index > start) {
        spans.add(
          TextSpan(text: label.substring(start, index), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: label.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );
      start = index + query.length;
      index = lowerLabel.indexOf(lowerQuery, start);
    }
    if (start < label.length) {
      spans.add(TextSpan(text: label.substring(start), style: baseStyle));
    }
    if (spans.length == 1) {
      spans.add(TextSpan(text: label, style: baseStyle));
    }
    return spans;
  }

  void _handleSuggestionWheel(int direction) {
    final suggestions = _visibleSuggestions;
    if (suggestions.isEmpty) return;
    final count = suggestions.length;
    _setSuggestionState(() {
      if (component.suggestionCyclicScroll) {
        _selectedSuggestionIndex =
            (_selectedSuggestionIndex + direction + count) % count;
      } else {
        _selectedSuggestionIndex = (_selectedSuggestionIndex + direction).clamp(
          0,
          count - 1,
        );
      }
      _adjustSuggestionScrollOffset();
    });
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

    for (final inlineToken in _inlineTokens) {
      final file = inlineToken.file;
      if (file == null) continue;
      final tokenStart = text.indexOf(inlineToken.token);
      if (tokenStart >= 0 &&
          offset >= tokenStart &&
          offset < tokenStart + inlineToken.token.length) {
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
}
