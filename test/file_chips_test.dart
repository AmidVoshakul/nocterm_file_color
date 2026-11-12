import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// A config with one recognizable color per type.
FileConfig _testConfig() {
  return const FileConfig(
    typeStyles: {
      FileType.document: FileStyle(text: Colors.black, background: Colors.blue),
    },
  );
}

void main() {
  group('FileChips', () {
    test('empty renders nothing', () async {
      await testNocterm('chips empty', (tester) async {
        await tester.pumpComponent(const FileChips(items: []));
        expect(tester.terminalState.getText().trim(), isEmpty);
      });
    });

    test('file chip shows the File label on the config color', () async {
      await testNocterm('chips file', (tester) async {
        await tester.pumpComponent(
          FileChips(
            config: _testConfig(),
            nameBackgroundColor: Colors.brightBlack,
            nameTextColor: Colors.white,
            items: const [FileChipItem(name: 'main.dart')],
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('File'));
        expect(text, contains('main.dart'));
        // Label plate: config background with the dark style text.
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.backgroundColor,
          Colors.blue,
        );
        expect(tester.terminalState.getCellAt(1, 0)?.style.color, Colors.black);
      });
    });

    test('directory chip shows the dir label', () async {
      await testNocterm('chips dir', (tester) async {
        await tester.pumpComponent(
          const FileChips(
            nameBackgroundColor: Colors.brightBlack,
            nameTextColor: Colors.white,
            items: [FileChipItem(name: 'lib/', isDirectory: true)],
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('dir'));
        expect(text, contains('lib/'));
      });
    });

    test('labelBuilder overrides the label', () async {
      await testNocterm('chips label builder', (tester) async {
        await tester.pumpComponent(
          FileChips(
            nameBackgroundColor: Colors.brightBlack,
            labelBuilder: (isDir) => isDir ? 'folder' : 'doc',
            items: [const FileChipItem(name: 'notes.md')],
          ),
        );
        expect(tester.terminalState.getText(), contains('doc'));
      });
    });

    test('a per-item style overrides the config color', () async {
      await testNocterm('chips item style', (tester) async {
        await tester.pumpComponent(
          FileChips(
            config: _testConfig(),
            nameBackgroundColor: Colors.brightBlack,
            items: const [
              FileChipItem(
                name: 'a.dart',
                style: FileStyle(
                  text: Colors.black,
                  background: Colors.magenta,
                ),
              ),
            ],
          ),
        );
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.backgroundColor,
          Colors.magenta,
        );
      });
    });

    test('colors are dropped under NO_COLOR', () async {
      await testNocterm('chips monochrome', (tester) async {
        await tester.pumpComponent(
          FileChips(
            key: const ValueKey('colored'),
            config: _testConfig(),
            nameBackgroundColor: Colors.brightBlack,
            nameTextColor: Colors.white,
            items: const [FileChipItem(name: 'main.dart')],
          ),
        );
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.backgroundColor,
          isNotNull,
        );

        TerminalColors.setNoColorOverride(true);
        // A stateless widget only re-reads the probe on rebuild; a new key
        // forces one.
        await tester.pumpComponent(
          FileChips(
            key: const ValueKey('monochrome'),
            config: _testConfig(),
            nameBackgroundColor: Colors.brightBlack,
            nameTextColor: Colors.white,
            items: const [FileChipItem(name: 'main.dart')],
          ),
        );
        await tester.pump();
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.backgroundColor,
          isNull,
        );
        expect(tester.terminalState.getText(), contains('main.dart'));
      });

      TerminalColors.setNoColorOverride(null);
    });

    test('a tap is reported with its item', () async {
      FileChipItem? tapped;

      await testNocterm('chips tap', (tester) async {
        await tester.pumpComponent(
          FileChips(
            nameBackgroundColor: Colors.brightBlack,
            items: const [FileChipItem(name: 'a.txt')],
            onChipTap: (item) => tapped = item,
          ),
        );
        await tester.press(2, 0);
        await tester.release(2, 0);
        await tester.pump();
      });

      expect(tapped?.name, 'a.txt');
    });

    test('wrap flows chips onto rows', () async {
      await testNocterm('chips wrap', (tester) async {
        await tester.pumpComponent(
          const Center(
            child: SizedBox(
              width: 24,
              child: FileChips(
                wrap: true,
                nameBackgroundColor: Colors.brightBlack,
                items: [
                  FileChipItem(name: 'alpha.txt'),
                  FileChipItem(name: 'beta.txt'),
                  FileChipItem(name: 'gamma.txt'),
                ],
              ),
            ),
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('alpha.txt'));
        expect(text, contains('beta.txt'));
        // Multiple rows: the names live on different terminal rows.
        final rows = <int>{};
        for (var row = 0; row < 24; row++) {
          if (tester.terminalState
              .getText()
              .split('\n')[row]
              .contains('beta')) {
            rows.add(row);
          }
        }
        expect(rows.length, 1);
        expect(
          text.split('\n').indexWhere((l) => l.contains('alpha')),
          isNot(text.split('\n').indexWhere((l) => l.contains('beta'))),
        );
      });
    });

    test('a single row scrolls horizontally when wrap is off', () async {
      await testNocterm('chips scroll', (tester) async {
        await tester.pumpComponent(
          const SizedBox(
            width: 20,
            child: FileChips(
              wrap: false,
              nameBackgroundColor: Colors.brightBlack,
              items: [
                FileChipItem(name: 'alpha.txt'),
                FileChipItem(name: 'beta.txt'),
              ],
            ),
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('alpha.txt'));
        // Both chips stay on the first row; the second is clipped by the box.
        expect(text.split('\n')[1].trim(), isEmpty);
      });
    });
  });
}
