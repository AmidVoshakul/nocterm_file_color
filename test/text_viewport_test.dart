import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:nocterm_file_color/src/text_viewport.dart';
import 'package:test/test.dart';

List<String> _rows(NoctermTester tester) =>
    tester.terminalState.getText().split('\n');

Color? _backgroundAt(NoctermTester tester, int column, int row) =>
    tester.terminalState.getCellAt(column, row)?.style.backgroundColor;

Color? _colorAt(NoctermTester tester, int column, int row) =>
    tester.terminalState.getCellAt(column, row)?.style.color;

/// `L01`..`L12`, four characters per line.
String _manyLines([int count = 12]) => List.generate(
  count,
  (i) => 'L${(i + 1).toString().padLeft(2, '0')}',
).join('\n');

void main() {
  group('viewport row math', () {
    test('the caret row is the row its offset lands on', () {
      // ['ab', 'cd'] joined with newlines: a b \n c d.
      final lines = ['ab', 'cd'];
      expect(TextViewportMixin.viewportCaretRow(lines, 0), 0);
      expect(TextViewportMixin.viewportCaretRow(lines, 1), 0);
      expect(TextViewportMixin.viewportCaretRow(lines, 2), 0);
      expect(TextViewportMixin.viewportCaretRow(lines, 3), 1);
      expect(TextViewportMixin.viewportCaretRow(lines, 4), 1);
      expect(TextViewportMixin.viewportCaretRow(lines, 5), 1);
      // Past the last row: the caret clamps to the end.
      expect(TextViewportMixin.viewportCaretRow(lines, 99), 1);
    });

    test('the visible rows are the text rows capped at the maximum', () {
      int visible(int lineCount, int maxLinesVisible) =>
          TextViewportMixin.viewportVisibleRows(
            lineCount: lineCount,
            maxLinesVisible: maxLinesVisible,
          );

      expect(visible(1, 8), 1);
      expect(visible(3, 8), 3);
      expect(visible(8, 8), 8);
      expect(visible(12, 8), 8);
      expect(visible(12, 3), 3);
    });
  });

  group('FileTextField viewport', () {
    test('the field grows with its content up to the cap', () async {
      final controller = TextEditingController();

      await testNocterm('grow to the cap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
          ),
        );

        controller.text = 'L01\nL02\nL03';
        await tester.pump();
        expect(_rows(tester)[0], contains('L01'));
        expect(_rows(tester)[2], contains('L03'));
        expect(
          _rows(tester)[3].trim(),
          isEmpty,
          reason: 'three lines of text is a three row field',
        );

        controller.text = _manyLines();
        await tester.pump();
        expect(
          _rows(tester)[8].trim(),
          isEmpty,
          reason: 'twelve lines of text stop at the eight row cap',
        );
      });

      controller.dispose();
    });

    test('the cap is configurable', () async {
      final controller = TextEditingController();

      await testNocterm('custom cap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            maxLinesVisible: 3,
          ),
        );

        controller.text = _manyLines();
        await tester.pump();

        expect(_rows(tester)[0], contains('L10'));
        expect(_rows(tester)[2], contains('L12'));
        expect(_rows(tester)[3].trim(), isEmpty);
      });

      controller.dispose();
    });

    test('the caret keeps its row in view when it moves up', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('caret follows up', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();
        // The caret starts past the last line: the last row is in view.
        expect(_rows(tester)[7], contains('L12'));

        // Move the caret to the start of the third line.
        controller.selection = const TextSelection.collapsed(offset: 8);
        await tester.pump();

        expect(_rows(tester)[0], contains('L01'));
        expect(_rows(tester)[1], contains('L02'));
        expect(_rows(tester)[2], contains('L03'));
        expect(
          _backgroundAt(tester, 0, 2),
          Colors.brightRed,
          reason: 'the caret paints on the row it moved to',
        );
        expect(
          _rows(tester)[7],
          contains('L08'),
          reason: 'the view scrolled back to the top of the text',
        );
      });

      controller.dispose();
    });

    test('the view scrolls one row ahead of the caret', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('lookahead row', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
          ),
        );
        await tester.pump();

        // Caret at the start of the ninth line (offset 4 per line).
        controller.selection = const TextSelection.collapsed(offset: 32);
        await tester.pump();

        // Rows 4..11 are in view: the caret sits on the fifth visible row
        // with three rows of lookahead below it — the view was already
        // showing the last row when the caret arrived, and the caret never
        // settles on the last visible row.
        expect(_rows(tester)[0], contains('L05'));
        expect(_rows(tester)[4], contains('L09'));
        expect(_rows(tester)[5], contains('L10'));
        expect(_rows(tester)[7], contains('L12'));
      });

      controller.dispose();
    });

    test('a wrapped paragraph grows by its rows', () async {
      final controller = TextEditingController();

      await testNocterm('wrap growth', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 10,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );

        controller.text = '0123456789abcdefghij';
        await tester.pump();

        // The field wraps one column short of its width (the caret column),
        // and the overlay must wrap exactly the same way for the caret row
        // and the row count to agree.
        expect(_rows(tester)[0].trim(), '012345678');
        expect(_rows(tester)[1].trim(), '9abcdefgh');
        expect(_rows(tester)[2].trim(), 'ij');
        expect(_rows(tester)[3].trim(), isEmpty);
        expect(
          _backgroundAt(tester, 2, 2),
          Colors.brightRed,
          reason: 'the caret paints past the last wrapped row',
        );
      });

      controller.dispose();
    });

    test('attachments stay aligned with their row after scrolling', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('tag alignment', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();

        // The token occupies the first row and the overlay paints it.
        expect(_rows(tester)[0], contains('[main.dart]'));
        expect(_backgroundAt(tester, 1, 0), isNotNull);

        // Add lines below it and scroll: the tag row leaves the viewport,
        // so its background goes with it.
        controller.text = '[main.dart] \n${_manyLines()}';
        await tester.pump();
        expect(_rows(tester)[0], isNot(contains('[main.dart]')));
        expect(
          _backgroundAt(tester, 1, 0),
          isNull,
          reason: 'the tag background must not outlive its row',
        );

        // Back to the top: the tag row is painted again, aligned to the
        // overlay it belongs to.
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pump();
        expect(_rows(tester)[0], contains('[main.dart]'));
        expect(_backgroundAt(tester, 1, 0), isNotNull);
      });

      controller.dispose();
    });

    test('the mouse wheel moves the caret row by row', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('wheel moves caret', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();
        // The caret starts past the last line; the view follows it to the
        // bottom of the text.
        expect(_rows(tester)[7], contains('L12'));
        expect(_backgroundAt(tester, 3, 7), Colors.brightRed);

        Future<void> wheel(MouseButton button) async {
          await tester.sendMouseEvent(
            MouseEvent(button: button, x: 5, y: 2, pressed: true),
          );
          await tester.pump();
        }

        // One row up: the caret leads, the view keeps it in view.
        await wheel(MouseButton.wheelUp);
        expect(_rows(tester)[6], contains('L11'));
        expect(_backgroundAt(tester, 3, 6), Colors.brightRed);
        expect(_rows(tester)[7], contains('L12'));

        // Far enough up, the view scrolls with the caret.
        for (var i = 0; i < 3; i++) {
          await wheel(MouseButton.wheelUp);
        }
        expect(_rows(tester)[3], contains('L08'));
        expect(_backgroundAt(tester, 3, 3), Colors.brightRed);

        for (var i = 0; i < 4; i++) {
          await wheel(MouseButton.wheelUp);
        }
        expect(_rows(tester)[0], contains('L02'));
        expect(_rows(tester)[2], contains('L04'));
        expect(_backgroundAt(tester, 3, 2), Colors.brightRed);

        // At the top row the caret has nowhere left to go, and neither has
        // the view — scrolling the other way is never blocked. The caret
        // keeps its column, so it sits at the end of the first row.
        for (var i = 0; i < 3; i++) {
          await wheel(MouseButton.wheelUp);
        }
        expect(_rows(tester)[0], contains('L01'));
        expect(_backgroundAt(tester, 3, 0), Colors.brightRed);

        // Back down the same way.
        for (var i = 0; i < 11; i++) {
          await wheel(MouseButton.wheelDown);
        }
        expect(_rows(tester)[7], contains('L12'));
        expect(_backgroundAt(tester, 3, 7), Colors.brightRed);
        await wheel(MouseButton.wheelDown);
        expect(_rows(tester)[7], contains('L12'));
      });

      controller.dispose();
    });

    test('the boundary arrows jump to the start and the end', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('boundary arrows', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();
        // The caret sits past the last line.
        expect(controller.selection.extentOffset, 47);

        // Up to the first row, one row per arrow.
        for (var i = 0; i < 11; i++) {
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
          );
          await tester.pump();
        }
        // On the first row, mid-line: the next ArrowUp is Home.
        expect(controller.selection.extentOffset, greaterThan(0));
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 0);
        expect(_backgroundAt(tester, 0, 0), Colors.brightRed);

        // Mid the last line, ArrowDown is End.
        controller.selection = const TextSelection.collapsed(offset: 44);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 47);
        expect(_backgroundAt(tester, 3, 7), Colors.brightRed);

        // Mid the first line, ArrowUp is Home.
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 0);

        // With Shift held, the jump extends the selection to Home.
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.arrowUp,
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();
        expect(controller.selection.baseOffset, 1);
        expect(controller.selection.extentOffset, 0);

        // Mid the last line, ArrowDown is End — extended with Shift.
        controller.selection = const TextSelection.collapsed(offset: 44);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.arrowDown,
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();
        expect(controller.selection.baseOffset, 44);
        expect(controller.selection.extentOffset, 47);

        // Mid the text, the arrows keep Nocterm's own row movement — down a
        // row at the caret's target column, no boundary jump.
        controller.selection = const TextSelection.collapsed(offset: 8);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 15);
      });

      controller.dispose();
    });

    test('the wheel keeps the caret column across a short row', () async {
      // The paragraph wraps by its hyphen: `L04-`, then the long runs.
      final controller = TextEditingController(
        text: 'L01\nL02\nSHORT\nL04-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nL05\nL06\nL07\nL08',
      );

      await testNocterm('wheel column', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();
        // Caret near the end of the long run: the row above it is short.
        controller.selection = const TextSelection.collapsed(offset: 37);
        await tester.pump();

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: 5,
            y: 2,
            pressed: true,
          ),
        );
        await tester.pump();
        // The short row cannot hold the caret's column, so the caret sits
        // at its end.
        expect(controller.selection.extentOffset, 18);

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelDown,
            x: 5,
            y: 2,
            pressed: true,
          ),
        );
        await tester.pump();
        // Back down, the caret returns to its own column — not to the short
        // row's end, which is what a column recomputed per notch would do.
        expect(controller.selection.extentOffset, 37);
      });

      controller.dispose();
    });

    test('a single-line field keeps one row', () async {
      final controller = TextEditingController();

      await testNocterm('single line', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            cursorColor: Colors.brightRed,
          ),
        );

        controller.text = 'x' * 60;
        await tester.pump();

        expect(_rows(tester)[0], isNot(isEmpty));
        expect(
          _rows(tester)[1].trim(),
          isEmpty,
          reason: 'a maxLines: 1 field does not grow',
        );
      });

      controller.dispose();
    });

    test('a two row cap keeps the caret in view', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('two row cap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            maxLinesVisible: 2,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();

        // The caret starts past the last line: it paints on the last
        // visible row, never below it.
        expect(_rows(tester)[1], contains('L12'));
        expect(_backgroundAt(tester, 3, 1), Colors.brightRed);
        expect(_rows(tester)[2].trim(), isEmpty);

        // Every row of the text keeps the caret somewhere in the two row
        // window.
        for (var row = 0; row < 12; row++) {
          controller.selection = TextSelection.collapsed(offset: row * 4);
          await tester.pump();
          expect(
            _backgroundAt(tester, 0, 0) != null ||
                _backgroundAt(tester, 0, 1) != null,
            isTrue,
            reason: 'row $row: the caret paints inside the window',
          );
        }
      });

      controller.dispose();
    });

    test('a one row cap shows the caret row alone', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('one row cap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            maxLinesVisible: 1,
            cursorColor: Colors.brightRed,
          ),
        );
        await tester.pump();

        for (var row = 0; row < 12; row++) {
          controller.selection = TextSelection.collapsed(offset: row * 4);
          await tester.pump();
          final label = 'L${(row + 1).toString().padLeft(2, '0')}';
          expect(
            _rows(tester)[0],
            contains(label),
            reason: 'row $row: the only visible row is the caret row',
          );
          expect(_backgroundAt(tester, 0, 0), Colors.brightRed);
          expect(_rows(tester)[1].trim(), isEmpty);
        }
      });

      controller.dispose();
    });

    test('a tap resolves to the row it landed on', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      FileInfo? clicked;

      await testNocterm('row tap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
            onFileClick: (file) => clicked = file,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/pic.png'));
        await tester.pump();
        // Both tokens live in the text; the second one moves two rows down.
        controller.text = '[main.dart] \nsecond\n[image 1] \n${_manyLines(9)}';
        await tester.pump();

        // Caret to the top of the text: the first rows are in view.
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pump();
        expect(_rows(tester)[0], contains('[main.dart]'));
        expect(_rows(tester)[1], contains('second'));
        expect(_rows(tester)[2], contains('[image 1]'));

        // Tap the second token on its own row: the click resolves to the
        // image, not to the first row's dart file.
        await tester.press(2, 2);
        await tester.release(2, 2);
        await tester.pump();
        expect(clicked?.path, '/tmp/pic.png');
      });

      controller.dispose();
    });

    test(
      'a tap resolves against the scrolled view, not the text top',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();
        FileInfo? clicked;

        await testNocterm('scrolled tap', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 20,
              maxLines: null,
              cursorColor: Colors.brightRed,
              onFileClick: (file) => clicked = file,
            ),
          );
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
          await tester.pump();
          // The token sits on the fifth row of the text; the caret past the
          // last line scrolls the view four rows down, so the token's row is
          // the second visible one.
          controller.text = 'L01\nL02\nL03\nL04\nL05\n[main.dart] \nL07\nL08\nL09\nL10\nL11\nL12';
          await tester.pump();
          expect(_rows(tester)[0], contains('L05'));
          expect(_rows(tester)[1], contains('[main.dart]'));

          // Tap the token on the row it is painted on. The tap position is
          // already in the text's own rows — the scroll translation is
          // measured once off the render chain — so the click resolves to the
          // file, not to a row further down the text.
          await tester.press(2, 1);
          await tester.release(2, 1);
          await tester.pump();
          expect(clicked?.path, '/tmp/main.dart');
        });

        controller.dispose();
      },
    );

    test('a tap resolves against the overlay box, not the window', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      FileInfo? clicked;

      await testNocterm('decorated tap', (tester) async {
        await tester.pumpComponent(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: FileTextField(
              key: key,
              controller: controller,
              focused: false,
              width: 40,
              maxLines: null,
              decoration: InputDecoration(
                border: BoxBorder.all(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 1),
              ),
              onFileClick: (file) => clicked = file,
            ),
          ),
        );
        // Two files share the label: the first occupies columns 0-10, the
        // second columns 12-22 of the text.
        key.currentState!.attachFile(
          FileInfo.fromPath('/home/user/a/main.dart'),
        );
        key.currentState!.attachFile(
          FileInfo.fromPath('/home/user/b/main.dart'),
        );
        await tester.pump();
        expect(controller.text, '[main.dart] [main.dart] ');
        // The overlay box sits inside the window padding (3), the decoration
        // border and its content padding (1 each): column 5, row 2.
        expect(_rows(tester)[2], contains('[main.dart]'));

        // A tap on the window's column 14 lands on the text's column 9 —
        // inside the first label, not the second.
        await tester.press(14, 2);
        await tester.release(14, 2);
        await tester.pump();
        expect(clicked?.path, '/home/user/a/main.dart');
      });

      controller.dispose();
    });

    test('an explicit height governs and the cap does not apply', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('explicit height', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            height: 3,
          ),
        );
        await tester.pump();

        // The legacy layout: a three row box whose content overflows it,
        // painted below rather than clipped by a viewport.
        expect(_rows(tester)[3], contains('L04'));
      });

      controller.dispose();
    });
  });

  group('TokenHighlightTextField viewport', () {
    test('the field grows with its content up to the cap', () async {
      final controller = TextEditingController();

      await testNocterm('highlight growth', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            maxLinesVisible: 3,
            tokens: const [
              InlineToken(
                token: 'L01',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );

        controller.text = _manyLines();
        await tester.pump();

        expect(_rows(tester)[0], contains('L10'));
        expect(_colorAt(tester, 0, 0), isNot(Colors.brightCyan));

        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pump();
        expect(_rows(tester)[0], contains('L01'));
        // The caret sits on the token, so its cell paints the caret; the
        // token's own cells around it carry the token's colour.
        expect(_colorAt(tester, 1, 0), Colors.brightCyan);
        expect(_rows(tester)[3].trim(), isEmpty);
      });

      controller.dispose();
    });

    test('the emulated caret paints at the end of a row', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('row-end caret', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/a.dart'));
        await tester.pump();
        controller.text = 'ab\ncd [a.dart]';
        await tester.pump();

        // The caret at the end of the first row sits on its newline: a
        // styled newline paints no cell, so the caret is a space at the end
        // of the row it closes.
        controller.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();
        expect(_backgroundAt(tester, 2, 0), Colors.brightRed);
        expect(_rows(tester)[0], contains('ab'));
        expect(_rows(tester)[1], contains('cd [a.dart]'));
      });

      controller.dispose();
    });

    test('the emulated caret keeps its row in view', () async {
      final controller = TextEditingController();

      await testNocterm('highlight caret', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
            tokens: const [
              InlineToken(
                token: 'L01',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );

        controller.text = _manyLines();
        await tester.pump();

        // The caret sits past the last line, on the last visible row.
        expect(_rows(tester)[7], contains('L12'));
        expect(
          _backgroundAt(tester, 3, 7),
          Colors.brightRed,
          reason: 'the emulated caret paints one row past the text',
        );

        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pump();
        expect(_backgroundAt(tester, 0, 0), Colors.brightRed);
        expect(_rows(tester)[7], contains('L08'));
      });

      controller.dispose();
    });

    test('the wheel and the boundary arrows move the caret', () async {
      final controller = TextEditingController(text: _manyLines());

      await testNocterm('highlight scroll keys', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: null,
            cursorColor: Colors.brightRed,
            tokens: const [
              InlineToken(
                token: 'L01',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        await tester.pump();
        expect(_rows(tester)[7], contains('L12'));

        // The wheel moves the caret a row up, and the view follows it.
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: 5,
            y: 2,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 43);
        expect(_rows(tester)[6], contains('L11'));
        expect(_rows(tester)[7], contains('L12'));

        // Mid the first line, ArrowUp is Home.
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 0);

        // With Shift held, the jump extends the selection instead of
        // collapsing it.
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.arrowUp,
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();
        expect(controller.selection.baseOffset, 1);
        expect(controller.selection.extentOffset, 0);

        // Mid the last line, ArrowDown is End.
        controller.selection = const TextSelection.collapsed(offset: 44);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.selection.extentOffset, 47);

        // With Shift held, the jump extends the selection to the end.
        controller.selection = const TextSelection.collapsed(offset: 44);
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.arrowDown,
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();
        expect(controller.selection.baseOffset, 44);
        expect(controller.selection.extentOffset, 47);
      });

      controller.dispose();
    });
  });
}
