import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

import '../example/nocterm_file_color_example.dart' as example;

/// Row of the composer input.
///
/// The agent line (`<agent> · <model> …`) is the only text that identifies the
/// prompt widget, and the input sits two rows above it: one blank row of
/// spacing above the input, one below it. Searching for the typed text instead
/// is unreliable — the menu rows and the hint line also contain `@`.
int _inputRow(List<String> lines) {
  final agentRow = lines.indexWhere((line) => line.contains('Muse'));
  expect(agentRow, greaterThan(1), reason: 'agent line is rendered');
  return agentRow - 2;
}

void main() {
  group('example composer layout', () {
    test('the demo panel draws section headings', () async {
      await testNocterm('demo headings', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        await tester.enterText('@');
        await tester.pump();
        expect(tester.terminalState, containsText('Files & folders'));

        // Drop into the first folder: the heading gives way to the breadcrumb.
        var browsed = false;
        for (var i = 0; i < 10 && !browsed; i++) {
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
          );
          await tester.pump();
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
          );
          await tester.pump();
          browsed = tester.terminalState.getText().contains('\u2190 back');
        }
        expect(browsed, isTrue, reason: 'a folder must open');
        expect(tester.terminalState, isNot(containsText('Files & folders')));
      });
    });

    test('arrow keys browse into a folder and back', () async {
      await testNocterm('folder browse', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        // Filtering narrows the demo's dynamic list to the agent itself.
        await tester.enterText('@gen');
        await tester.pump();
        expect(tester.terminalState, containsText('@general'));

        // Clear the query so the whole tree is listed again.
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.backspace),
          );
        }
        await tester.pump();

        var browsed = false;
        for (var i = 0; i < 10; i++) {
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
          );
          await tester.pump();
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
          );
          await tester.pump();
          if (tester.terminalState.getText().contains('← back')) {
            browsed = true;
            break;
          }
        }
        expect(browsed, isTrue, reason: 'RightArrow must enter a folder');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowLeft),
        );
        await tester.pump();
        expect(
          tester.terminalState.getText().contains('← back'),
          isFalse,
          reason: 'LeftArrow must return to the root',
        );
      });
    });

    test('composer is pinned to the bottom of the window', () async {
      await testNocterm('bottom-pinned composer', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());

        final lines = tester.terminalState.getText().split('\n');

        // Title stays at the top of the window.
        expect(
          lines.take(5).any((line) => line.contains('nocterm_file_color')),
          isTrue,
        );

        // The input placeholder stays inside the bottom rows.
        final inputRow = lines.lastIndexWhere(
          (line) => line.contains('Type a message'),
        );
        expect(inputRow, greaterThanOrEqualTo(lines.length - 8));
        final topHalf = lines.sublist(0, lines.length ~/ 2).join('\n');
        expect(topHalf.contains('Type a message'), isFalse);
      });
    });

    test('suggestion menu renders above the input row', () async {
      await testNocterm('menu above input', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        // Narrow the demo's dynamic provider to a row that always matches.
        for (final character in 'pubspec'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.pump();
        await tester.pump();
        final lines = tester.terminalState.getText().split('\n');

        // Menu rows are painted above the field's input row: the last menu
        // row sits above the input.
        final lastMenuRow = lines.lastIndexWhere(
          (line) => line.contains('pubspec.yaml'),
        );
        final inputRow = _inputRow(lines);
        expect(lastMenuRow, greaterThan(-1));
        expect(inputRow, greaterThan(lastMenuRow));
      });
    });

    test('input field has an agent-colored left border', () async {
      await testNocterm('agent left border', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        final lines = tester.terminalState.getText().split('\n');

        // Plan is the first agent, so the prompt's border starts yellow.
        final inputRow = lines.indexWhere(
          (line) => line.contains('Type a message'),
        );
        expect(inputRow, greaterThan(-1));
        expect(lines[inputRow].contains('│'), isTrue);
        expect(
          tester.terminalState.getCellAt(2, inputRow)?.style.color,
          Colors.yellow,
        );
      });
    });

    test('menu items render above the input field', () async {
      await testNocterm('menu above field', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'pubspec'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.pump();
        await tester.pump();
        final lines = tester.terminalState.getText().split('\n');

        // Menu rows appear before the input field.
        final menuRow = lines.indexWhere(
          (line) => line.contains('pubspec.yaml'),
        );
        final inputRow = _inputRow(lines);
        expect(menuRow, greaterThan(-1));
        expect(menuRow, lessThan(inputRow));
      });
    });

    test('mention menu floats above the prompt as its own panel', () async {
      await testNocterm('menu own panel', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        // Narrow the demo's dynamic provider to a row that always matches.
        for (final character in 'pubspec'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.pump();
        await tester.pump();
        final lines = tester.terminalState.getText().split('\n');

        // Plan is the first agent, so the prompt's bar starts yellow.
        const menuBorder = Color.fromRGB(46, 46, 50);
        const promptBorder = Colors.yellow;

        final lastMenuRow = lines.lastIndexWhere(
          (line) => line.contains('pubspec.yaml'),
        );
        final inputRow = _inputRow(lines);
        expect(lastMenuRow, greaterThan(-1));
        expect(inputRow, greaterThan(lastMenuRow));

        // The panel carries its own gray left border, ...
        expect(
          tester.terminalState.getCellAt(2, lastMenuRow)?.style.color,
          menuBorder,
        );
        // ...and the prompt below it keeps its own, so the menu is not nested
        // inside the prompt widget.
        expect(
          tester.terminalState.getCellAt(2, inputRow)?.style.color,
          promptBorder,
        );

        // Exactly two blank rows separate the panel from the prompt: one
        // reserved by the menu panel, one by the prompt.
        expect(inputRow - lastMenuRow - 1, 2);
      });
    });
  });
}
