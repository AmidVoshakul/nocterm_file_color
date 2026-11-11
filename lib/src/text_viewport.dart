import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

/// Grow-then-scroll geometry shared by the text fields of this package.
///
/// Nocterm 0.9.0's [TextField] has no vertical scroll of its own: it lays its
/// text out at the full height the content needs. A field wrapped in a
/// [SingleChildScrollView] therefore grows with its content and scrolls once
/// it outgrows the box, with the scroll view clipping and translating the
/// child for free.
///
/// Keeping the caret visible needs two numbers this mixin derives without
/// duplicating any wrap math: the rows the text occupies, and the row the
/// caret sits on. Both come from the field's own oracle paragraph — the same
/// text laid out at the same width, mounted before the scrolled layers so its
/// layout is always fresh when the scroll views report their metrics.
mixin TextViewportMixin<T extends StatefulComponent> on State<T> {
  /// Key of the hidden paragraph that mirrors the field's text layout.
  final GlobalKey viewportOracleKey = GlobalKey();

  /// Key of the overlay layer, whose origin tap positions are measured from.
  final GlobalKey viewportOverlayKey = GlobalKey();

  final ScrollController _viewportController = ScrollController();

  /// The text the field holds.
  String get viewportText;

  /// The field's selection; the caret is its extent.
  TextSelection get viewportSelection;
  set viewportSelection(TextSelection selection);

  /// How many rows the field grows to before it scrolls.
  int get viewportMaxLinesVisible;

  /// Whether the field holds the focus.
  bool get viewportFocused;

  /// The controller the field and its overlay scroll by.
  ScrollController get viewportController => _viewportController;

  double? _knownMaxScrollExtent;
  double? _knownViewportDimension;

  @override
  void initState() {
    super.initState();
    _viewportController.addListener(_handleViewportMetrics);
  }

  @override
  void dispose() {
    _viewportController.removeListener(_handleViewportMetrics);
    _viewportController.dispose();
    super.dispose();
  }

  /// The scroll views report their metrics from the layout phase, after the
  /// oracle laid the text out. Metrics move when the content or the viewport
  /// changed — text edited, box grown, terminal resized — and that is when
  /// the caret is placed again from the freshest rows. A plain scroll (mouse
  /// wheel, [jumpTo]) leaves the metrics alone, so it keeps its offset.
  void _handleViewportMetrics() {
    final maxScrollExtent = _viewportController.maxScrollExtent;
    final viewportDimension = _viewportController.viewportDimension;
    if (maxScrollExtent == _knownMaxScrollExtent &&
        viewportDimension == _knownViewportDimension) {
      return;
    }
    _knownMaxScrollExtent = maxScrollExtent;
    _knownViewportDimension = viewportDimension;
    syncViewportScroll(
      text: viewportText,
      caretOffset: viewportSelection.extentOffset,
      maxLinesVisible: viewportMaxLinesVisible,
    );
  }

  /// The offset the caret moves to for a boundary arrow key, or `null` when
  /// the key jumps nowhere — the first row acts like Home and the last like
  /// End, the way editors treat the boundary of a multi-line field. Only
  /// meaningful when the field is multi-line; single-line fields keep
  /// Nocterm's own (no) arrow handling.
  int? viewportBoundaryJumpOffset(KeyboardEvent event) {
    final isUp = event.logicalKey == LogicalKey.arrowUp;
    final isDown = event.logicalKey == LogicalKey.arrowDown;
    if (!isUp && !isDown) return null;
    final lines = viewportOracleLines();
    if (lines == null || lines.isEmpty) return null;
    final text = viewportText;
    final offset = viewportSelection.extentOffset.clamp(0, text.length);
    final row = viewportCaretRow(lines, offset);
    if (isUp) {
      if (row != 0 || offset == 0) return null;
      return 0; // Home
    }
    if (row != lines.length - 1 || offset == text.length) return null;
    return text.length; // End
  }

  /// Runs the boundary arrow jump for [event] — collapsed without Shift,
  /// extended to Home/End with it. Returns whether the key was handled, so
  /// mid-text arrows stay with Nocterm's own caret movement.
  bool viewportHandleBoundaryArrow(KeyboardEvent event) {
    final jump = viewportBoundaryJumpOffset(event);
    if (jump == null) return false;
    final selection = viewportSelection;
    viewportSelection = event.isShiftPressed
        ? TextSelection(baseOffset: selection.baseOffset, extentOffset: jump)
        : TextSelection.collapsed(offset: jump);
    return true;
  }

  /// Places the caret for the rows laid out so far. Call from the text
  /// controller's listener: the rows depend on the text, so a pure caret
  /// move already has the right rows, and a text edit is corrected once the
  /// frame's layout reports its metrics.
  void placeCaretInView() {
    syncViewportScroll(
      text: viewportText,
      caretOffset: viewportSelection.extentOffset,
      maxLinesVisible: viewportMaxLinesVisible,
    );
  }

  /// The rows the field shows for [lineCount]: the text's own layout, capped
  /// at [maxLinesVisible].
  static int viewportVisibleRows({
    required int lineCount,
    required int maxLinesVisible,
  }) => math.min(lineCount, maxLinesVisible);

  /// The row the caret sits on for [lines] — the rows the oracle laid out,
  /// whose concatenation with newlines reconstructs the field text.
  static int viewportCaretRow(List<String> lines, int caretOffset) {
    var remaining = caretOffset;
    for (var row = 0; row < lines.length; row++) {
      final length = lines[row].length;
      if (remaining <= length) return row;
      remaining -= length + 1; // the newline between the rows
    }
    return lines.length - 1;
  }

  /// The offset [row] of [lines] starts at.
  static int viewportRowStart(List<String> lines, int row) {
    var start = 0;
    for (var i = 0; i < row; i++) {
      start += lines[i].length + 1; // the newline between the rows
    }
    return start;
  }

  /// The columns a grapheme occupies in a terminal cell run.
  static int terminalColumnWidth(String grapheme) {
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

  /// The visual column the caret holds on its row.
  static int viewportCaretColumn(List<String> lines, int row, int offset) {
    var remaining = offset - viewportRowStart(lines, row);
    var column = 0;
    for (final grapheme in lines[row].characters) {
      if (remaining <= 0) break;
      column += terminalColumnWidth(grapheme);
      remaining -= grapheme.length;
    }
    return column;
  }

  /// The offset of [column] on [row] of [lines], or the row's end when the
  /// column runs past it.
  static int viewportOffsetAtColumn(List<String> lines, int row, int column) {
    final start = viewportRowStart(lines, row);
    var current = 0;
    var offset = start;
    for (final grapheme in lines[row].characters) {
      if (current >= column) break;
      current += terminalColumnWidth(grapheme);
      offset += grapheme.length;
    }
    return math.min(math.max(offset, start), start + lines[row].length);
  }

  /// The column the vertical caret moves preserve, or `null` when none is
  /// held. The wheel and the boundary arrows share it with Nocterm's own
  /// arrows: captured on the first vertical move of a run and kept until an
  /// edit, a tap or a horizontal move resets it, so a caret crossing a short
  /// row comes back to its own column instead of drifting.
  int? _targetColumn;
  bool _movingCaretVertically = false;

  /// Forgets the preserved column after a movement that is not vertical.
  /// Call from the text controller's listener; the mixin's own vertical
  /// moves are recognised and keep the column.
  void resetViewportTargetColumn() {
    if (_movingCaretVertically) return;
    _targetColumn = null;
  }

  /// Moves the caret one row up or down, preserving its column the way the
  /// arrow keys do, and letting the view follow it. This is the single
  /// scroll logic of the field: the caret leads, the view keeps it in view,
  /// so a long text scrolls without the caret ever leaving — or blocking —
  /// the window. At the first or last row the caret has nowhere to go.
  void moveViewportCaretByRows(int direction) {
    final lines = viewportOracleLines();
    if (lines == null || lines.isEmpty) return;
    final text = viewportText;
    final caretOffset = viewportSelection.extentOffset.clamp(0, text.length);
    final caretRow = viewportCaretRow(lines, caretOffset);
    final targetRow = (caretRow + direction).clamp(0, lines.length - 1);
    if (targetRow == caretRow) return; // the edge of the text

    final column =
        _targetColumn ?? viewportCaretColumn(lines, caretRow, caretOffset);
    _targetColumn = column;
    _movingCaretVertically = true;
    viewportSelection = TextSelection.collapsed(
      offset: viewportOffsetAtColumn(lines, targetRow, column),
    );
    _movingCaretVertically = false;
  }

  /// The rows the oracle laid out, or `null` before its first layout.
  ///
  /// Nocterm exports the [RichText] component but not the render object's
  /// type, so the layout is reached dynamically — the members involved are
  /// public on the render objects Nocterm itself creates for the overlay.
  List<String>? viewportOracleLines() {
    try {
      final dynamic context = viewportOracleKey.currentContext;
      if (context == null) return null;
      final dynamic paragraph = context.renderObject;
      if (paragraph == null) return null;
      final dynamic layout = paragraph.selectableLayout;
      if (layout == null) return null;
      final dynamic lines = layout.lines;
      if (lines is! List) return null;
      return lines.cast<String>();
    } on Object {
      // The bridge into the paragraph render object changed shape: keep the
      // field working without caret-following rather than failing the frame.
      return null;
    }
  }

  /// The tap position relative to the overlay's box.
  ///
  /// Nocterm's gesture recognizers receive the raw terminal coordinates, so
  /// the overlay's own origin is measured off its render object's parent
  /// chain — which carries the decoration insets and the scroll translation,
  /// making one conversion correct for every layout.
  Offset viewportLocalTapPosition(Offset terminalPosition) {
    final dynamic context = viewportOverlayKey.currentContext;
    final dynamic renderObject = context?.renderObject;
    if (renderObject is! RenderObject) return Offset.zero;
    var x = 0.0;
    var y = 0.0;
    RenderObject? node = renderObject;
    while (node != null) {
      final parentData = node.parentData;
      if (parentData is BoxParentData) {
        x += parentData.offset.dx;
        y += parentData.offset.dy;
      }
      node = node.parent;
    }
    return Offset(terminalPosition.dx - x, terminalPosition.dy - y);
  }

  /// The scroll offset that keeps [caretRow] in view. The caret is never
  /// allowed to settle on the last visible row: the view scrolls one row
  /// ahead, and one row behind when the caret rises, mirroring the
  /// suggestion menu's edge behavior.
  int viewportScrollOffsetFor({
    required int caretRow,
    required int lineCount,
    required int visibleRows,
  }) {
    final maxOffset = math.max(0, lineCount - visibleRows);
    var offset = math.min(
      math.max(_viewportController.offset.round(), 0),
      maxOffset,
    );
    var position = caretRow - offset;
    while (position >= visibleRows - 2 && offset < maxOffset) {
      offset++;
      position = caretRow - offset;
    }
    while (position <= 1 && offset > 0) {
      offset--;
      position = caretRow - offset;
    }
    return math.min(math.max(offset, 0), maxOffset);
  }

  /// The offset range the view may scroll through while the caret stays in
  /// view: the caret never leaves the window, whichever way the view was
  /// scrolled. A free scroll (mouse wheel) may never cross either bound.
  (int, int) viewportOffsetRange({
    required int caretRow,
    required int lineCount,
    required int visibleRows,
  }) {
    final min = math.max(0, caretRow - visibleRows + 1);
    final max = math.min(caretRow, math.max(0, lineCount - visibleRows));
    return (min, math.max(min, max));
  }

  /// Pulls a scrolled-past-caret view back until the caret is inside the
  /// window again. A no-op while the caret is already in view.
  void clampViewportToCaret() {
    final lines = viewportOracleLines();
    if (lines == null || lines.isEmpty) return;
    final lineCount = lines.length;
    final (min, max) = viewportOffsetRange(
      caretRow: viewportCaretRow(
        lines,
        viewportSelection.extentOffset.clamp(0, viewportText.length),
      ),
      lineCount: lineCount,
      visibleRows: viewportVisibleRows(
        lineCount: lineCount,
        maxLinesVisible: viewportMaxLinesVisible,
      ),
    );
    final offset = _viewportController.offset.clamp(
      min.toDouble(),
      max.toDouble(),
    );
    if (offset != _viewportController.offset) {
      _viewportController.jumpTo(offset);
    }
  }

  /// Applies the caret-following offset. A no-op while the offset already
  /// keeps the caret in view.
  void syncViewportScroll({
    required String text,
    required int caretOffset,
    required int maxLinesVisible,
  }) {
    final lines = viewportOracleLines();
    if (lines == null || lines.isEmpty) return;
    final lineCount = lines.length;
    final caretRow = viewportCaretRow(lines, caretOffset.clamp(0, text.length));
    final next = viewportScrollOffsetFor(
      caretRow: caretRow,
      lineCount: lineCount,
      visibleRows: viewportVisibleRows(
        lineCount: lineCount,
        maxLinesVisible: maxLinesVisible,
      ),
    );
    if (next.toDouble() != _viewportController.offset) {
      _viewportController.jumpTo(next.toDouble());
    }
    clampViewportToCaret();
  }

  /// The grow-then-scroll box every field of this package renders through.
  ///
  /// [layers] receives the wrap widths the two scrolled layers must be sized
  /// to and returns them: the field layer at [fieldWidth] and the colored
  /// overlay (or `null` for a plain field) that the box wraps at
  /// [textWidth]. The box owns the rest — the hidden oracle, the row cap,
  /// the shared scroll controller, the wheel handling and the decoration —
  /// so every field gets the same geometry without repeating it.
  Component buildViewportBox({
    required double? width,
    required InputDecoration? decoration,
    required bool focused,
    required int? maxLines,
    required (Component, Component?) Function(
      double fieldWidth,
      double textWidth,
    )
    layers,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth.toDouble()
            : 80.0;
        final contentWidth = math.min(width ?? available, available);
        final hasDecoration =
            decoration?.border != null || decoration?.fillColor != null;
        final padding = hasDecoration
            ? (decoration?.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 1))
            : null;
        final inset = padding == null ? 0.0 : padding.left + padding.right;
        final fieldWidth = math.max(1, contentWidth - inset).toDouble();
        // Nocterm reserves the last column of a field for the caret block;
        // the overlay must wrap at the same width or the rows drift apart.
        final textWidth = math.max(1, fieldWidth - 1).toDouble();

        final (field, overlay) = layers(fieldWidth, textWidth);
        final children = <Component>[
          // The oracle comes first: the scroll views report their metrics
          // from the layout phase, and the caret-following offset computed
          // then must see the rows of the text laid out in that same frame.
          // It paints nothing: the paragraph paints every row it lays out,
          // so the zero-height box is clipped.
          SizedBox(
            width: textWidth,
            height: 0,
            child: ClipRect(
              child: RichText(
                key: viewportOracleKey,
                text: TextSpan(text: viewportText),
                softWrap: maxLines != 1,
                overflow: TextOverflow.clip,
                maxLines: maxLines,
              ),
            ),
          ),
          _cappedScrollView(
            child: SizedBox(width: fieldWidth, child: field),
          ),
          if (overlay != null)
            _cappedScrollView(
              child: SizedBox(width: textWidth, child: overlay),
            ),
        ];

        // The stack shrink-wraps to its tallest layer, so the box is exactly
        // as tall as the text — up to the cap each layer enforces.
        return MouseRegion(
          // Wheel scrolling moves the caret one row per notch, exactly like
          // the arrow keys do; the view follows the caret. The scroll views'
          // own wheel handling never sees the event — the field's mouse
          // annotation sits on top of theirs.
          onHover: (event) {
            if (!viewportFocused) return; // the caret of an unfocused field
            if (event.button == MouseButton.wheelUp) {
              moveViewportCaretByRows(-1);
            } else if (event.button == MouseButton.wheelDown) {
              moveViewportCaretByRows(1);
            }
          },
          child: Container(
            width: contentWidth,
            padding: padding,
            decoration: hasDecoration
                ? BoxDecoration(
                    border: focused
                        ? (decoration?.focusedBorder ?? decoration?.border)
                        : decoration?.border,
                    color: decoration?.fillColor,
                  )
                : null,
            child: Stack(children: children),
          ),
        );
      },
    );
  }

  /// One scrolled layer: a scroll view the cap holds down.
  ///
  /// The cap belongs inside the stack: the root constraints are tight, and
  /// Nocterm's enforce() clamps a smaller max height up to the terminal
  /// height there. Below the stack the constraints are loose, so the cap
  /// holds and each scroll view shrinks to its content up to it.
  Component _cappedScrollView({required Component child}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: viewportMaxLinesVisible.toDouble(),
      ),
      child: SingleChildScrollView(
        controller: viewportController,
        child: child,
      ),
    );
  }
}
