import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';
import 'file_opener.dart';
import 'file_tag.dart';
import 'file_text_field_suggestion.dart';
import 'suggestion_grouping.dart';
import 'suggestion_menu_style.dart';
import 'inline_token.dart';
import 'token_spans.dart';
import 'cursor_blink_mixin.dart';

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
  const _InlineToken({
    required this.token,
    required this.style,
    this.file,
    this.pastedText,
    this.start,
    this.end,
  });

  final String token;
  final FileStyle style;
  final FileInfo? file;

  /// Full text collapsed into this token when it represents a large paste.
  final String? pastedText;

  /// Half-open range `[start, end)` of [token] inside the controller text.
  ///
  /// An extmark-style anchor: expansion and removal act on the span the user
  /// sees, not on the first lookalike match.
  final int? start;
  final int? end;

  bool get isPasted => pastedText != null;

  _InlineToken withRange(int from, int to) {
    return _InlineToken(
      token: token,
      style: style,
      file: file,
      pastedText: pastedText,
      start: from,
      end: to,
    );
  }
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
    this.suggestionGrouping = const SuggestionMenuGrouping(),
    this.enablePasteCollapse = true,
    this.pasteCollapseMinLines = 3,
    this.pasteCollapseMinChars = 150,
    this.pasteStyle = const FileStyle(
      text: Colors.brightWhite,
      background: Colors.grey,
      bold: true,
    ),
    this.onPastedChanged,
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

  /// Section order and headings of the suggestion menu.
  final SuggestionMenuGrouping suggestionGrouping;

  /// Whether large pastes are collapsed into a `[Pasted ~N lines]` tag.
  final bool enablePasteCollapse;

  /// Minimum number of lines in a paste before it is collapsed.
  final int pasteCollapseMinLines;

  /// Minimum number of characters in a paste before it is collapsed (for
  /// single-line pastes).
  final int pasteCollapseMinChars;

  /// Style used for collapsed paste tags.
  final FileStyle pasteStyle;

  /// Called whenever the set of collapsed pastes changes.
  final ValueChanged<List<String>>? onPastedChanged;

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

class _SuggestionNavFrame {
  const _SuggestionNavFrame({
    required this.trigger,
    required this.query,
    required this.basePath,
  });
  final String trigger;
  final String query;
  final String? basePath;
}

/// Mutable state for [FileTextField], exposed via [GlobalKey] for [getAttachedFiles].
class FileTextFieldState extends State<FileTextField>
    with CursorBlinkMixin<FileTextField> {
  late TextEditingController _controller;
  bool _controllerIsInternal = false;
  final List<FileInfo> _attachedFiles = [];
  final List<_InlineToken> _inlineTokens = [];
  String? _activeTrigger;
  String _suggestionQuery = '';
  int _suggestionStartOffset = 0;
  List<FileTextFieldSuggestion> _providedSuggestions = const [];
  int _selectedSuggestionIndex = 0;
  int _suggestionScrollOffset = 0;

  // Navigation stack for directory browsing
  final List<_SuggestionNavFrame> _navStack = [];

  // -- Public API: attachments ----------------------------------------------

  /// Returns the current list of attached files.
  ///
  /// Call this before sending the message to the AI model to include all
  /// attachments in the context.
  List<FileInfo> getAttachedFiles() => List.unmodifiable(_attachedFiles);

  /// Navigation helpers for directory browsing
  int get navigationDepth => _navStack.length;
  bool get canNavigateBack => _navStack.length > 1;
  String? get currentBasePath =>
      _navStack.isNotEmpty ? _navStack.last.basePath : null;

  /// Returns the full text of every collapsed paste currently in the field.
  List<String> getPastedTexts() => List.unmodifiable(
    _inlineTokens
        .where((token) => token.isPasted)
        .map((token) => token.pastedText!)
        .toList(),
  );

  /// Returns the field text with every collapsed paste tag expanded back to
  /// its full text. Without collapsed pastes the text comes back untouched, so
  /// a submit observes exactly what the controller holds. Read-only: ranges
  /// are anchored by the controller listener, so nothing is mutated here.
  String getExpandedText() {
    final text = _controller.text;
    final pasted = _inlineTokens.where((token) => token.isPasted).toList();
    if (pasted.isEmpty) return text;

    // Compute ranges locally without mutating state
    final replacements = <(int start, int end, String text)>[];
    var cursor = 0;
    for (final token in pasted) {
      final stored = token.start;
      final fitsStored =
          stored != null &&
          stored >= cursor &&
          stored + token.token.length <= text.length &&
          text.startsWith(token.token, stored);
      final start = fitsStored ? stored : text.indexOf(token.token, cursor);
      if (start < 0) continue;
      final end = start + token.token.length;
      replacements.add((start, end, token.pastedText!));
      cursor = end;
    }

    // Expand right to left so the offsets stay valid.
    replacements.sort((a, b) => b.$1.compareTo(a.$1));
    var result = text;
    for (final range in replacements) {
      result =
          result.substring(0, range.$1) + range.$3 + result.substring(range.$2);
    }
    return result.trimRight();
  }

  /// Replaces every collapsed paste tag in the field with its full text.
  void expandPastedText() {
    setState(() {
      _controller.text = getExpandedText();
    });
  }

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
      _notifyPastedChanged();
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

  /// Sections of the open menu, in render order.
  ///
  /// A section's [SuggestionMenuGroupView.title] is `null` when it renders
  /// without a heading: headings are off, this is the only section, or the
  /// section opts out of one while browsing a directory. Host-rendered menus
  /// draw the headings themselves.
  List<SuggestionMenuGroupView> get visibleSuggestionGroups {
    final items = _visibleSuggestions;
    if (items.isEmpty) return const [];

    final grouping = component.suggestionGrouping;
    final browsing = canNavigateBack;
    final buckets = <int, List<FileTextFieldSuggestion>>{};
    final ungrouped = <FileTextFieldSuggestion>[];

    for (final item in items) {
      final groupIndex = grouping.groups.indexWhere(
        (group) => group.kinds.contains(item.kind),
      );
      if (groupIndex < 0) {
        ungrouped.add(item);
        continue;
      }
      buckets.putIfAbsent(groupIndex, () => []).add(item);
    }

    final populated = <(SuggestionMenuGroup?, List<FileTextFieldSuggestion>)>[];
    for (var i = 0; i < grouping.groups.length; i++) {
      final bucket = buckets[i];
      if (bucket == null || bucket.isEmpty) continue;
      populated.add((grouping.groups[i], bucket));
    }
    if (ungrouped.isNotEmpty) populated.add((null, ungrouped));

    // A lone section needs no heading.
    final headings = grouping.showHeaders && populated.length > 1;

    return [
      for (final entry in populated)
        () {
          final group = entry.$1;
          final title = group != null ? group.title : grouping.ungroupedTitle;
          final show =
              headings && ((group?.headerWhileBrowsed ?? true) || !browsing);
          return SuggestionMenuGroupView(
            show ? title : null,
            List.unmodifiable(entry.$2),
          );
        }(),
    ];
  }

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
    final tokenStart = insertOffset + (needsLeadingSpace ? 1 : 0);
    _inlineTokens.add(
      inlineToken.withRange(tokenStart, tokenStart + inlineToken.token.length),
    );
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
    // The token's own span, not the first lookalike: two files can share a
    // basename and therefore the same label.
    var index = inlineToken.start ?? -1;
    if (index < 0 || !text.startsWith(token, index)) {
      index = text.indexOf(token);
    }
    if (index < 0) return;

    final range = _attachmentRemovalRange(text, index, index + token.length);
    final newText = text.substring(0, range.$1) + text.substring(range.$2);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: range.$1.clamp(0, newText.length),
    );
  }

  /// Range a token occupies together with the separator it brings. The
  /// trailing one is preferred: a token always carries it, so removal never
  /// reaches back for the space the user typed before the token.
  (int, int) _attachmentRemovalRange(String text, int start, int end) {
    if (end < text.length && text[end].trim().isEmpty) {
      return (start, end + 1);
    }
    if (start > 0 && text[start - 1].trim().isEmpty) {
      return (start - 1, end);
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
    syncCursorBlink(
      hasTokens: showInlineTags,
      obscureText: component.obscureText,
      focused: component.focused,
      showCursor: component.showCursor,
      cursorBlinkRate: component.cursorBlinkRate,
    );
  }

  void _syncAttachmentsFromText() {
    final text = _controller.text;
    _anchorTokens(text);

    final uniqueTokens = _inlineTokens.map((t) => t.token).toSet();
    final counts = <String, int>{};
    for (final token in uniqueTokens) {
      counts[token] = _countOccurrences(text, token);
    }

    final remaining = Map<String, int>.from(counts);
    final toRemoveTokens = <_InlineToken>[];
    for (final inlineToken in _inlineTokens.toList()) {
      if ((remaining[inlineToken.token] ?? 0) > 0) {
        remaining[inlineToken.token] = remaining[inlineToken.token]! - 1;
      } else {
        toRemoveTokens.add(inlineToken);
      }
    }
    final removedPasted = toRemoveTokens.any((t) => t.isPasted);
    for (final inlineToken in toRemoveTokens) {
      _inlineTokens.remove(inlineToken);
    }

    final toRemove = _attachedFiles.where((file) {
      return !_inlineTokens.any((inlineToken) => inlineToken.file == file);
    }).toList();
    if (toRemove.isNotEmpty) {
      _attachedFiles.removeWhere(toRemove.contains);
      _notifyFilesChanged();
    }
    if (removedPasted) _notifyPastedChanged();
  }

  /// Re-binds tokens to the span they currently occupy. A stored range is
  /// trusted only while it still delimits its token; otherwise the token is
  /// relocated by scanning forward from the previous token's end, so duplicate
  /// labels stay bound to their own occurrence.
  void _anchorTokens(String text) {
    var cursor = 0;

    for (var index = 0; index < _inlineTokens.length; index++) {
      final token = _inlineTokens[index];
      final stored = token.start;
      final fitsStored =
          stored != null &&
          stored >= cursor &&
          stored + token.token.length <= text.length &&
          text.startsWith(token.token, stored);
      final start = fitsStored ? stored : text.indexOf(token.token, cursor);
      if (start < 0) continue;
      final end = start + token.token.length;
      _inlineTokens[index] = token.withRange(start, end);
      cursor = end;
    }
  }

  int _countOccurrences(String text, String token) {
    if (token.isEmpty) return 0;
    var count = 0;
    var searchFrom = 0;
    while (true) {
      final index = text.indexOf(token, searchFrom);
      if (index < 0) break;
      count++;
      searchFrom = index + token.length;
    }
    return count;
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

  /// Handles paste events: intercepts file paths and collapses large pastes.
  bool _handlePaste(String pastedText) {
    final paths = _extractPaths(pastedText);
    if (paths.isNotEmpty) {
      for (final path in paths) {
        attachFile(FileInfo.fromPath(path));
      }
      return true; // Handled
    }

    if (component.enablePasteCollapse) {
      final collapse = _collapsiblePaste(pastedText);
      if (collapse != null) {
        _attachPastedText(collapse);
        return true; // Handled
      }
    }
    return false; // Let TextField handle normal text paste
  }

  /// The text to collapse, or `null` when the paste is small enough to insert
  /// verbatim. Counting and storage happen on the trimmed text, the token
  /// already supplies its own separators. In single-line fields Nocterm
  /// flattens newlines before the paste arrives, so only length applies there.
  String? _collapsiblePaste(String pastedText) {
    final trimmed = pastedText.trim();
    if (trimmed.isEmpty) return null;
    final lineCount = trimmed.split('\n').length;
    if (lineCount >= component.pasteCollapseMinLines ||
        trimmed.length >= component.pasteCollapseMinChars) {
      return trimmed;
    }
    return null;
  }

  void _attachPastedText(String pastedText) {
    setState(() {
      final style = component.pasteStyle;
      final lineCount = pastedText.split('\n').length;
      final label = lineCount == 1 ? 'line' : 'lines';
      final token =
          '${style.openingDelimiter}Pasted ~$lineCount $label${style.closingDelimiter}';
      _insertInlineToken(
        _InlineToken(token: token, style: style, pastedText: pastedText),
      );
      _notifyPastedChanged();
    });
  }

  void _notifyPastedChanged() {
    component.onPastedChanged?.call(getPastedTexts());
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
    // The start of the selection: a range selection types at its start, so a
    // word preceded by a space is still a valid mention boundary.
    final offset = _controller.selection.start.clamp(
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
        return _controller.selection.start.clamp(0, _controller.text.length) ==
            0;
    }
  }

  // -- Suggestion menu internals --------------------------------------------
  // Everything here runs behind the public menu API above: detection, query
  // bookkeeping, filtering, keyboard navigation and token insertion.

  void _openSuggestions(String trigger) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    // The trigger key was consumed by [_handleKeyEvent], so it is inserted
    // here — over the selection, exactly as typing it would. Every later
    // rewrite of the trigger region can then assume it is present.
    _controller.text =
        '${text.substring(0, start)}$trigger${text.substring(end)}';
    _controller.selection = TextSelection.collapsed(offset: start + 1);
    _suggestionStartOffset = start;
    _setSuggestionState(() {
      _activeTrigger = trigger;
      _suggestionQuery = '';
      _selectedSuggestionIndex = 0;
      _suggestionScrollOffset = 0;
      _refreshSuggestions();
    });
    // The stack always holds the frame the menu opened at, so navigation has a
    // root to return to.
    _navStack.clear();
    _navStack.add(
      _SuggestionNavFrame(trigger: trigger, query: '', basePath: null),
    );
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
    // While the menu is open the caret stands still: the left/right arrows
    // browse the tree instead of moving through the text. Only folders carry a
    // path to drop into.
    if (event.logicalKey == LogicalKey.arrowRight) {
      final suggestions = _visibleSuggestions;
      if (suggestions.isNotEmpty) {
        final highlighted = suggestions[_selectedSuggestionIndex];
        if (highlighted.kind == FileTextFieldSuggestionKind.folder &&
            highlighted.path != null) {
          _navigateIntoFolder(highlighted);
        }
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowLeft) {
      _navigateBack();
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
      // The menu writes through the controller, so honor maxLength here the
      // way Nocterm's own insertion does.
      final maxLength = component.maxLength;
      final text = _controller.text;
      final triggerLength = 1 + _suggestionQuery.length;
      if (maxLength != null &&
          text.length - triggerLength + event.character!.length > maxLength) {
        return true;
      }
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
      _navStack.clear();
    });
  }

  void _navigateIntoFolder(FileTextFieldSuggestion suggestion) {
    if (_navStack.isEmpty || suggestion.path == null) return;
    final current = _navStack.last;
    _navStack.add(
      _SuggestionNavFrame(
        trigger: current.trigger,
        query: _suggestionQuery,
        basePath: suggestion.path,
      ),
    );
    _setSuggestionState(() {
      // Replace the trigger text first, while it still spans the old query.
      _replaceSuggestionInput('');
      _suggestionQuery = '';
      _refreshSuggestions();
      _selectedSuggestionIndex = 0;
      _adjustSuggestionScrollOffset();
    });
  }

  void _navigateBack() {
    if (_navStack.length <= 1) return;
    _navStack.removeLast();
    final previous = _navStack.last;
    _setSuggestionState(() {
      // Replace the trigger text first, while it still spans the old query.
      _replaceSuggestionInput(previous.query);
      _suggestionQuery = previous.query;
      _refreshSuggestions();
      _selectedSuggestionIndex = 0;
      _adjustSuggestionScrollOffset();
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
    final List<FileTextFieldSuggestion> all =
        trigger == null || provider == null
        ? const []
        : provider(trigger, _suggestionQuery);
    final basePath = currentBasePath;
    const sep = '/';
    final filtered = basePath == null
        ? all
        : all.where((s) {
            // Agents, commands and sessions carry no path: they stay listed
            // while the directory tree is browsed.
            final p = s.path;
            if (p == null) return true;
            // Boundary match: `lib` must not claim the sibling `library.txt`.
            final base = basePath.endsWith(sep)
                ? basePath.substring(0, basePath.length - 1)
                : basePath;
            if (!p.startsWith('$base$sep')) return false;
            final remainder = p.substring(base.length + sep.length);
            return !remainder.contains(sep);
          }).toList();
    _providedSuggestions = List.unmodifiable(filtered);
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
      final label = suggestion.displayLabel;
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

    // Ranges are the source of truth: each token acts on the span it occupies,
    // so two identical labels never resolve to the same occurrence.
    _anchorTokens(text);

    for (final inlineToken in _inlineTokens.toList()) {
      if (inlineToken.start == null || inlineToken.end == null) continue;
      final tokenStart = inlineToken.start!;
      final tokenEnd = inlineToken.end!;
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
        if (inlineToken.isPasted) _notifyPastedChanged();
      });
      return true;
    }
    return false;
  }

  /// Extracts pasted file paths from [text].
  ///
  /// A line is a path only when every token on it is path-shaped — carries a
  /// separator or ends in an extension — so prose that merely mentions a path
  /// has bare words in it and is left for the collapsible-paste path instead
  /// of being torn into attachments.
  List<String> _extractPaths(String text) {
    final paths = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final tokens = trimmed.split(RegExp(r'\s+'));
      if (tokens.isEmpty) continue;
      if (!tokens.every(_isPathShaped)) continue;

      // `a.png b.png` is a list of paths; a line whose tokens are shaped but
      // only some carry an extension is one path that contains spaces.
      if (tokens.length > 1 && tokens.every(_hasExtension)) {
        paths.addAll(tokens);
      } else {
        paths.add(trimmed);
      }
    }
    return paths;
  }

  bool _hasExtension(String path) => RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(path);

  /// A token belongs to a path when it carries a separator or a file
  /// extension. Bare words (`and`, `the`, `supports`) never do.
  bool _isPathShaped(String token) =>
      token.contains('/') || token.contains('\\') || _hasExtension(token);

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
      onSubmitted: component.onSubmitted == null
          ? null
          : (value) => component.onSubmitted!(getExpandedText()),
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
                      component.focused && component.showCursor && cursorVisible
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

    // Interleave section headings with the windowed rows. Headings are not
    // rows of their own: offsets stay those of [visibleSuggestions].
    final rows = <({String? heading, int index})>[];
    for (var i = 0; i < visible.length; i++) {
      final flatIndex = offset + i;
      rows.add((
        heading: _suggestionHeadingBefore(flatIndex),
        index: flatIndex,
      ));
    }

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
              ? [const Text('No matches', style: TextStyle(color: Colors.gray))]
              : [
                  for (final row in rows) ...[
                    if (row.heading != null)
                      Text(
                        row.heading!,
                        style: TextStyle(
                          color: style.groupHeaderTextColor ?? Colors.gray,
                          backgroundColor: style.groupHeaderBackgroundColor,
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _selectSuggestion(suggestions[row.index]),
                      child: Container(
                        color: row.index == _selectedSuggestionIndex
                            ? style.selectedBackgroundColor
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: RichText(
                          text: TextSpan(
                            children: _highlightedSuggestionRow(
                              prefix: row.index == _selectedSuggestionIndex
                                  ? markerPrefix
                                  : unselectedPrefix,
                              label: suggestions[row.index].displayLabel,
                              query: _suggestionQuery,
                              selected: row.index == _selectedSuggestionIndex,
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
                ],
        ),
      ),
    );
  }

  /// Heading drawn ahead of [flatIndex], or `null` when the row starts no
  /// titled section.
  String? _suggestionHeadingBefore(int flatIndex) {
    var index = 0;
    for (final group in visibleSuggestionGroups) {
      final title = group.title;
      if (title == null) {
        index += group.items.length;
        continue;
      }
      if (index == flatIndex) return title;
      index += group.items.length;
    }
    return null;
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
      final tokenStart = inlineToken.start ?? text.indexOf(inlineToken.token);
      final tokenEnd =
          inlineToken.end ??
          (tokenStart >= 0 ? tokenStart + inlineToken.token.length : -1);
      if (tokenStart >= 0 &&
          tokenEnd > tokenStart &&
          offset >= tokenStart &&
          offset < tokenEnd) {
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
