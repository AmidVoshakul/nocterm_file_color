import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';
import 'package:nocterm/nocterm.dart';

List<FileTextFieldSuggestion> _mockSuggestions(String trigger, String query) {
  final fileConfig = FileConfig.defaultConfig();
  late final List<FileTextFieldSuggestion> suggestions;
  if (trigger == '/') {
    const style = FileStyle(
      text: Colors.brightMagenta,
      background: Colors.magenta,
      bold: true,
    );
    suggestions = [
      FileTextFieldSuggestion.command(name: 'help', style: style),
      FileTextFieldSuggestion.command(name: 'clear', style: style),
      FileTextFieldSuggestion.command(name: 'tmp', style: style),
    ];
  } else {
    const folderStyle = FileStyle(
      text: Colors.brightYellow,
      background: Colors.yellow,
      bold: true,
    );
    const agentStyle = FileStyle(
      text: Colors.brightCyan,
      background: Colors.cyan,
      bold: true,
    );
    final example = FileInfo.fromPath(
      'example/nocterm_file_color_example.dart',
    );
    suggestions = [
      FileTextFieldSuggestion.file(
        example,
        style: fileConfig.styleFor(example),
      ),
      const FileTextFieldSuggestion.folder(
        name: 'example/',
        style: folderStyle,
        searchText: 'example folder',
      ),
      const FileTextFieldSuggestion.folder(
        name: 'lib/',
        style: folderStyle,
        searchText: 'lib folder',
      ),
      const FileTextFieldSuggestion.agent(name: 'explore', style: agentStyle),
      const FileTextFieldSuggestion.agent(name: 'general', style: agentStyle),
      const FileTextFieldSuggestion.agent(
        name: 'code-reviewer',
        style: agentStyle,
      ),
    ];
  }
  final normalizedQuery = query.toLowerCase();
  return suggestions
      .where(
        (suggestion) => suggestion.searchableText.contains(normalizedQuery),
      )
      .toList();
}

void main() {
  group('FileDetector', () {
    test('detects image extensions', () {
      expect(FileDetector.detectType('png'), FileType.image);
      expect(FileDetector.detectType('jpg'), FileType.image);
      expect(FileDetector.detectType('svg'), FileType.image);
    });

    test('detects code extensions', () {
      expect(FileDetector.detectType('dart'), FileType.code);
      expect(FileDetector.detectType('ts'), FileType.code);
      expect(FileDetector.detectType('go'), FileType.code);
    });

    test('detects document extensions', () {
      expect(FileDetector.detectType('pdf'), FileType.document);
      expect(FileDetector.detectType('md'), FileType.document);
      expect(FileDetector.detectType('txt'), FileType.document);
    });

    test('detects archive extensions', () {
      expect(FileDetector.detectType('zip'), FileType.archive);
      expect(FileDetector.detectType('tar'), FileType.archive);
    });

    test('detects audio extensions', () {
      expect(FileDetector.detectType('mp3'), FileType.audio);
      expect(FileDetector.detectType('wav'), FileType.audio);
    });

    test('detects video extensions', () {
      expect(FileDetector.detectType('mp4'), FileType.video);
      expect(FileDetector.detectType('mov'), FileType.video);
    });

    test('returns other for unknown extensions', () {
      expect(FileDetector.detectType('xyz'), FileType.other);
      expect(FileDetector.detectType(''), FileType.other);
    });

    test('normalizes extensions with leading dot and uppercase', () {
      expect(FileDetector.detectType('.PNG'), FileType.image);
      expect(FileDetector.detectType('DART'), FileType.code);
    });
  });

  group('FileInfo', () {
    test('fromPath extracts name and extension', () {
      final file = FileInfo.fromPath('/home/user/lib/main.dart');
      expect(file.name, 'main.dart');
      expect(file.extension, 'dart');
      expect(file.type, FileType.code);
    });

    test('fromPath handles files without extension', () {
      final file = FileInfo.fromPath('/home/user/Makefile');
      expect(file.name, 'Makefile');
      expect(file.extension, '');
      expect(file.type, FileType.other);
    });

    test('fromPath normalizes path separators', () {
      final file = FileInfo.fromPath(r'C:\Users\test\file.txt');
      expect(file.name, 'file.txt');
      expect(file.extension, 'txt');
      expect(file.type, FileType.document);
    });

    test('displayLabel returns image for image type', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      expect(file.displayLabel, 'image');
    });

    test('displayLabel returns name for non-image types', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      expect(file.displayLabel, 'main.dart');
    });

    test('equality is based on all fields', () {
      final a = FileInfo.fromPath('/tmp/test.txt');
      final b = FileInfo.fromPath('/tmp/test.txt');
      expect(a, equals(b));
    });

    test('copyWith returns a new instance with updated fields', () {
      final file = FileInfo.fromPath('/tmp/test.txt');
      final copy = file.copyWith(name: 'renamed.txt');
      expect(copy.name, 'renamed.txt');
      expect(copy.path, file.path);
    });
  });

  group('FileConfig', () {
    test('defaultConfig provides styles for all file types', () {
      final config = FileConfig.defaultConfig();
      for (final type in FileType.values) {
        final file = FileInfo(
          path: 'test.$type',
          name: 'test.$type',
          extension: type.name,
          type: type,
        );
        expect(config.styleFor(file), isNotNull);
      }
    });

    test('styleForExtension returns extension override or null', () {
      final config = FileConfig(
        typeStyles: {FileType.code: const FileStyle(text: Colors.red)},
        extensionStyles: {'dart': const FileStyle(text: Colors.green)},
      );
      expect(config.styleForExtension('dart')?.text, Colors.green);
      expect(
        config.styleForExtension('go'),
        isNull,
      ); // No extension override -> nullension override -> null
    });

    test('styleFor returns null for unknown extension without default', () {
      final config = const FileConfig();
      expect(config.styleForExtension('unknown'), isNull);
    });

    test('FileStyle.toTextStyle converts correctly', () {
      const style = FileStyle(
        text: Colors.red,
        background: Colors.blue,
        bold: true,
      );
      final textStyle = style.toTextStyle();
      expect(textStyle.color, Colors.red);
      expect(textStyle.backgroundColor, Colors.blue);
      expect(textStyle.fontWeight, FontWeight.bold);
    });

    test('FileStyle.copyWith returns updated style', () {
      const style = FileStyle(text: Colors.red);
      final copy = style.copyWith(background: Colors.blue);
      expect(copy.text, Colors.red);
      expect(copy.background, Colors.blue);
    });
  });

  group('FileTag', () {
    test('labelFor returns image prefix for images', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      final style = const FileStyle(prefix: 'image');
      expect(FileTag.labelFor(file, style, index: 1), 'image 1');
    });

    test('tokenFor preserves the image index in the editing token', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      final style = const FileStyle(prefix: 'image');
      expect(FileTag.tokenFor(file, style, index: 1), '[image 1]');
    });

    test('tokenFor uses the stable label of an attached image', () {
      final file = FileInfo.fromPath('/tmp/photo.png')
          .copyWith(name: 'image 3');
      expect(
        FileTag.tokenFor(file, const FileStyle(prefix: 'image')),
        '[image 3]',
      );
    });

    test('token delimiters can be customized or omitted', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      expect(
        FileTag.tokenFor(
          file,
          const FileStyle(openingDelimiter: '', closingDelimiter: ''),
        ),
        'main.dart',
      );
    });

    test('labelFor returns file name for non-images', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      final style = const FileStyle(prefix: 'code');
      expect(FileTag.labelFor(file, style), 'main.dart');
    });
  });

  group('FileOpener', () {
    test('openLocation is a static method', () {
      // Verify the method exists as a static method
      expect(FileOpener.openLocation, isA<Function>());
    });
  });

  group('FileTextField', () {
    test('FileTextField can be instantiated', () {
      // Verify the class exists and can be instantiated
      expect(FileTextField, isA<Type>());
    });

    test(
      'types mention trigger as text when no provider is configured',
      () async {
        final controller = TextEditingController();

        await testNocterm('literal mention without provider', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
          );

          expect(controller.text, '@');
        });

        controller.dispose();
      },
    );

    test(
      'shows trigger text and preserves it when space closes the menu',
      () async {
        final controller = TextEditingController();

        await testNocterm('visible mention trigger', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
              onSuggestionsRequested: _mockSuggestions,
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
          );
          expect(controller.text, '@');
          expect(tester.terminalState, containsText('@'));

          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.space, character: ' '),
          );
          expect(controller.text, '@ ');
          expect(tester.terminalState, containsText('@ '));
          expect(tester.terminalState, isNot(containsText('@explore')));
        });

        controller.dispose();
      },
    );

    test('default slash menu opens mid-text at word boundary', () async {
      final controller = TextEditingController();

      await testNocterm('slash mid-text default', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        for (final character in 'hi'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyA, character: character),
          );
        }
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.space, character: ' '),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );

        expect(controller.text, 'hi /');
        expect(tester.terminalState, containsText('/help'));
      });

      controller.dispose();
    });

    test('slashAnchor startOnly keeps mid-text slash plain', () async {
      final controller = TextEditingController();

      await testNocterm('slash mid-text startOnly', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            slashAnchor: SlashAnchor.startOnly,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        for (final character in 'hi'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyA, character: character),
          );
        }
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.space, character: ' '),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );

        expect(controller.text, 'hi /');
        expect(tester.terminalState, isNot(containsText('/help')));
      });

      controller.dispose();
    });

    test('slashAnchor startOnly opens slash menu at field start', () async {
      final controller = TextEditingController();

      await testNocterm('slash at start startOnly', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            slashAnchor: SlashAnchor.startOnly,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );

        expect(controller.text, '/');
        expect(tester.terminalState, containsText('/help'));
      });

      controller.dispose();
    });

    test('typing an email does not activate the mention menu', () async {
      final controller = TextEditingController();

      await testNocterm('email remains plain input', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        for (final character in 'name@example.com'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyA, character: character),
          );
        }

        expect(controller.text, 'name@example.com');
        expect(tester.terminalState, isNot(containsText('@explore')));
      });

      controller.dispose();
    });

    test(
      'slash-prefixed path remains editable and submits when unmatched',
      () async {
        final controller = TextEditingController();
        String? submitted;

        await testNocterm('slash path does not get swallowed', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              controller: controller,
              focused: true,
              width: 50,
              height: 1,
              onSuggestionsRequested: _mockSuggestions,
              onSubmitted: (value) => submitted = value,
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
          );
          expect(controller.text, '/');
          for (final character in 'tmp/input.txt'.split('')) {
            await tester.sendKeyEvent(
              KeyboardEvent(logicalKey: LogicalKey.keyA, character: character),
            );
          }
          await tester.sendEnter();

          expect(controller.text, '/tmp/input.txt');
          expect(submitted, '/tmp/input.txt');
        });

        controller.dispose();
      },
    );

    test('does not open suggestions for a read-only field', () async {
      final controller = TextEditingController();

      await testNocterm('read-only mention', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            readOnly: true,
            width: 30,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );

        expect(tester.terminalState, isNot(containsText('@explore')));
        expect(controller.text, equals(''));
      });

      controller.dispose();
    });

    test(
      'allows the host app to replace the neutral suggestion menu',
      () async {
        final controller = TextEditingController();

        await testNocterm('custom suggestion menu', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
              onSuggestionsRequested: _mockSuggestions,
              suggestionMenuBuilder: (
                context,
                suggestions,
                selectedIndex,
                onSelected,
              ) => const Text('Application menu'),
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
          );

          expect(tester.terminalState, containsText('Application menu'));
        });

        controller.dispose();
      },
    );

    test(
      'renders the attached file token inline with its configured color',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('inline colored file token', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: false,
              width: 30,
              height: 1,
            ),
          );
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
          await tester.pump();

          expect(controller.text, '[main.dart] ');
          expect(tester.terminalState, containsText('[main.dart]'));
          expect(
            tester.terminalState.getCellAt(1, 0)?.style.color,
            Colors.brightGreen,
          );
        });

        controller.dispose();
      },
    );

    test('inserts numbered image token into the same field', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('inline image token', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/photo.png'));
        await tester.pump();

        expect(controller.text, '[image 1] ');
        expect(tester.terminalState, containsText('[image 1]'));
      });

      controller.dispose();
    });

    test('adds spacing after an attachment token', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('attachment spacing', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));

        expect(controller.text, '[main.dart] ');
      });

      controller.dispose();
    });

    test(
      'backspace at an attachment boundary removes its whole token',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('atomic attachment deletion', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
            ),
          );
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
          controller.selection = const TextSelection.collapsed(offset: 11);
          await tester.sendBackspace();

          expect(controller.text, equals(''));
          expect(key.currentState!.getAttachedFiles(), hasLength(0));
        });

        controller.dispose();
      },
    );

    test(
      'delete at the start of an attachment removes its whole token',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('atomic attachment delete', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
            ),
          );
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
          controller.selection = const TextSelection.collapsed(offset: 0);
          await tester.sendDelete();

          expect(controller.text, equals(''));
          expect(key.currentState!.getAttachedFiles(), hasLength(0));
        });

        controller.dispose();
      },
    );

    test('remains editable after attaching an inline token', () async {
      final controller = TextEditingController(text: 'hello ');
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('editable inline file token', (tester) async {
        await tester.pumpComponent(
          Container(
            width: 30,
            height: 1,
            child: FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
            ),
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.press(0, 0);
        await tester.release(0, 0);
        expect(controller.selection.extentOffset, 0);
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.keyX, character: 'x'),
        );

        expect(controller.text, 'xhello [main.dart] ');
        expect(tester.terminalState, containsText('xhello [main.dart]'));
      });

      controller.dispose();
    });

    test('selects and inserts a filtered agent mention', () async {
      final controller = TextEditingController(text: 'Run ');
      final key = GlobalKey<FileTextFieldState>();
      FileTextFieldSuggestion? selectedSuggestion;

      await testNocterm('agent suggestion', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
            onSuggestionSelected: (suggestion) {
              selectedSuggestion = suggestion;
            },
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'explore'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        expect(tester.terminalState, containsText('@explore'));
        final menuMention = tester.terminalState.findText('@explore').first;
        expect(
          tester.terminalState
              .getCellAt(menuMention.x, menuMention.y)
              ?.style
              .color,
          isNot(Colors.brightCyan),
        );
        await tester.sendEnter();

        expect(controller.text, 'Run [@explore] ');
        expect(selectedSuggestion?.name, 'explore');
        expect(
          tester.terminalState.getCellAt(5, 0)?.style.color,
          Colors.brightCyan,
        );
        expect(
          tester.terminalState.getCellAt(5, 0)?.style.backgroundColor,
          Colors.cyan,
        );
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('selects a mention suggestion by mouse click', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('mouse suggestion selection', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'explore'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        final suggestion = tester.terminalState.findText('@explore').first;
        await tester.tap(suggestion.x, suggestion.y);

        expect(controller.text, '[@explore] ');
      });

      controller.dispose();
    });

    test('selects a mock file and adds it to attached files', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('file suggestion', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 50,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'nocterm_file_color_example.dart'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.sendEnter();

        expect(controller.text, '[nocterm_file_color_example.dart] ');
        expect(
          key.currentState!.getAttachedFiles().single.path,
          'example/nocterm_file_color_example.dart',
        );
      });

      controller.dispose();
    });

    test('selects a mock folder as a colored inline token', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('folder suggestion', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'folder'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.sendEnter();

        expect(controller.text, '[example/] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('navigates filtered suggestions with arrow keys', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('navigate suggestions', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        for (final character in 'folder'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.sendArrowDown();
        await tester.sendEnter();

        expect(controller.text, '[lib/] ');
      });

      controller.dispose();
    });

    test('selects a slash command as a colored inline token', () async {
      final controller = TextEditingController(text: 'Run ');
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('slash command suggestion', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        for (final character in 'help'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.sendEnter();

        expect(controller.text, 'Run [/help] ');
        expect(
          tester.terminalState.getCellAt(5, 0)?.style.color,
          Colors.brightMagenta,
        );
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('special-token delimiters are configurable', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('custom suggestion delimiter', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              FileTextFieldSuggestion.command(
                name: 'help',
                style: const FileStyle(
                  text: Colors.brightMagenta,
                  openingDelimiter: '',
                  closingDelimiter: '',
                ),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.sendEnter();

        expect(controller.text, '/help ');
      });

      controller.dispose();
    });
  });

  group('InlineToken', () {
    test('equality is based on token and style', () {
      const a = InlineToken(
        token: '@x',
        style: FileStyle(text: Colors.red),
      );
      const b = InlineToken(
        token: '@x',
        style: FileStyle(text: Colors.red),
      );
      const c = InlineToken(
        token: '@y',
        style: FileStyle(text: Colors.red),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('FileStyle', () {
    test('equality includes italic and underline', () {
      const full = FileStyle(text: Colors.cyan, italic: true, underline: true);
      const same = FileStyle(text: Colors.cyan, italic: true, underline: true);
      const plain = FileStyle(text: Colors.cyan);
      const italicOnly = FileStyle(text: Colors.cyan, italic: true);
      const underlineOnly = FileStyle(text: Colors.cyan, underline: true);

      expect(full, equals(same));
      expect(full.hashCode, same.hashCode);
      expect(full, isNot(equals(plain)));
      expect(full, isNot(equals(italicOnly)));
      expect(full, isNot(equals(underlineOnly)));
    });
  });

  group('TokenHighlightTextField', () {
    test('can be instantiated', () {
      expect(TokenHighlightTextField, isA<Type>());
    });

    test('colors an inline token occurrence', () async {
      final controller = TextEditingController();

      await testNocterm('colored token', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            tokens: [
              InlineToken(
                token: '@explore',
                style: FileStyle(
                  text: Colors.brightCyan,
                  background: Colors.cyan,
                  bold: true,
                ),
              ),
            ],
          ),
        );
        controller.text = 'use @explore now';
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pump();

        expect(tester.terminalState, containsText('@explore'));
        // 'use @explore now' -> '@' starts at column 4
        expect(
          tester.terminalState.getCellAt(4, 0)?.style.color,
          Colors.brightCyan,
        );
      });

      controller.dispose();
    });

    test('plain text stays neutral without tokens', () async {
      final controller = TextEditingController();

      await testNocterm('plain text neutral', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
          ),
        );
        controller.text = 'hello world';
        await tester.pump();

        expect(tester.terminalState, containsText('hello world'));
        expect(tester.terminalState.getCellAt(0, 0)?.style.color, isNull);
      });

      controller.dispose();
    });

    test('token coloring disappears when token is deleted', () async {
      final controller = TextEditingController();

      await testNocterm('token removed on delete', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            tokens: [
              InlineToken(
                token: '@explore',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = 'use @explore now';
        await tester.pump();

        expect(tester.terminalState, containsText('@explore'));
        expect(
          tester.terminalState.getCellAt(4, 0)?.style.color,
          Colors.brightCyan,
        );

        controller.text = 'use now';
        await tester.pump();

        expect(tester.terminalState, isNot(containsText('@explore')));
        expect(
          tester.terminalState.getCellAt(4, 0)?.style.color,
          isNot(Colors.brightCyan),
        );
      });

      controller.dispose();
    });

    test('every occurrence of a duplicate token is colored', () async {
      final controller = TextEditingController();

      await testNocterm('duplicate tokens colored', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            tokens: [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = '@x and @x';
        await tester.pump();

        expect(tester.terminalState, containsText('@x'));
        // '@x and @x' -> first '@' at col 0, second '@' at col 7
        expect(
          tester.terminalState.getCellAt(0, 0)?.style.color,
          Colors.brightCyan,
        );
        expect(
          tester.terminalState.getCellAt(7, 0)?.style.color,
          Colors.brightCyan,
        );
      });

      controller.dispose();
    });

    test('underline token renders underlined cells', () async {
      final controller = TextEditingController();

      await testNocterm('underline token', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            tokens: const [
              InlineToken(
                token: '@w',
                style: FileStyle(text: Colors.brightCyan, underline: true),
              ),
            ],
          ),
        );
        controller.text = 'see @w here';
        await tester.pump();

        final start = controller.text.indexOf('@w');
        expect(tester.terminalState, containsText('@w'));
        expect(
          tester.terminalState
              .getCellAt(start, 0)
              ?.style
              .decoration
              ?.hasUnderline,
          isTrue,
        );
      });

      controller.dispose();
    });

    test('italic token renders italic cells', () async {
      final controller = TextEditingController();

      await testNocterm('italic token', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            tokens: const [
              InlineToken(
                token: '@i',
                style: FileStyle(text: Colors.brightCyan, italic: true),
              ),
            ],
          ),
        );
        controller.text = 'see @i here';
        await tester.pump();

        final start = controller.text.indexOf('@i');
        expect(tester.terminalState, containsText('@i'));
        expect(
          tester.terminalState.getCellAt(start, 0)?.style.fontStyle,
          FontStyle.italic,
        );
      });

      controller.dispose();
    });

    test('onChanged fires exactly once per controller change', () async {
      final controller = TextEditingController();
      var calls = 0;
      String? lastValue;

      await testNocterm('onChanged forwarded once on key input', (
        tester,
      ) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            tokens: const [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
            onChanged: (value) {
              calls++;
              lastValue = value;
            },
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.keyA, character: 'a'),
        );

        expect(lastValue, 'a');
        expect(calls, 1);
      });

      controller.dispose();
    });

    test(
      'onChanged fires exactly once for programmatic controller edits',
      () async {
        final controller = TextEditingController();
        var calls = 0;
        String? lastValue;

        await testNocterm('onChanged forwarded once on programmatic edit', (
          tester,
        ) async {
          await tester.pumpComponent(
            TokenHighlightTextField(
              controller: controller,
              focused: true,
              width: 30,
              height: 1,
              tokens: const [
                InlineToken(
                  token: '@x',
                  style: FileStyle(text: Colors.brightCyan),
                ),
              ],
              onChanged: (value) {
                calls++;
                lastValue = value;
              },
            ),
          );
          controller.text = 'has @x token';
          await tester.pump();

          expect(lastValue, 'has @x token');
          expect(calls, 1);
          expect(tester.terminalState, containsText('has @x token'));
        });

        controller.dispose();
      },
    );

    test('onSubmitted fires on Enter when focused', () async {
      final controller = TextEditingController();
      String? submitted;

      await testNocterm('onSubmitted on enter', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            onSubmitted: (value) => submitted = value,
          ),
        );
        controller.text = 'hello';
        await tester.pump();
        await tester.sendEnter();

        expect(submitted, 'hello');
      });

      controller.dispose();
    });

    test('obscureText falls back to a plain obscured field', () async {
      final controller = TextEditingController();

      await testNocterm('obscure text no color', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: false,
            width: 30,
            height: 1,
            obscureText: true,
            tokens: [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = '@x';
        await tester.pump();

        expect(tester.terminalState, isNot(containsText('@x')));
        expect(
          tester.terminalState.getCellAt(0, 0)?.style.color,
          isNot(Colors.brightCyan),
        );
      });

      controller.dispose();
    });

    test('cursor emulation runs when focused', () async {
      final controller = TextEditingController();

      await testNocterm('cursor emulation', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            tokens: [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = '@x';
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();

        expect(tester.terminalState, containsText('@x'));
        final cursorCell = tester.terminalState.getCellAt(1, 0);
        expect(cursorCell, isNotNull);
        expect(cursorCell!.style.backgroundColor, isNotNull);
      });

      controller.dispose();
    });
  });

  group('TokenText', () {
    test('renders colored inline tokens without editing', () async {
      await testNocterm('token text colored', (tester) async {
        await tester.pumpComponent(
          TokenText(
            text: 'check @explore and /help',
            tokens: [
              InlineToken(
                token: '@explore',
                style: FileStyle(text: Colors.brightCyan),
              ),
              InlineToken(
                token: '/help',
                style: FileStyle(text: Colors.brightMagenta),
              ),
            ],
            width: 30,
            height: 1,
          ),
        );

        expect(tester.terminalState, containsText('@explore'));
        expect(tester.terminalState, containsText('/help'));
        // 'check @explore and /help' -> '@' at col 6, '/' at col 19
        expect(
          tester.terminalState.getCellAt(6, 0)?.style.color,
          Colors.brightCyan,
        );
        expect(
          tester.terminalState.getCellAt(19, 0)?.style.color,
          Colors.brightMagenta,
        );
      });
    });
  });
}
