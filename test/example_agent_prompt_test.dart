import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

import '../example/nocterm_file_color_example.dart' as example;

void main() {
  group('example agent prompt', () {
    test('agent prompt line is displayed with initial agent Plan', () async {
      await testNocterm('agent prompt initial', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        final text = tester.terminalState.getText();
        expect(
          text.contains('Plan · Muse Glimmer 30B NVIDIA NIM · max'),
          isTrue,
        );
      });
    });

    test('Tab cycles agent from Plan to Build', () async {
      await testNocterm('agent prompt tab', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        // ensure focused
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.tab),
        );
        await tester.pump();
        final text = tester.terminalState.getText();
        expect(
          text.contains('Build · Muse Glimmer 30B NVIDIA NIM · max'),
          isTrue,
        );
      });
    });

    test('the left border recolors with the active agent', () async {
      const accents = {
        'Plan': Colors.yellow,
        'Build': Colors.blue,
        'Ask': Colors.green,
      };

      await testNocterm('agent border color', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();

        for (final entry in accents.entries) {
          final lines = tester.terminalState.getText().split('\n');
          final inputRow = lines.indexWhere(
            (line) => line.contains('Type a message'),
          );
          final agentRow = lines.indexWhere((line) => line.contains('· Muse'));

          expect(lines[agentRow], contains(entry.key));
          // Column 2 carries the prompt's left border character.
          expect(
            tester.terminalState.getCellAt(2, inputRow)?.style.color,
            entry.value,
          );
          // The agent name on the prompt line uses the same accent.
          expect(
            tester.terminalState.getCellAt(5, agentRow)?.style.color,
            entry.value,
          );

          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.tab),
          );
          await tester.pump();
        }
      });
    });

    test('key hints render keys white and descriptions grey', () async {
      await testNocterm('hint colors', (tester) async {
        await tester.pumpComponent(const example.ComposerDemo());
        await tester.pump();
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.indexWhere((line) => line.contains('switch agent'));
        final line = lines[row];
        expect(row, greaterThan(-1));

        Color? at(int column) =>
            tester.terminalState.getCellAt(column, row)?.style.color;

        for (final key in ['Tab', '@', '/', 'Enter', 'Esc']) {
          final column = line.indexOf(key);
          expect(column, greaterThanOrEqualTo(0), reason: 'hint has $key');
          expect(at(column), Colors.white, reason: '$key is white');
        }

        for (final description in [
          'switch agent',
          'agents and files',
          'commands',
          'send',
          'exit',
        ]) {
          final column = line.indexOf(description);
          expect(column, greaterThanOrEqualTo(0));
          expect(at(column), isNot(Colors.white));
        }
      });
    });

    test('Escape closes the mention menu before it exits', () async {
      var quitCount = 0;
      await testNocterm('escape closes menu', (tester) async {
        await tester.pumpComponent(
          example.ComposerDemo(onQuit: () => quitCount++),
        );
        await tester.pump();
        await tester.enterText('@');
        await tester.pump();
        expect(tester.terminalState, containsText('@explore'));

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.escape),
        );
        await tester.pump();

        // The menu is gone but the typed trigger survives, so Escape was
        // consumed by the field rather than quitting the app.
        expect(tester.terminalState, isNot(containsText('@explore')));
        expect(tester.terminalState, containsText('@'));
        expect(quitCount, 0, reason: 'menu was open, so Escape only closed it');

        // A second Escape, with no menu open, is the one that quits.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.escape),
        );
        await tester.pump();
        expect(quitCount, 1);
      });
    });

    test('Ctrl+C quits via onQuit', () async {
      var quitCount = 0;
      await testNocterm('ctrl+c quits', (tester) async {
        await tester.pumpComponent(
          example.ComposerDemo(onQuit: () => quitCount++),
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyC,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(quitCount, 1);
      });
    });
  });
}
