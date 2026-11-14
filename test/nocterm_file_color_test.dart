import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';
import 'package:nocterm/nocterm.dart' hide isEmpty;

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
      const FileTextFieldSuggestion.command(name: 'help', style: style),
      const FileTextFieldSuggestion.command(name: 'clear', style: style),
      const FileTextFieldSuggestion.command(name: 'tmp', style: style),
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

    test('extensionsFor lists the extensions of a type', () {
      final code = FileDetector.extensionsFor(FileType.code);

      expect(code, contains('dart'));
      expect(code, contains('go'));
      // Unmodifiable: the internal table cannot be mutated by hosts.
      expect(() => code.add('nope'), throwsUnsupportedError);
      // Unknown types come back empty rather than null.
      expect(FileDetector.extensionsFor(FileType.other), isNotNull);
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

    test('copyWith keeps every field it is not given', () {
      final file = const FileInfo(
        path: '/tmp/a.txt',
        name: 'a.txt',
        extension: 'txt',
        type: FileType.document,
        size: 12,
      );
      final copy = file.copyWith(size: 99);

      expect(copy.path, file.path);
      expect(copy.name, file.name);
      expect(copy.extension, file.extension);
      expect(copy.type, file.type);
      expect(copy.size, 99);
      expect(copy, file.copyWith(size: 99));
    });

    test('equality and hashCode cover every field', () {
      final a = FileInfo.fromPath('/tmp/test.txt');
      final b = FileInfo.fromPath('/tmp/test.txt');
      final c = a.copyWith(size: 1);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString reports the path, name and type', () {
      final file = FileInfo.fromPath('/tmp/main.dart');

      expect(
        file.toString(),
        'FileInfo(path: /tmp/main.dart, name: main.dart, '
        'extension: dart, type: code, size: null)',
      );
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
      final config = const FileConfig(
        typeStyles: {FileType.code: FileStyle(text: Colors.red)},
        extensionStyles: {'dart': FileStyle(text: Colors.green)},
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

    test('typeStyles and extensionStyles expose unmodifiable maps', () {
      final config = const FileConfig(
        typeStyles: {FileType.code: FileStyle(text: Colors.green)},
        extensionStyles: {'DART': FileStyle(text: Colors.blue)},
      );

      // Extension keys are normalized to lowercase without a dot.
      expect(config.typeStyles.keys, [FileType.code]);
      expect(config.extensionStyles.keys, ['dart']);
      expect(
        () => config.typeStyles[FileType.document] = const FileStyle(),
        throwsUnsupportedError,
      );

      // An empty config still hands out empty maps.
      expect(const FileConfig().typeStyles, hasLength(0));
      expect(const FileConfig().extensionStyles, hasLength(0));
    });

    test('styleFor prefers the extension override over the type default', () {
      final config = const FileConfig(
        typeStyles: {FileType.code: FileStyle(text: Colors.green)},
        extensionStyles: {'dart': FileStyle(text: Colors.red)},
      );
      final dart = FileInfo.fromPath('/tmp/main.dart');

      expect(config.styleFor(dart).text, Colors.red);
    });

    test('styleFor falls back to a neutral style for an unknown type', () {
      final config = const FileConfig();
      final file = const FileInfo(
        path: 'mystery.xyz',
        name: 'mystery.xyz',
        extension: 'xyz',
        type: FileType.other,
      );

      expect(config.styleFor(file), const FileStyle());
      expect(config.styleForType(FileType.other), const FileStyle());
    });

    test('equality ignores map ordering and nulls', () {
      const red = FileStyle(text: Colors.red);
      const blue = FileStyle(text: Colors.blue);

      final a = const FileConfig(
        typeStyles: {FileType.code: red, FileType.document: blue},
        extensionStyles: {'dart': red},
      );
      final b = const FileConfig(
        typeStyles: {FileType.document: blue, FileType.code: red},
        extensionStyles: {'dart': red},
      );
      final c = const FileConfig(
        typeStyles: {FileType.code: red},
        extensionStyles: {'dart': red},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));

      // Null maps are only equal to null maps.
      expect(const FileConfig(), const FileConfig());
      expect(const FileConfig(), isNot(a));
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

    test('labelFor falls back to the prefix when no index is given', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      final style = const FileStyle(prefix: 'image');

      // An image that already carries a numbered name keeps it.
      final named = file.copyWith(name: 'image 3');
      expect(FileTag.labelFor(named, style), 'image 3');
      // Anything else falls back to the bare prefix.
      expect(FileTag.labelFor(file, style), 'image');
    });

    test('label getter matches labelFor', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      final tag = FileTag(file: file, style: const FileStyle());

      expect(tag.label, FileTag.labelFor(file, const FileStyle()));
    });

    test('renders the token text with the configured colors', () async {
      await testNocterm('file tag render', (tester) async {
        final file = FileInfo.fromPath('/tmp/main.dart');
        await tester.pumpComponent(
          FileTag(
            file: file,
            style: const FileStyle(
              text: Colors.brightGreen,
              background: Colors.green,
            ),
          ),
        );

        expect(tester.terminalState, containsText('[main.dart]'));
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.color,
          Colors.brightGreen,
        );
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.backgroundColor,
          Colors.green,
        );
      });
    });

    test('reports a tap with the represented file', () async {
      FileInfo? tapped;
      final file = FileInfo.fromPath('/tmp/main.dart');

      await testNocterm('file tag tap', (tester) async {
        await tester.pumpComponent(
          FileTag(
            file: file,
            style: const FileStyle(),
            onTap: (value) => tapped = value,
          ),
        );
        await tester.press(0, 0);
        await tester.release(0, 0);

        expect(tapped, file);
      });
    });
  });

  group('FileOpener', () {
    test('openLocation is a static method', () {
      // Verify the method exists as a static method
      expect(FileOpener.openLocation, isA<Function>());
    });

    test('SuggestionMenuStyle default equals another default', () async {
      expect(const SuggestionMenuStyle(), const SuggestionMenuStyle());
      expect(
        const SuggestionMenuStyle().hashCode,
        const SuggestionMenuStyle().hashCode,
      );
    });

    test('SuggestionMenuStyle equality is field-wise', () async {
      const base = SuggestionMenuStyle();
      const other = SuggestionMenuStyle(
        backgroundColor: Colors.red,
        border: null,
        selectedBackgroundColor: Colors.blue,
        selectedTextColor: Colors.green,
        itemTextColor: Colors.yellow,
        descriptionColor: Colors.grey,
        highlightMarker: '>',
        highlightMarkerColor: Colors.magenta,
        padding: EdgeInsets.zero,
      );

      expect(base, isNot(other));
      expect(base == other, isFalse);
      expect(base.hashCode == other.hashCode, isFalse);
      expect(other, other);

      // Each later field on its own, so equality walks the whole chain.
      final perField = <String, SuggestionMenuStyle>{
        'selectedBackgroundColor': base.copyWith(
          selectedBackgroundColor: Colors.red,
        ),
        'selectedTextColor': base.copyWith(selectedTextColor: Colors.red),
        'itemTextColor': base.copyWith(itemTextColor: Colors.red),
        'descriptionColor': base.copyWith(descriptionColor: Colors.red),
        'highlightMarker': base.copyWith(highlightMarker: '>'),
        'highlightMarkerColor': base.copyWith(highlightMarkerColor: Colors.red),
        'padding': base.copyWith(padding: EdgeInsets.zero),
      };
      perField.forEach((field, style) {
        expect(base, isNot(style), reason: '$field takes part in equality');
        expect(base.hashCode, isNot(style.hashCode), reason: '$field hashes');
      });
    });

    test('SuggestionMenuStyle copyWith overrides single fields', () async {
      const base = SuggestionMenuStyle();
      final changed = base.copyWith(
        backgroundColor: Colors.red,
        highlightMarker: '>',
      );

      expect(changed.backgroundColor, Colors.red);
      expect(changed.highlightMarker, '>');
      expect(changed.selectedBackgroundColor, base.selectedBackgroundColor);
      expect(changed.border, base.border);
    });

    test('SuggestionMenuStyle copyWith can drop the border', () async {
      const base = SuggestionMenuStyle();
      expect(base.copyWith(clearBorder: true).border, isNull);
      // Passing a border explicitly still wins over the existing one.
      final border = BoxBorder.all(color: Colors.red);
      expect(base.copyWith(border: border).border, border);
    });

    test('FileOpener rejects an empty path', () {
      expect(
        () => FileOpener.buildLocationCommand(''),
        throwsA(
          isA<FileOpenerException>().having(
            (error) => error.message,
            'message',
            'Cannot open an empty path.',
          ),
        ),
      );
    });

    test('FileOpener rejects a path that does not exist', () {
      expect(
        () => FileOpener.buildLocationCommand('/no/such/file/at/all.txt'),
        throwsA(
          isA<FileOpenerException>()
              .having(
                (error) => error.message,
                'message',
                contains('does not exist'),
              )
              .having(
                (error) => error.path,
                'path',
                '/no/such/file/at/all.txt',
              ),
        ),
      );
    });

    test('FileOpener builds the platform command for an existing file', () {
      final directory = Directory.systemTemp.createTempSync();
      final file = File('${directory.path}/main.dart')..writeAsStringSync('//');
      final command = FileOpener.buildLocationCommand(file.path);

      if (Platform.isWindows) {
        expect(command.first, 'explorer');
      } else if (Platform.isMacOS) {
        expect(command, ['open', '-R', file.path]);
      } else {
        expect(command, ['xdg-open', directory.path]);
      }
      directory.deleteSync(recursive: true);
    });

    test('FileOpenerException renders with and without a path', () {
      const withPath = FileOpenerException('boom', path: '/tmp/x');
      const without = FileOpenerException('boom');

      expect('$withPath', 'FileOpenerException: boom (path: /tmp/x)');
      expect('$without', 'FileOpenerException: boom');
    });
  });

  group('FileTextField', () {
    test('FileTextField can be instantiated', () {
      // Verify the class exists and can be instantiated
      expect(FileTextField, isA<Type>());
    });

    test(
      'typing @ in the middle of text keeps the following character',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('trigger mid text', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 40,
              height: 1,
              onSuggestionsRequested: (trigger, query) => [
                const FileTextFieldSuggestion.agent(name: 'explore'),
              ],
            ),
          );
          controller.text = 'hello world';
          controller.selection = const TextSelection.collapsed(offset: 6);
          await tester.pump();

          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
          );
          await tester.pump();

          expect(controller.text, 'hello @world');

          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.enter),
          );
          await tester.pump();

          expect(controller.text, 'hello [@explore] world');
        });

        controller.dispose();
      },
    );

    test('typing a trigger replaces the selection', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('trigger over selection', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.agent(name: 'explore'),
            ],
          ),
        );
        controller.text = 'hello world';
        controller.selection = const TextSelection(
          baseOffset: 6,
          extentOffset: 11,
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(controller.text, 'hello @');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();

        expect(controller.text, 'hello [@explore] ');
      });

      controller.dispose();
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

    test('modifier enter inserts a newline in a multiline field', () async {
      const modifiers = {
        'ctrl': ModifierKeys(ctrl: true),
        'shift': ModifierKeys(shift: true),
        'alt': ModifierKeys(alt: true),
      };

      final controller = TextEditingController();

      await testNocterm('modifier enter newline', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 4,
            maxLines: 4,
          ),
        );

        for (final entry in modifiers.entries) {
          controller.text = 'ab';
          controller.selection = const TextSelection.collapsed(offset: 2);
          await tester.pump();

          await tester.sendKeyEvent(
            KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: entry.value,
            ),
          );
          await tester.pump();

          expect(
            controller.text,
            'ab\n',
            reason: '${entry.key}+Enter must insert a line break',
          );
          expect(
            controller.selection.extentOffset,
            3,
            reason: 'caret must sit after the inserted ${entry.key} break',
          );
        }
      });

      controller.dispose();
    });

    test('plain enter still submits a multiline field', () async {
      final controller = TextEditingController();
      String? submitted;

      await testNocterm('plain enter submits multiline', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 3,
            maxLines: 3,
            onSubmitted: (value) => submitted = value,
          ),
        );
        controller.text = 'ab';
        await tester.pump();

        await tester.sendEnter();

        expect(submitted, 'ab');
        expect(controller.text, 'ab');
      });

      controller.dispose();
    });

    test('the menu query honors maxLength', () async {
      final controller = TextEditingController();

      await testNocterm('menu max length', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            maxLength: 8,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.agent(name: 'explore'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(controller.text, '@');

        for (final character in 'abcdefg'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
          await tester.pump();
        }

        // '@' + 7 chars = 8, so the last one is refused.
        expect(controller.text, '@abcdefg');
      });

      controller.dispose();
    });

    test('non-file suggestions survive a folder browse', () async {
      final controller = TextEditingController();

      await testNocterm('browse keeps non-file rows', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            // Built the way hosts build them — through the models — so a
            // path leaking into a non-file row fails here, not in the wild.
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(name: 'lib/', path: 'lib'),
              const AgentInfo(
                name: 'explore',
                description: 'Reads code.',
                path: '.claude/agents/explore.md',
              ).toSuggestion(),
              const CommandInfo(
                name: 'help',
                description: 'Shows help.',
                path: '.claude/commands/help.md',
              ).toSuggestion(),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('@explore'));

        // Drop into the folder: only pathless (non-file) rows must remain.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('@explore'));
        expect(tester.terminalState, containsText('/help'));
        expect(tester.terminalState, isNot(containsText('lib/')));
      });

      controller.dispose();
    });

    test('arrows keep the caret still even with no matches', () async {
      final controller = TextEditingController();

      await testNocterm('arrows with no matches', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => const [],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('No matches'));
        final offset = controller.selection.extentOffset;

        for (final key in const [
          LogicalKey.arrowLeft,
          LogicalKey.arrowRight,
          LogicalKey.arrowUp,
          LogicalKey.arrowDown,
        ]) {
          await tester.sendKeyEvent(KeyboardEvent(logicalKey: key));
          await tester.pump();
        }

        expect(controller.selection.extentOffset, offset);
      });

      controller.dispose();
    });

    test('kitty ctrl+j inserts a newline in a multiline field', () async {
      final controller = TextEditingController();

      await testNocterm('kitty ctrl+j newline', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 3,
            maxLines: 3,
          ),
        );
        controller.text = 'ab';
        controller.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();

        // Kitty terminals deliver Ctrl+J as `CSI 106;5u`, which parses as
        // keyJ+ctrl rather than a bare byte 0x0A.
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyJ,
            character: 'j',
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, 'ab\n');
        expect(controller.selection.extentOffset, 3);
      });

      controller.dispose();
    });

    test('modified enter replaces a selected range with a newline', () async {
      final controller = TextEditingController();

      await testNocterm('selection newline', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 3,
            maxLines: 3,
          ),
        );
        controller.text = 'abcd';
        controller.selection = const TextSelection(
          baseOffset: 1,
          extentOffset: 3,
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.enter,
            character: '\n',
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();

        expect(controller.text, 'a\nd');
        expect(controller.selection.extentOffset, 2);
      });

      controller.dispose();
    });

    test('modified enter closes the menu and inserts a newline', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('menu newline', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 30,
            height: 3,
            maxLines: 3,
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(key.currentState!.isSuggestionMenuOpen, isTrue);

        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.enter,
            character: '\n',
            modifiers: ModifierKeys(shift: true),
          ),
        );
        await tester.pump();

        expect(key.currentState!.isSuggestionMenuOpen, isFalse);
        expect(controller.text, '@\n');
        expect(controller.selection.extentOffset, 2);
      });

      controller.dispose();
    });

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

    test('suggestionMenuPlacement.host renders no in-place menu', () async {
      final controller = TextEditingController();

      await testNocterm('host menu placement', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: _mockSuggestions,
            suggestionMenuPlacement: SuggestionMenuPlacement.host,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );

        // The widget keeps the menu state but paints nothing itself.
        expect(tester.terminalState, isNot(containsText('@explore')));
        expect(
          tester.terminalState,
          containsText('@'), // the trigger is typed into the field
        );
      });

      controller.dispose();
    });

    test('suggestions without a style fall back to a kind default', () async {
      const agent = FileTextFieldSuggestion.agent(name: 'explore');
      const command = FileTextFieldSuggestion.command(name: 'help');
      const folder = FileTextFieldSuggestion.folder(name: 'lib/');

      expect(agent.style, FileTextFieldSuggestion.defaultAgentStyle);
      expect(command.style, FileTextFieldSuggestion.defaultCommandStyle);
      expect(folder.style, FileTextFieldSuggestion.defaultFolderStyle);

      const custom = FileStyle(text: Colors.red);
      expect(
        const FileTextFieldSuggestion.agent(
          name: 'explore',
          style: custom,
        ).style,
        custom,
      );
    });

    test('the default style colors the inserted token', () async {
      final controller = TextEditingController();

      await testNocterm('default style token', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => const [
              FileTextFieldSuggestion.agent(name: 'explore'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.sendEnter();

        expect(controller.text, '[@explore] ');
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.color,
          FileTextFieldSuggestion.defaultAgentStyle.text,
        );
      });

      controller.dispose();
    });

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
            Colors.black,
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

    test('reuses the image index freed by deleting a token', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('image index reuse', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 2,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/a.png'));
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/b.png'));
        expect(controller.text, '[image 1] [image 2] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(2));

        // Remove the second token with Backspace: it must detach the file
        // too, otherwise the index would still be taken.
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.sendBackspace();
        expect(controller.text, '[image 1] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(1));

        // The freed number is available again, not skipped.
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/c.png'));
        expect(controller.text, '[image 1] [image 2] ');
        expect(
          key.currentState!.getAttachedFiles().map((f) => f.name),
          containsAll(['image 1', 'image 2']),
        );
      });

      controller.dispose();
    });

    test('image indices stay unique after deleting the first one', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('image index uniqueness', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 2,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/a.png'));
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/b.png'));
        expect(controller.text, '[image 1] [image 2] ');

        // Drop the first token by hand; the second keeps its number.
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.sendDelete();
        expect(controller.text, '[image 2] ');

        // The caret sits at offset 0 after the deletion, so the new token is
        // inserted first and takes the number the deleted file gave up.
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/c.png'));
        expect(controller.text, '[image 1] [image 2] ');
        expect(
          key.currentState!.getAttachedFiles().map((f) => f.name).toSet(),
          {'image 1', 'image 2'},
        );
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
            onSuggestionSelected: (FileTextFieldSuggestion suggestion) {
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

    test('exposes visibleSuggestions only while the menu is open', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('visible suggestions state', (tester) async {
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
        expect(key.currentState!.visibleSuggestions, hasLength(0));
        expect(key.currentState!.selectedSuggestionIndex, -1);
        expect(key.currentState!.isSuggestionMenuOpen, isFalse);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        expect(key.currentState!.isSuggestionMenuOpen, isTrue);
        expect(
          key.currentState!.visibleSuggestions.map((s) => s.name),
          containsAll([
            'example/',
            'lib/',
            'explore',
            'general',
            'code-reviewer',
          ]),
        );

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.space, character: ' '),
        );
        await tester.pump();

        expect(key.currentState!.visibleSuggestions, hasLength(0));
        expect(key.currentState!.selectedSuggestionIndex, -1);
      });

      controller.dispose();
    });

    test('selectedSuggestionIndex follows arrow keys', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('selected suggestion index', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.agent(
                name: 'a',
                style: FileStyle(),
              ),
              const FileTextFieldSuggestion.agent(
                name: 'b',
                style: FileStyle(),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        expect(key.currentState!.selectedSuggestionIndex, 0);
        await tester.sendArrowDown();
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);
        await tester.sendArrowUp();
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('selectSuggestion inserts the token and closes the menu', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('programmatic suggestion selection', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.agent(
                name: 'explore',
                style: FileStyle(),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        final menu = key.currentState!.visibleSuggestions;
        expect(menu, hasLength(1));
        key.currentState!.selectSuggestion(menu.first);
        await tester.pump();

        expect(controller.text, '[@explore] ');
        expect(key.currentState!.visibleSuggestions, hasLength(0));
        expect(key.currentState!.isSuggestionMenuOpen, isFalse);
      });

      controller.dispose();
    });

    test('selectSuggestion ignores a suggestion that is not visible', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('select unknown suggestion', (tester) async {
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
        await tester.pump();

        key.currentState!.selectSuggestion(
          const FileTextFieldSuggestion.agent(
            name: 'not-in-the-menu',
            style: FileStyle(),
          ),
        );
        await tester.pump();

        expect(controller.text, '@');
        expect(key.currentState!.isSuggestionMenuOpen, isTrue);
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
              const FileTextFieldSuggestion.command(
                name: 'help',
                style: FileStyle(
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

    test('pasting a file path attaches it', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('paste attaches path', (tester) async {
        // testNocterm clears the clipboard on entry, so seed it here.
        ClipboardManager.copy('/tmp/main.dart');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );

        expect(controller.text, '[main.dart] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(1));
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/tmp/main.dart',
        );
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('pasting plain text leaves the attachments alone', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('paste plain text', (tester) async {
        ClipboardManager.copy('hello world');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );

        expect(controller.text, 'hello world');
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('pasting several paths attaches each one', () async {
      for (final separator in ['\n', ' ']) {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('paste multiple paths ($separator)', (tester) async {
          ClipboardManager.copy('/tmp/a.txt$separator/tmp/b.txt');
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 60,
              height: 2,
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(
              logicalKey: LogicalKey.keyV,
              modifiers: ModifierKeys(ctrl: true),
            ),
          );

          expect(
            controller.text,
            '[a.txt] [b.txt] ',
            reason:
                'paths separated by ${separator == '\n' ? 'newline' : 'space'}',
          );
          expect(key.currentState!.getAttachedFiles(), hasLength(2));
        });

        controller.dispose();
      }

      ClipboardManager.clear();
    });

    test('pasting several paths attaches them in one batch', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      var notifications = 0;
      final sizes = <int>[];

      await testNocterm('paste batch notifications', (tester) async {
        ClipboardManager.copy('/tmp/a.txt\n/tmp/b.txt\n/tmp/c.txt');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 3,
            onFilesChanged: (files) {
              notifications++;
              sizes.add(files.length);
            },
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );

        expect(key.currentState!.getAttachedFiles(), hasLength(3));
        expect(
          notifications,
          1,
          reason: 'a batch is one notification, not one per file',
        );
        expect(sizes, [3], reason: 'a host never sees a partial batch');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('a pasted path containing a space stays whole', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('path with a space', (tester) async {
        ClipboardManager.copy('/home/user/My Docs/notes.txt');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 2,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );

        expect(controller.text, '[notes.txt] ');
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/home/user/My Docs/notes.txt',
        );
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('attachFilePaths attaches by path strings', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('batch paths', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        key.currentState!.attachFilePaths(['/tmp/a.txt', '/tmp/b.txt']);
        await tester.pump();

        expect(key.currentState!.getAttachedFiles().map((file) => file.name), [
          'a.txt',
          'b.txt',
        ]);
        expect(controller.text, '[a.txt] [b.txt] ');
      });

      controller.dispose();
    });

    test('an empty batch keeps the field untouched', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      var notifications = 0;

      await testNocterm('empty batch', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onFilesChanged: (_) => notifications++,
          ),
        );
        key.currentState!.attachFiles(const []);
        await tester.pump();

        expect(controller.text, '');
        expect(notifications, 0);
      });

      controller.dispose();
    });

    test('a batch numbers its images without gaps', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('batch images', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        key.currentState!.attachFiles([
          FileInfo.fromPath('/tmp/1.png'),
          FileInfo.fromPath('/tmp/2.png'),
          FileInfo.fromPath('/tmp/3.png'),
        ]);
        await tester.pump();

        expect(key.currentState!.getAttachedFiles().map((file) => file.name), [
          'image 1',
          'image 2',
          'image 3',
        ]);
        expect(controller.text, '[image 1] [image 2] [image 3] ');
      });

      controller.dispose();
    });

    test('attachFiles inserts the batch in one rebuild', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      var notifications = 0;

      await testNocterm('batch attach', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onFilesChanged: (_) => notifications++,
          ),
        );
        key.currentState!.attachFiles([
          FileInfo.fromPath('/tmp/a.txt'),
          FileInfo.fromPath('/tmp/b.txt'),
        ]);
        await tester.pump();

        expect(key.currentState!.getAttachedFiles().map((file) => file.name), [
          'a.txt',
          'b.txt',
        ]);
        expect(controller.text, '[a.txt] [b.txt] ');
        expect(notifications, 1, reason: 'one notification for the batch');
      });

      controller.dispose();
    });

    test('attachFilePath attaches a file by path string', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('attachFilePath', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
          ),
        );
        key.currentState!.attachFilePath('/tmp/main.dart');

        expect(controller.text, '[main.dart] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(1));
      });

      controller.dispose();
    });

    test('detachFile removes the token and the attachment', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('detach file', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
          ),
        );
        final file = FileInfo.fromPath('/tmp/main.dart');
        key.currentState!.attachFile(file);
        expect(key.currentState!.getAttachedFiles(), hasLength(1));

        key.currentState!.detachFile(file);

        expect(controller.text, hasLength(0));
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('clearAttachments empties the field and the list', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('clear attachments', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 2,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/a.txt'));
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/b.txt'));
        expect(key.currentState!.getAttachedFiles(), hasLength(2));

        key.currentState!.clearAttachments();

        expect(controller.text, hasLength(0));
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('deleting a token by hand detaches its file', () async {
      final controller = TextEditingController(text: 'a [main.dart] b');
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('token deleted by hand', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        expect(key.currentState!.getAttachedFiles(), hasLength(1));

        // The host removes the token text itself: no key event involved.
        controller.text = 'a  b';
        await tester.pump();

        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('onFilesChanged reports additions and removals', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      final seen = <int>[];

      await testNocterm('files changed callback', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
            onFilesChanged: (files) => seen.add(files.length),
          ),
        );
        final file = FileInfo.fromPath('/tmp/main.dart');
        key.currentState!.attachFile(file);
        key.currentState!.detachFile(file);

        expect(seen, [1, 0]);
      });

      controller.dispose();
    });

    test('tapping a file token reports onFileClick', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      FileInfo? clicked;

      await testNocterm('token click', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
            onFileClick: (file) => clicked = file,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();

        // The token starts at column 0 of the field.
        await tester.press(0, 0);
        await tester.release(0, 0);

        expect(clicked?.path, '/tmp/main.dart');
      });

      controller.dispose();
    });

    test('backspace at the start of a query removes the trigger', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('backspace removes trigger', (tester) async {
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
        expect(key.currentState!.isSuggestionMenuOpen, isTrue);

        await tester.sendBackspace();

        expect(controller.text, hasLength(0));
        expect(key.currentState!.isSuggestionMenuOpen, isFalse);
      });

      controller.dispose();
    });

    test('the default menu reports when nothing matches', () async {
      final controller = TextEditingController();

      await testNocterm('no matches', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            // An empty candidate list keeps the menu open but empty.
            onSuggestionsRequested: (trigger, query) => const [],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );

        expect(tester.terminalState, containsText('No matches'));
      });

      controller.dispose();
    });

    test('menu reopens when a previously empty query matches again', () async {
      final controller = TextEditingController();

      await testNocterm('reopen menu', (tester) async {
        await tester.pumpComponent(
          FileTextField(
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
        await tester.pump();
        expect(tester.terminalState, containsText('/help'));

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.keyZ, character: 'z'),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('No matches'));

        await tester.sendBackspace();
        await tester.pump();
        expect(tester.terminalState, containsText('/help'));
      });

      controller.dispose();
    });

    List<FileTextFieldSuggestion> mixedSuggestions(
      String trigger,
      String query,
    ) => [
      const FileTextFieldSuggestion.folder(name: 'lib/', path: 'lib'),
      FileTextFieldSuggestion.file(
        FileInfo.fromPath('README.md'),
        style: const FileStyle(),
      ),
      const FileTextFieldSuggestion.agent(name: 'explore'),
      const FileTextFieldSuggestion.session(name: 'ses_abc'),
    ];

    test('default grouping titles each kind group at the root', () async {
      final controller = TextEditingController();

      await testNocterm('default grouping', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        expect(tester.terminalState, containsText('Files & folders'));
        expect(tester.terminalState, containsText('Agents'));
        expect(tester.terminalState, containsText('Sessions'));
      });

      controller.dispose();
    });

    test('the file group carries no title while browsing a folder', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('browsing titles', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 8,
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();

        expect(key.currentState!.currentBasePath, 'lib');
        expect(tester.terminalState, isNot(containsText('Files & folders')));
        expect(tester.terminalState, containsText('Agents'));
        expect(tester.terminalState, containsText('Sessions'));
      });

      controller.dispose();
    });

    test('a single group renders without a title', () async {
      final controller = TextEditingController();

      await testNocterm('single group', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.command(name: 'help'),
              const FileTextFieldSuggestion.command(name: 'model'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        expect(tester.terminalState, isNot(containsText('Commands')));
      });

      controller.dispose();
    });

    test('showHeaders false renders no titles', () async {
      final controller = TextEditingController();

      await testNocterm('headers off', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionGrouping: const SuggestionMenuGrouping(
              showHeaders: false,
            ),
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        expect(tester.terminalState, isNot(containsText('Files & folders')));
        expect(tester.terminalState, isNot(containsText('Agents')));
        expect(tester.terminalState, isNot(containsText('Sessions')));
      });

      controller.dispose();
    });

    test('custom grouping renames and reorders groups', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('custom grouping', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionGrouping: const SuggestionMenuGrouping(
              groups: [
                SuggestionMenuGroup('Assistants', [
                  FileTextFieldSuggestionKind.agent,
                ]),
                SuggestionMenuGroup('Project', [
                  FileTextFieldSuggestionKind.file,
                  FileTextFieldSuggestionKind.folder,
                ]),
              ],
            ),
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        expect(tester.terminalState, containsText('Assistants'));
        expect(tester.terminalState, containsText('Project'));
        // The session kind is not grouped, so it falls into `Other`.
        expect(tester.terminalState, containsText('Other'));
      });

      controller.dispose();
    });

    test('visibleSuggestionGroups exposes titles and items', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('group views', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        final groups = key.currentState!.visibleSuggestionGroups;
        expect(groups.map((g) => g.title), [
          'Files & folders',
          'Agents',
          'Sessions',
        ]);
        expect(groups.first.items, hasLength(2));
      });

      controller.dispose();
    });

    test('titles do not shift the selection index', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('group selection', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: mixedSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        // Flat order: lib/, README.md, @explore, @session ses_abc.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);
        expect(
          key
              .currentState!
              .visibleSuggestions[key.currentState!.selectedSuggestionIndex]
              .name,
          'README.md',
        );

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 2);
      });

      controller.dispose();
    });

    test('suggestion menu windows to suggestionPageSize rows', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('window size', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        // only 3 rows rendered
        expect(tester.terminalState, containsText('cmd0'));
        expect(tester.terminalState, containsText('cmd1'));
        expect(tester.terminalState, containsText('cmd2'));
        expect(tester.terminalState, isNot(containsText('cmd3')));
      });

      controller.dispose();
    });

    test(
      'suggestion scroll triggers at second-to-last row by default',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('scroll trigger', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 40,
              height: 1,
              suggestionPageSize: 4,
              onSuggestionsRequested: (trigger, query) => List.generate(
                10,
                (i) => FileTextFieldSuggestion.command(
                  name: 'cmd$i',
                  style: const FileStyle(),
                ),
              ),
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
          );
          await tester.pump();

          // move down to the second-to-last visible (index 2 of window = cmd2)
          await tester.sendArrowDown();
          await tester.pump();
          await tester.sendArrowDown();
          await tester.pump();
          // selected = cmd2 (second-to-last of 4) -> scroll should fire
          expect(key.currentState!.selectedSuggestionIndex, 2);
          await tester.sendArrowDown();
          await tester.pump();
          // after scroll, window shifts; cmd3 should now be visible
          expect(tester.terminalState, containsText('cmd3'));
        });

        controller.dispose();
      },
    );

    test('suggestion cyclic scroll false clamps at the end', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('no cyclic', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            suggestionCyclicScroll: false,
            onSuggestionsRequested: (trigger, query) => List.generate(
              5,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        for (var i = 0; i < 10; i++) {
          await tester.sendArrowDown();
          await tester.pump();
        }
        expect(key.currentState!.selectedSuggestionIndex, 4);
      });

      controller.dispose();
    });

    test('page down and page up move by pageSize', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('page keys', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            suggestionCyclicScroll: false,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.pageDown),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 3);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.pageUp),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('home and end jump to first and last', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('home end', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            suggestionCyclicScroll: false,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.end),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 9);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.home),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('mouse wheel moves suggestion selection', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('wheel', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelDown,
            x: 1,
            y: 1,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);
      });

      controller.dispose();
    });

    test('highlightSuggestion moves the keyboard highlight by index', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('highlight by index', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => const [
              FileTextFieldSuggestion.agent(name: 'explore'),
              FileTextFieldSuggestion.agent(name: 'general'),
              FileTextFieldSuggestion.command(name: 'help'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);

        key.currentState!.highlightSuggestion(2);
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 2);

        // Out-of-range indexes clamp — a host must not crash the field.
        key.currentState!.highlightSuggestion(99);
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 2);
        key.currentState!.highlightSuggestion(-5);
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('highlightSuggestion never pre-scrolls a visible row', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      final items = [
        for (var i = 0; i < 20; i++)
          FileTextFieldSuggestion.file(
            FileInfo(
              path: 'f$i.dart',
              name: 'f$i.dart',
              extension: 'dart',
              type: FileType.code,
            ),
            style: const FileStyle(),
          ),
      ];

      await testNocterm('hover no pre-scroll', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 8,
            onSuggestionsRequested: (trigger, query) => items,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        // Arrow keys scroll by the threshold, as they should.
        for (var i = 0; i < 8; i++) {
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
          );
          await tester.pump();
        }
        final offset = key.currentState!.suggestionScrollOffset;
        expect(offset, greaterThan(0));

        // Hover the LAST row of the visible window: no scroll, no drift.
        key.currentState!.highlightSuggestion(
          offset + key.currentState!.suggestionPageSize - 1,
        );
        await tester.pump();
        expect(key.currentState!.suggestionScrollOffset, offset);
        expect(
          key.currentState!.selectedSuggestionIndex,
          offset + key.currentState!.suggestionPageSize - 1,
        );

        // A row outside the window still scrolls into view.
        key.currentState!.highlightSuggestion(19);
        await tester.pump();
        expect(key.currentState!.suggestionScrollOffset, greaterThan(offset));
      });

      controller.dispose();
    });

    test('default suggestion menu has no highlight marker', () async {
      final controller = TextEditingController();

      await testNocterm('no marker', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.command(
                name: 'help',
                style: FileStyle(),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        expect(tester.terminalState, containsText('help'));
        expect(tester.terminalState, isNot(containsText('> help')));
      });

      controller.dispose();
    });

    test(
      'suggestion menu style applies marker, colors and no border',
      () async {
        final controller = TextEditingController();

        await testNocterm('styled menu', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              controller: controller,
              focused: true,
              width: 40,
              height: 1,
              suggestionMenuStyle: const SuggestionMenuStyle(
                border: null,
                highlightMarker: '>',
                selectedBackgroundColor: Colors.magenta,
                selectedTextColor: Colors.white,
                itemTextColor: Colors.green,
                padding: EdgeInsets.zero,
              ),
              onSuggestionsRequested: (trigger, query) => [
                const FileTextFieldSuggestion.command(
                  name: 'help',
                  style: FileStyle(),
                ),
              ],
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
          );
          await tester.pump();

          // marker present
          expect(tester.terminalState, containsText('> /help'));
        });

        controller.dispose();
      },
    );

    test('large multiline paste collapses into a pasted tag', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('paste collapse', (tester) async {
        final lines = List.generate(5, (i) => 'line $i').join('\n');
        ClipboardManager.copy(lines);
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 4,
            maxLines: 10,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~5 lines] ');
        expect(key.currentState!.getPastedTexts(), hasLength(1));
        expect(key.currentState!.getPastedTexts().single, lines);
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('small paste stays as plain text', () async {
      final controller = TextEditingController();

      await testNocterm('small paste', (tester) async {
        ClipboardManager.copy('hello world');
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, 'hello world');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('large single-line paste collapses by character count', () async {
      final controller = TextEditingController();

      await testNocterm('char collapse', (tester) async {
        ClipboardManager.copy('a' * 600);
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~1 line] ');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('deleting a pasted tag removes the whole chunk', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('delete pasted', (tester) async {
        ClipboardManager.copy('a\nb\nc\nd');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 4,
            maxLines: 10,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(controller.text, '[Pasted ~4 lines] ');

        await tester.sendBackspace();
        await tester.pump();
        expect(controller.text, '');
        expect(key.currentState!.getPastedTexts(), hasLength(0));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('onSubmitted receives expanded text', () async {
      final controller = TextEditingController();
      String? submitted;

      await testNocterm('submit expanded', (tester) async {
        ClipboardManager.copy('a\nb\nc\nd');
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 4,
            maxLines: 10,
            onSubmitted: (value) => submitted = value,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        await tester.sendEnter();
        await tester.pump();

        expect(submitted, 'a\nb\nc\nd');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('prose mentioning paths is not treated as attachments', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('prose paste', (tester) async {
        ClipboardManager.copy(
          '''
Inline file attachments – paste a path or attach programmatically; [lib/main.dart] and [image 1] labels are colored in place; Backspace removes a token and detaches the file as one unit.
Colored tokens – InlineToken entries paint @mentions, /commands, or any substring; styles support colors, bold, italic, underline, and square, custom, or no brackets around the label.
Host-owned suggestion menus – the application supplies @ and / candidates (FileTextFieldSuggestion.file, .folder, .agent, .command); the field filters, selects, and inserts them.''',
        );
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 10,
            maxLines: 10,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(
          key.currentState!.getAttachedFiles(),
          hasLength(0),
          reason: 'prose must not be attached as files',
        );
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('identical pasted labels keep their own spans', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('duplicate pasted labels', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        // Two identical 4-line pastes: both collapse to the same label text.
        ClipboardManager.copy('a\nb\nc\nd');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        ClipboardManager.copy('e\nf\ng\nh');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~4 lines] [Pasted ~4 lines] ');
        // Each label expands to its own chunk, not the first one twice.
        expect(key.currentState!.getExpandedText(), 'a\nb\nc\nd e\nf\ng\nh');

        // Backspace on the second label removes that span only.
        controller.selection = const TextSelection.collapsed(offset: 35);
        await tester.pump();
        await tester.sendBackspace();
        await tester.pump();

        expect(controller.text, '[Pasted ~4 lines] ');
        expect(key.currentState!.getPastedTexts(), hasLength(1));
        expect(key.currentState!.getPastedTexts().single, 'a\nb\nc\nd');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('a path list on one line still attaches every path', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('path list', (tester) async {
        ClipboardManager.copy('/tmp/a.txt /tmp/b.txt');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[a.txt] [b.txt] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(2));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('deleting a pasted tag keeps the separator the user typed', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('keep typed separator', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        controller.text = 'hi ';
        controller.selection = const TextSelection.collapsed(offset: 3);
        await tester.pump();

        ClipboardManager.copy('a\nb\nc\nd');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        // The tag brings its own trailing separator, so typing continues
        // without extra spaces.
        expect(controller.text, 'hi [Pasted ~4 lines] ');
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.keyX, character: 'x'),
        );
        await tester.pump();
        expect(controller.text, 'hi [Pasted ~4 lines] x');

        // Deleting the tag takes only the tag and its own separator: the
        // space typed before it survives and `x` stays put.
        controller.selection = const TextSelection.collapsed(offset: 20);
        await tester.pump();
        await tester.sendBackspace();
        await tester.pump();
        expect(controller.text, 'hi x');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('deleting a file tag keeps the separator the user typed', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('keep typed separator file', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        controller.text = 'hi ';
        controller.selection = const TextSelection.collapsed(offset: 3);
        await tester.pump();

        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        expect(controller.text, 'hi [main.dart] ');

        controller.selection = const TextSelection.collapsed(offset: 15);
        await tester.pump();
        await tester.sendBackspace();
        await tester.pump();
        expect(controller.text, 'hi ');
      });

      controller.dispose();
    });

    test('paste collapse counts lines on the trimmed text', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('trimmed line count', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        // A trailing newline must not add a line to the label.
        ClipboardManager.copy('a\nb\nd\n');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~3 lines] ');
        expect(key.currentState!.getPastedTexts(), hasLength(1));
        expect(key.currentState!.getPastedTexts().single, 'a\nb\nd');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('a long few-line paste collapses too', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('long few lines', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        // Two very long lines: under the line threshold, over the char one.
        ClipboardManager.copy('${'x' * 100}\n${'y' * 100}');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~2 lines] ');
        expect(key.currentState!.getPastedTexts(), hasLength(1));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('short two-line pastes stay as text', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('short few lines', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        ClipboardManager.copy('a\nb');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, 'a\nb');
        expect(key.currentState!.getPastedTexts(), hasLength(0));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('collapsed paste stores the trimmed text', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('trimmed storage', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        ClipboardManager.copy('  a\nb\nc  ');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, '[Pasted ~3 lines] ');
        expect(key.currentState!.getPastedTexts().single, 'a\nb\nc');
        expect(key.currentState!.getExpandedText(), 'a\nb\nc');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test(
      'creates and disposes its own controller when none is given',
      () async {
        await testNocterm('owned controller', (tester) async {
          await tester.pumpComponent(
            const FileTextField(focused: true, width: 40, height: 1),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.keyA, character: 'a'),
          );
          expect(tester.terminalState, containsText('a'));

          // Unmounting runs the state's dispose path for the owned controller.
          await tester.pumpComponent(const SizedBox());
        });
      },
    );

    test('backspace at a token start also removes the leading space', () async {
      final controller = TextEditingController(text: 'x');
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('backspace eats leading space', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        // Inserting after 'x' yields 'x [main.dart] '.
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        expect(controller.text, 'x [main.dart] ');

        await tester.sendBackspace();

        // Backspace at the token also swallows the space that precedes it.
        expect(controller.text, 'x ');
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test('mouse wheel up moves the selection back', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('wheel up', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelDown,
            x: 1,
            y: 1,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: 1,
            y: 1,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('a non-cyclic menu stops the wheel at the first row', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('wheel no cyclic', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionCyclicScroll: false,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: 1,
            y: 1,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelDown,
            x: 1,
            y: 1,
            pressed: true,
          ),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);
      });

      controller.dispose();
    });

    test('cyclic page keys wrap around the ends', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('cyclic page keys', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionPageSize: 3,
            suggestionCyclicScroll: true,
            onSuggestionsRequested: (trigger, query) => List.generate(
              10,
              (i) => FileTextFieldSuggestion.command(
                name: 'cmd$i',
                style: const FileStyle(),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.pageUp),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 7);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.pageDown),
        );
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('a row matched by searchText renders without a highlight', () async {
      final controller = TextEditingController();

      await testNocterm('match by search text', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            // The file rows carry `searchText: '<name> file'`, so the query
            // matches them without appearing in the label.
            onSuggestionsRequested: _mockSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        for (final character in 'file'.split('')) {
          await tester.sendKeyEvent(
            KeyboardEvent(logicalKey: LogicalKey.keyE, character: character),
          );
        }
        await tester.pump();

        // All five file rows stay listed; no label contains the query.
        expect(
          tester.terminalState,
          containsText('nocterm_file_color_example.dart'),
        );
        expect(tester.terminalState, isNot(containsText('file[main.dart]')));
      });

      controller.dispose();
    });

    test('the host reads the menu style from the state', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('state style', (tester) async {
        const style = SuggestionMenuStyle(highlightMarker: '»');
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionMenuStyle: style,
          ),
        );

        expect(key.currentState!.suggestionMenuStyle, style);
      });

      controller.dispose();
    });

    test(
      'a non-cyclic menu stops moveSuggestionHighlight at the ends',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('linear highlight move', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 40,
              height: 1,
              suggestionCyclicScroll: false,
              onSuggestionsRequested: (trigger, query) => List.generate(
                3,
                (i) => FileTextFieldSuggestion.command(
                  name: 'cmd$i',
                  style: const FileStyle(),
                ),
              ),
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
          );
          await tester.pump();

          key.currentState!.moveSuggestionHighlight(-1);
          await tester.pump();
          expect(key.currentState!.selectedSuggestionIndex, 0);

          key.currentState!.moveSuggestionHighlight(5);
          await tester.pump();
          expect(key.currentState!.selectedSuggestionIndex, 2);
        });

        controller.dispose();
      },
    );

    test('the inline cursor blinks once a token is present', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('inline blink', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            cursorBlinkRate: const Duration(milliseconds: 50),
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        controller.text = '[main.dart] ab';
        // Caret on the plain text, where the cell has no background of its own.
        controller.selection = const TextSelection.collapsed(offset: 12);
        await tester.pump();

        // Phase-independent: the caret must be observed both on and off.
        Color? backgroundColor() =>
            tester.terminalState.getCellAt(12, 0)?.style.backgroundColor;
        final seen = <Color?>{};
        for (var i = 0; i < 4; i++) {
          seen.add(backgroundColor());
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(
          seen.whereType<Color>().isNotEmpty && seen.contains(null),
          isTrue,
          reason: 'the caret blinks between visible and hidden phases',
        );
      });

      controller.dispose();
    });

    test('swapping the controller keeps tokens in sync', () async {
      final first = TextEditingController(text: '[main.dart] ab');
      final second = TextEditingController(text: 'plain');
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('swap field controller', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: first,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        expect(key.currentState!.getAttachedFiles(), hasLength(1));

        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: second,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        // The attachment follows the text it came with.
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
        expect(second.text, 'plain');
      });

      first.dispose();
      second.dispose();
    });

    test('pressing Enter with no matches closes the menu', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('enter with no matches', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => const [],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('No matches'));

        await tester.sendEnter();
        await tester.pump();

        expect(key.currentState!.isSuggestionMenuOpen, isFalse);
        expect(tester.terminalState, isNot(containsText('No matches')));
      });

      controller.dispose();
    });

    test('a submit without collapsed pastes passes the text through', () async {
      final controller = TextEditingController();
      String? submitted;

      await testNocterm('submit passthrough', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 60,
            height: 3,
            maxLines: 3,
            onSubmitted: (value) => submitted = value,
          ),
        );
        controller.text = 'hello ';
        await tester.pump();

        await tester.sendEnter();
        await tester.pump();

        expect(submitted, 'hello ');
      });

      controller.dispose();
    });

    test('a submit with a collapsed paste drops the tag separator', () async {
      final controller = TextEditingController();
      String? submitted;

      await testNocterm('submit collapses separator', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 60,
            height: 3,
            maxLines: 3,
            onSubmitted: (value) => submitted = value,
          ),
        );
        ClipboardManager.copy('a\nb\nc\n');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(controller.text, '[Pasted ~3 lines] ');

        await tester.sendEnter();
        await tester.pump();

        expect(submitted, 'a\nb\nc');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('the char threshold pins >= exactly', () async {
      final controller = TextEditingController();

      await testNocterm('char boundary', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 60,
            height: 1,
          ),
        );
        ClipboardManager.copy('a' * 149);
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(controller.text, 'a' * 149);

        ClipboardManager.copy('a' * 150);
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        // The 149-char paste from before stays in the field.
        expect(controller.text, '${'a' * 149} [Pasted ~1 line] ');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('disabling paste collapse inserts the paste verbatim', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('collapse disabled', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 8,
            maxLines: 8,
            enablePasteCollapse: false,
          ),
        );
        ClipboardManager.copy('a\nb\nc\nd\ne\nf');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        expect(controller.text, 'a\nb\nc\nd\ne\nf');
        expect(key.currentState!.getPastedTexts(), hasLength(0));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('right arrow drops into a folder and left arrow leaves it', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('folder navigation', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(
                name: 'lib/',
                path: 'lib',
                searchText: 'lib folder',
              ),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/main.dart'),
                path: 'lib/main.dart',
                style: const FileStyle(),
              ),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/src/main.dart'),
                path: 'lib/src/main.dart',
                style: const FileStyle(),
              ),
              const FileTextFieldSuggestion.agent(name: 'explore'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        // The root lists everything; agents keep no path so they stay.
        expect(key.currentState!.navigationDepth, 1);
        expect(key.currentState!.canNavigateBack, isFalse);
        expect(key.currentState!.currentBasePath, isNull);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();

        // Only `lib`'s direct child remains (plus the agent).
        expect(key.currentState!.currentBasePath, 'lib');
        expect(key.currentState!.canNavigateBack, isTrue);
        expect(key.currentState!.navigationDepth, 2);
        expect(
          key.currentState!.visibleSuggestions.map((s) => s.path ?? s.name),
          ['lib/main.dart', 'explore'],
        );

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowLeft),
        );
        await tester.pump();

        expect(key.currentState!.currentBasePath, isNull);
        expect(
          key.currentState!.visibleSuggestions.map((s) => s.path ?? s.name),
          ['lib', 'lib/main.dart', 'lib/src/main.dart', 'explore'],
        );
      });

      controller.dispose();
    });

    test('entering a folder clears the query from the field', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('query cleared on enter', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(
                name: 'lib/',
                path: 'lib',
                searchText: 'lib folder',
              ),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/main.dart'),
                path: 'lib/main.dart',
                style: const FileStyle(),
              ),
            ],
          ),
        );
        // A query that still matches the folder row.
        await tester.enterText('@li');
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();

        expect(controller.text, '@');
        expect(key.currentState!.currentBasePath, 'lib');
      });

      controller.dispose();
    });

    test('the child filter respects the path boundary', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('path boundary', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(
                name: 'lib/',
                path: 'lib',
                searchText: 'lib folder',
              ),
              // A sibling that merely starts with the folder's name.
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('library.txt'),
                path: 'library.txt',
                style: const FileStyle(),
              ),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/main.dart'),
                path: 'lib/main.dart',
                style: const FileStyle(),
              ),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/src/main.dart'),
                path: 'lib/src/main.dart',
                style: const FileStyle(),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();

        expect(
          key.currentState!.visibleSuggestions.map((s) => s.path ?? s.name),
          ['lib/main.dart'],
        );
      });

      controller.dispose();
    });

    test('right arrow on a non-folder row does not navigate', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('no folder navigation', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(name: 'lib/', path: 'lib'),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('README.md'),
                path: 'README.md',
                style: const FileStyle(),
              ),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        // Highlight the file row, then try to drop into it.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowRight),
        );
        await tester.pump();

        expect(key.currentState!.currentBasePath, isNull);
      });

      controller.dispose();
    });

    test('left arrow at the root does not navigate back', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('root left arrow', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(name: 'lib/', path: 'lib'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowLeft),
        );
        await tester.pump();

        expect(key.currentState!.navigationDepth, 1);
        expect(key.currentState!.currentBasePath, isNull);
      });

      controller.dispose();
    });

    test('the caret stays put while the menu is open', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('caret locked by menu', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.folder(name: 'lib/', path: 'lib'),
              FileTextFieldSuggestion.file(
                FileInfo.fromPath('lib/main.dart'),
                path: 'lib/main.dart',
                style: const FileStyle(),
              ),
              const FileTextFieldSuggestion.agent(name: 'explore'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();
        final offset = controller.selection.extentOffset;

        // None of the navigation keys move the caret while the menu owns them.
        for (final key_ in const [
          LogicalKey.arrowLeft,
          LogicalKey.arrowRight,
          LogicalKey.arrowUp,
          LogicalKey.arrowDown,
          LogicalKey.home,
          LogicalKey.end,
          LogicalKey.pageUp,
          LogicalKey.pageDown,
        ]) {
          await tester.sendKeyEvent(KeyboardEvent(logicalKey: key_));
          await tester.pump();
        }

        expect(controller.selection.extentOffset, offset);
        // Navigation did happen (the first RightArrow dropped into `lib`), and
        // a LeftArrow after the loop still finds its way back out.
        expect(key.currentState!.currentBasePath, 'lib');
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowLeft),
        );
        await tester.pump();
        expect(key.currentState!.currentBasePath, isNull);
        expect(controller.selection.extentOffset, offset);
      });

      controller.dispose();
    });

    test('a selection over a token paints the selection color', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('selection highlight', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            selectionColor: Colors.red,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        controller.text = '[main.dart] ab';
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 5,
        );
        await tester.pump();

        for (final column in [2, 3, 4]) {
          expect(
            tester.terminalState.getCellAt(column, 0)?.style.backgroundColor,
            Colors.red,
            reason: 'column $column is inside the selection',
          );
        }
        expect(
          tester.terminalState.getCellAt(6, 0)?.style.backgroundColor,
          isNot(Colors.red),
        );
      });

      controller.dispose();
    });

    test('an underline cursor renders underlined cells', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('underline cursor', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            cursorStyle: CursorStyle.underline,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        controller.text = '[main.dart] ab';
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(1, 0)?.style.decoration,
          TextDecoration.underline,
        );
        expect(
          tester.terminalState.getCellAt(5, 0)?.style.decoration,
          isNot(TextDecoration.underline),
        );
      });

      controller.dispose();
    });

    test('expansion survives edits before the tag', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('expansion after edits', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        ClipboardManager.copy('a\nb\nc\nd');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();

        // Typing before the tag drifts its stored range.
        controller.text = 'AB[Pasted ~4 lines] x';
        await tester.pump();

        expect(key.currentState!.getExpandedText(), 'ABa\nb\nc\nd x');
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('expandPastedText puts the full text back in the field', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('public expand', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 6,
            maxLines: 6,
          ),
        );
        ClipboardManager.copy('a\nb\nc\nd');
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(controller.text, '[Pasted ~4 lines] ');

        key.currentState!.expandPastedText();
        await tester.pump();

        expect(controller.text, 'a\nb\nc\nd');
        expect(key.currentState!.getPastedTexts(), hasLength(0));
      });

      ClipboardManager.clear();
      controller.dispose();
    });

    test('moveSuggestionHighlight drives the menu for hosts', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('host highlight move', (tester) async {
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
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);

        key.currentState!.moveSuggestionHighlight(1);
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 1);

        key.currentState!.moveSuggestionHighlight(-1);
        await tester.pump();
        expect(key.currentState!.selectedSuggestionIndex, 0);
      });

      controller.dispose();
    });

    test('a range selection deletes the token it covers', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('range selection delete', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 60,
            height: 1,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        controller.text = 'hi [main.dart] ab';
        controller.selection = const TextSelection(
          baseOffset: 1,
          extentOffset: 8,
        );
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.backspace),
        );
        await tester.pump();

        expect(controller.text, 'hi ab');
        expect(key.currentState!.getAttachedFiles(), hasLength(0));
      });

      controller.dispose();
    });

    test(
      'a token without its trailing separator falls back to the leading one',
      () async {
        final controller = TextEditingController();
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('leading separator fallback', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 60,
              height: 1,
            ),
          );
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
          await tester.pump();
          // The user removed the separator the tag brought with it.
          controller.text = 'hi [main.dart]';
          controller.selection = const TextSelection.collapsed(offset: 15);
          await tester.pump();

          await tester.sendBackspace();
          await tester.pump();

          expect(controller.text, 'hi');
        });

        controller.dispose();
      },
    );

    test('a wide grapheme shifts the hit test for token taps', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      FileInfo? tapped;

      await testNocterm('wide grapheme tap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 60,
            height: 1,
            onFileClick: (file) => tapped = file,
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        controller.text = '你[main.dart]';
        controller.selection = const TextSelection.collapsed(offset: 13);
        await tester.pump();

        // 你 occupies columns 0-1, so column 4 lands inside the token body.
        await tester.press(4, 0);
        await tester.release(4, 0);

        expect(tapped, isNotNull);
        expect(tapped!.name, 'main.dart');
      });

      controller.dispose();
    });

    test('tapping an unfocused field with tokens focuses it', () async {
      final controller = TextEditingController(text: 'lib 显示');
      final key = GlobalKey<FileTextFieldState>();
      final focus = <bool>[];

      await testNocterm('tap focuses', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
            onFocusChange: (value) => focus.add(value),
          ),
        );
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();

        // Wide graphemes shift the columns the hit test has to account for.
        await tester.press(4, 0);
        await tester.release(4, 0);

        expect(focus, [true]);
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
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(c.hashCode));
    });
  });

  group('SuggestionMenuGrouping', () {
    test('equality covers order, titles and flags', () {
      const grouping = SuggestionMenuGrouping();
      const same = SuggestionMenuGrouping();
      const renamed = SuggestionMenuGrouping(
        groups: [SuggestionMenuGroup('Stuff', [])],
      );
      const otherFlag = SuggestionMenuGrouping(
        groups: [
          SuggestionMenuGroup('Files & folders', [
            FileTextFieldSuggestionKind.file,
            FileTextFieldSuggestionKind.folder,
          ]),
          SuggestionMenuGroup('Agents', [FileTextFieldSuggestionKind.agent]),
          SuggestionMenuGroup('Sessions', [
            FileTextFieldSuggestionKind.session,
          ]),
          SuggestionMenuGroup('Commands', [
            FileTextFieldSuggestionKind.command,
          ]),
        ],
      );
      const ungrouped = SuggestionMenuGrouping(ungroupedTitle: 'Misc');
      const noHeaders = SuggestionMenuGrouping(showHeaders: false);

      expect(grouping, same);
      expect(grouping.hashCode, same.hashCode);
      for (final other in [renamed, otherFlag, ungrouped, noHeaders]) {
        expect(grouping, isNot(other));
        expect(grouping.hashCode, isNot(other.hashCode));
      }
    });

    test('a kind not listed by any group is not lost', () async {
      final key = GlobalKey<FileTextFieldState>();
      final controller = TextEditingController();

      await testNocterm('ungrouped kinds', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            suggestionGrouping: const SuggestionMenuGrouping(
              groups: [
                SuggestionMenuGroup('Only agents', [
                  FileTextFieldSuggestionKind.agent,
                ]),
              ],
            ),
            onSuggestionsRequested: (trigger, query) => [
              const FileTextFieldSuggestion.agent(name: 'explore'),
              const FileTextFieldSuggestion.session(name: 'ses_x'),
            ],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
        );
        await tester.pump();

        final groups = key.currentState!.visibleSuggestionGroups;
        expect(groups.map((group) => group.title), ['Only agents', 'Other']);
        expect(groups.last.items.single.name, 'ses_x');
      });

      controller.dispose();
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

      // Same token with different styles hash differently.
      expect(full.hashCode, isNot(same.hashCode == plain.hashCode));
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
              const InlineToken(
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

    test('a host selection color stops with NO_COLOR', () async {
      final controller = TextEditingController();
      addTearDown(() => TerminalColors.setNoColorOverride(null));

      await testNocterm('monochrome host selection', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            selectionColor: Colors.brightRed,
            tokens: const [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = 'use @x now';
        controller.selection = const TextSelection(
          baseOffset: 4,
          extentOffset: 6,
        );
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(4, 0)?.style.backgroundColor,
          Colors.brightRed,
          reason: 'the host color paints while colors are on',
        );

        TerminalColors.setNoColorOverride(true);
        // An extent move rebuilds the overlay with the flag on.
        controller.selection = const TextSelection(
          baseOffset: 4,
          extentOffset: 7,
        );
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(4, 0)?.style.backgroundColor,
          isNot(Colors.brightRed),
          reason: 'a host-supplied selection color must not survive NO_COLOR',
        );
      });

      controller.dispose();
    });

    test('tokens and caret drop their colors when colors are off', () async {
      final controller = TextEditingController();
      addTearDown(() => TerminalColors.setNoColorOverride(null));

      await testNocterm('monochrome highlight', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 30,
            height: 1,
            tokens: [
              const InlineToken(
                token: '@explore',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        controller.text = 'use @explore now';
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(4, 0)?.style.color,
          Colors.brightCyan,
        );
        // The caret sits past the last character and paints the cell.
        final caretFill = tester.terminalState
            .getCellAt(16, 0)
            ?.style
            .backgroundColor;
        expect(caretFill, isNotNull, reason: 'the emulated caret paints');

        TerminalColors.setNoColorOverride(true);
        // A text change rebuilds the overlay with the flag on; the caret is
        // placed back on the same cell, so what is observed is its fill under
        // NO_COLOR and not a plain cell the caret happened to leave.
        controller.text = 'use @explore now!';
        controller.selection = const TextSelection.collapsed(offset: 16);
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(4, 0)?.style.color,
          isNot(Colors.brightCyan),
          reason: 'NO_COLOR must leave the token uncolored',
        );
        expect(
          tester.terminalState.getCellAt(16, 0)?.style.backgroundColor,
          isNull,
          reason: 'the overlay caret fill must not survive NO_COLOR',
        );
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
              const InlineToken(
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
              const InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
              const InlineToken(
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

    test(
      'creates and disposes its own controller when none is given',
      () async {
        await testNocterm('owned token controller', (tester) async {
          await tester.pumpComponent(
            const TokenHighlightTextField(
              focused: true,
              width: 40,
              height: 1,
              tokens: [InlineToken(token: '@x', style: FileStyle())],
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.at, character: '@'),
          );
          expect(tester.terminalState, containsText('@'));

          // Unmounting runs the owned-controller dispose path.
          await tester.pumpComponent(const SizedBox());
        });
      },
    );

    test('swapping the controller repaints the overlay', () async {
      final first = TextEditingController(text: '@x');
      final second = TextEditingController(text: 'yy');

      await testNocterm('swap token controller', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: first,
            focused: true,
            width: 40,
            height: 1,
            tokens: const [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        expect(tester.terminalState, containsText('@x'));
        expect(
          tester.terminalState.getCellAt(1, 0)?.style.color,
          Colors.brightCyan,
        );

        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: second,
            focused: true,
            width: 40,
            height: 1,
            tokens: const [InlineToken(token: '@x', style: FileStyle())],
          ),
        );
        expect(tester.terminalState, containsText('yy'));
        expect(tester.terminalState, isNot(containsText('@x')));
      });

      first.dispose();
      second.dispose();
    });

    test('the emulated cursor blinks at the configured rate', () async {
      final controller = TextEditingController(text: '@x');
      controller.selection = const TextSelection.collapsed(offset: 1);

      await testNocterm('blinking token cursor', (tester) async {
        await tester.pumpComponent(
          TokenHighlightTextField(
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            cursorBlinkRate: const Duration(milliseconds: 50),
            tokens: const [
              InlineToken(
                token: '@x',
                style: FileStyle(text: Colors.brightCyan),
              ),
            ],
          ),
        );
        await tester.pump();

        // Phase-independent: the caret must be observed both on and off.
        Color? backgroundColor() =>
            tester.terminalState.getCellAt(1, 0)?.style.backgroundColor;
        final seen = <Color?>{};
        for (var i = 0; i < 4; i++) {
          seen.add(backgroundColor());
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(
          seen.whereType<Color>().isNotEmpty && seen.contains(null),
          isTrue,
          reason: 'the caret blinks between visible and hidden phases',
        );
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
              const InlineToken(
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
              const InlineToken(
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
          const TokenText(
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
  group('prompt history', () {
    test('recalls the previous prompt on ArrowUp', () async {
      final controller = TextEditingController();
      final history = PromptHistoryController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history up', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'first prompt';
        await tester.pump();
        // submit
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        // submit clears via onSubmitted callback

        // Up recalls the submitted prompt.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, 'first prompt');
        expect(controller.selection.extentOffset, 'first prompt'.length);
      });

      controller.dispose();
      controller.clear();
    });

    test('ArrowDown restores the draft past the newest entry', () async {
      final controller = TextEditingController();
      final history = PromptHistoryController();

      await testNocterm('history down', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'draft text';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        controller.text = 'new draft';
        await tester.pump();

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, 'draft text');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, 'new draft');
      });

      controller.dispose();
    });

    test('submitting pushes to an injected storage', () async {
      final dir = await Directory.systemTemp.createTemp('phw');
      final storage = FilePromptHistoryStorage('${dir.path}/h.jsonl');
      final history = PromptHistoryController(storage: storage);
      await history.load();
      final controller = TextEditingController();

      await testNocterm('history storage', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'persisted prompt';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final loaded = await storage.load();
        expect(loaded.map((e) => e.text), contains('persisted prompt'));
      });

      controller.dispose();
      await dir.delete(recursive: true);
    });

    test('promptHistoryFilter skips filtered entries', () async {
      final history = PromptHistoryController(
        filter: (t) => !t.startsWith('/'),
      );
      final controller = TextEditingController();

      await testNocterm('history filter', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = '/secret';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        expect(history.texts, isEmpty);

        controller.text = 'hello';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        expect(history.texts, ['hello']);
      });

      controller.dispose();
    });

    test('edit mid-browse resets navigation', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();

      await testNocterm('history edit', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'old';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        controller.text = 'draft';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, 'old');
        expect(history.state.index, isNotNull);

        // edit
        await tester.enterText('x');
        await tester.pump();
        expect(history.state.index, isNull);
      });

      controller.dispose();
    });

    test('single-line Up recalls immediately', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();

      await testNocterm('history single', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'remembered';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        expect(controller.text, '');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, 'remembered');
      });

      controller.dispose();
    });

    test('consecutive duplicate submit is deduped', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();

      await testNocterm('history dedup', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        for (var i = 0; i < 2; i++) {
          controller.text = 'same';
          await tester.pump();
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.enter),
          );
          await tester.pump();
        }
        expect(history.texts, ['same']);
      });

      controller.dispose();
    });

    test('recalling a prompt restores its attachments', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history recall files', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => key.currentState?.clearAttachments(),
          ),
        );
        // Attach a file, then submit.
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
        await tester.pump();
        expect(controller.text, '[main.dart] ');
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        // Field cleared, entry carries the file.
        expect(controller.text, '');
        expect(history.items.single.files.single.path, '/tmp/main.dart');

        // Recall: text and attachment both come back.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, '[main.dart] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(1));
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/tmp/main.dart',
        );

        // Re-sending the recalled prompt keeps the file.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();
        expect(history.items.last.files.single.path, '/tmp/main.dart');
      });

      controller.dispose();
    });

    test('recalling entries swaps their attachments (up and down)', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history recall swap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => key.currentState?.clearAttachments(),
          ),
        );
        // Two prompts, each with a different file.
        for (final name in ['one.dart', 'two.dart']) {
          key.currentState!.attachFile(FileInfo.fromPath('/tmp/$name'));
          await tester.pump();
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.enter),
          );
          await tester.pump();
        }
        expect(history.texts, ['[one.dart] ', '[two.dart] ']);

        // Recall to the newest, then one older.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, '[two.dart] ');
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/tmp/two.dart',
        );

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, '[one.dart] ');
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/tmp/one.dart',
        );

        // Down returns to the newer entry with ITS file, not the older one.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, '[two.dart] ');
        expect(
          key.currentState!.getAttachedFiles().single.path,
          '/tmp/two.dart',
        );

        // Past the newest entry the draft (empty here) is restored and the
        // attachments are dropped.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, '');
        expect(key.currentState!.getAttachedFiles(), isEmpty);
      });

      controller.dispose();
    });

    test('recalling an empty draft clears the recalled text', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();

      await testNocterm('history empty draft', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 40,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        controller.text = 'first';
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();

        // Up recalls, Down past the newest restores the empty draft.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, 'first');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, '');

        // A repeated Down is a no-op, not another draft restore.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, '');
      });

      controller.dispose();
    });

    test('recalled attachments stay deletable out of text order', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history recall order', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            maxLines: null,
            promptHistory: history,
            onSubmitted: (_) => key.currentState?.clearAttachments(),
          ),
        );
        // Attach with the caret before existing text so the attachment order
        // ends up reversed relative to the text order.
        controller.text = 'some text';
        await tester.pump();
        controller.selection = const TextSelection.collapsed(offset: 9);
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/a.txt'));
        await tester.pump();
        controller.selection = const TextSelection.collapsed(offset: 0);
        key.currentState!.attachFile(FileInfo.fromPath('/tmp/b.txt'));
        await tester.pump();
        // Attachments were added [a, b]; the text reads [b, a].
        expect(controller.text, '[b.txt] some text [a.txt] ');

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();

        // Recall both and check every token carries a range: Backspace must
        // remove it as one unit.
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(controller.text, '[b.txt] some text [a.txt] ');
        expect(key.currentState!.getAttachedFiles(), hasLength(2));

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();

        // Deleting from inside each label drops the whole token.
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.backspace),
        );
        await tester.pump();
        expect(controller.text.startsWith('some text'), isTrue);
        expect(key.currentState!.getAttachedFiles(), hasLength(1));
      });

      controller.dispose();
    });

    test('a collapsed paste survives an up/down round trip', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history paste round trip', (tester) async {
        // Multi-line: single-line fields flatten the newlines, so only the
        // character threshold applies there. The clipboard is seeded inside
        // the callback: testNocterm clears it on entry.
        final long = List.generate(4, (i) => 'line $i').join('\n');
        ClipboardManager.copy(long);
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            maxLines: null,
            promptHistory: history,
            onSubmitted: (_) => key.currentState?.clearAttachments(),
          ),
        );
        // Paste over the collapse threshold, then submit so the history has
        // an entry to browse to.
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(controller.text, contains('Pasted ~4 lines'));
        expect(key.currentState!.getPastedTexts(), [long]);

        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();

        // A second paste gives the field a collapsed paste of its own.
        ClipboardManager.copy(long);
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: ModifierKeys(ctrl: true),
          ),
        );
        await tester.pump();
        expect(key.currentState!.getPastedTexts(), [long]);

        // Up recalls the submitted prompt; the paste of the draft is not
        // part of it. The caret starts at the text edge, so the first Up is
        // history and not the boundary Home.
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowUp),
        );
        await tester.pump();
        expect(key.currentState!.getPastedTexts(), isEmpty);

        // Down restores the draft — and its collapsed paste content.
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
        );
        await tester.pump();
        expect(controller.text, contains('Pasted ~4 lines'));
        expect(key.currentState!.getPastedTexts(), [long]);

        ClipboardManager.clear();
      });

      controller.dispose();
    });

    test('pushPrompt carries files', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history push files', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            maxLines: 1,
            promptHistory: history,
          ),
        );
        key.currentState!.pushPrompt(
          'sent from a button',
          files: [FileInfo.fromPath('/tmp/a.png')],
        );
        expect(history.items.single.files.single.path, '/tmp/a.png');

        final recalled = history.moveUp(currentText: '');
        expect(recalled?.entry?.files.single.path, '/tmp/a.png');
      });

      controller.dispose();
    });

    test('pushPrompt / getPromptHistory / clearPromptHistory', () async {
      final history = PromptHistoryController();
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('history api', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 20,
            maxLines: 1,
            promptHistory: history,
            onSubmitted: (_) => controller.text = '',
          ),
        );
        key.currentState!.pushPrompt('manual');
        expect(key.currentState!.getPromptHistory(), ['manual']);
        await key.currentState!.clearPromptHistory();
        expect(key.currentState!.getPromptHistory(), isEmpty);
      });

      controller.dispose();
    });
  });
}
