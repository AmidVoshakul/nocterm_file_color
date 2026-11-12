import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

PromptHistoryEntry entry(String text, {List<FileInfo> files = const []}) =>
    PromptHistoryEntry(text: text, files: files);

void main() {
  group('promptEdgeStep', () {
    test('up on empty text returns null (history owns)', () {
      expect(promptEdgeStepUp('', 0), isNull);
    });

    test('up snaps to start on first line mid-text', () {
      expect(promptEdgeStepUp('abc\ndef', 2), 0);
    });

    test('up returns null when already at start', () {
      expect(promptEdgeStepUp('abc\ndef', 0), isNull);
    });

    test('up returns null when cursor below first line', () {
      expect(promptEdgeStepUp('abc\ndef', 5), isNull);
    });

    test('down snaps to end on last line mid-text', () {
      expect(promptEdgeStepDown('abc\ndef', 5), 7);
    });

    test('down returns null when already at end', () {
      expect(promptEdgeStepDown('abc\ndef', 7), isNull);
    });

    test('down returns null when cursor above last line', () {
      expect(promptEdgeStepDown('abc\ndef', 2), isNull);
    });

    test('single line: up snaps to start when mid-text', () {
      expect(promptEdgeStepUp('abc', 2), 0);
    });

    test('single line: up returns null at start', () {
      expect(promptEdgeStepUp('abc', 0), isNull);
    });

    test('single line: down snaps to end when mid-text', () {
      expect(promptEdgeStepDown('abc', 1), 3);
    });

    test('single line: down returns null at end', () {
      expect(promptEdgeStepDown('abc', 3), isNull);
    });
  });

  group('PromptHistoryState', () {
    test('equality compares items, index, draft', () {
      const a = PromptHistoryState(
        items: [PromptHistoryEntry(text: 'x')],
        index: 1,
        draft: 'd',
      );
      const b = PromptHistoryState(
        items: [PromptHistoryEntry(text: 'x')],
        index: 1,
        draft: 'd',
      );
      const c = PromptHistoryState(
        items: [PromptHistoryEntry(text: 'y')],
        index: 1,
        draft: 'd',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('createHistory', () {
    test('filters empty/whitespace', () {
      final s = createHistory([entry(''), entry('  '), entry('a')]);
      expect(s.items.map((e) => e.text), ['a']);
      expect(s.index, isNull);
      expect(s.draft, '');
    });

    test('dedups consecutive (trim-normalized)', () {
      final s = createHistory([entry('a'), entry('a '), entry(' b')]);
      expect(s.items.map((e) => e.text), ['a', ' b']);
    });

    test('trims to capacity', () {
      final items = List.generate(10, (i) => entry('e$i'));
      final s = createHistory(items, maxCapacity: 3);
      expect(s.items.map((e) => e.text), ['e7', 'e8', 'e9']);
    });
  });

  group('pushHistory', () {
    test('ignores empty', () {
      final s = pushHistory(
        const PromptHistoryState(items: [PromptHistoryEntry(text: 'a')]),
        entry('   '),
      );
      expect(s.items.map((e) => e.text), ['a']);
    });

    test('dedups consecutive', () {
      final s = pushHistory(
        const PromptHistoryState(items: [PromptHistoryEntry(text: 'a')]),
        entry('a'),
      );
      expect(s.items.map((e) => e.text), ['a']);
      expect(s.index, isNull);
    });

    test('appends new entry', () {
      final s = pushHistory(
        const PromptHistoryState(items: [PromptHistoryEntry(text: 'a')]),
        entry('b'),
      );
      expect(s.items.map((e) => e.text), ['a', 'b']);
    });

    test('trims to capacity', () {
      final base = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
        ],
      );
      final s = pushHistory(base, entry('c'), maxCapacity: 2);
      expect(s.items.map((e) => e.text), ['b', 'c']);
    });

    test('resets navigation', () {
      final base = const PromptHistoryState(
        items: [PromptHistoryEntry(text: 'a')],
        index: 0,
        draft: 'd',
      );
      final s = pushHistory(base, entry('b'));
      expect(s.index, isNull);
      expect(s.draft, '');
    });
  });

  group('moveHistoryUp/moveDown', () {
    test('moveUp on empty returns null', () {
      final s = const PromptHistoryState(items: [], index: null, draft: '');
      final r = moveHistoryUpResult(s, 'draft');
      expect(r.entry, isNull);
      expect(r.state, s);
    });

    test('moveUp first step saves draft and returns last', () {
      final s = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
        ],
      );
      final r = moveHistoryUpResult(s, 'draft');
      expect(r.entry?.text, 'b');
      expect(r.state.index, 1);
      expect(r.state.draft, 'draft');
    });

    test('moveUp second step goes older', () {
      final s = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
        ],
        index: 1,
        draft: 'draft',
      );
      final r = moveHistoryUpResult(s, 'ignored');
      expect(r.entry?.text, 'a');
      expect(r.state.index, 0);
      expect(r.state.draft, 'draft');
    });

    test('moveUp at beginning returns null', () {
      final s = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
        ],
        index: 0,
        draft: 'draft',
      );
      final r = moveHistoryUpResult(s, 'ignored');
      expect(r.entry, isNull);
      expect(r.state, s);
    });

    test('moveDown past newest clears index and keeps draft', () {
      final s = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
        ],
        index: 1,
        draft: 'draft',
      );
      final r = moveHistoryDownResult(s);
      expect(r.entry, isNull);
      expect(r.state.index, isNull);
      expect(r.state.draft, 'draft');
    });

    test('moveDown when index null returns null', () {
      final s = const PromptHistoryState(
        items: [PromptHistoryEntry(text: 'a')],
        index: null,
      );
      final r = moveHistoryDownResult(s);
      expect(r.entry, isNull);
      expect(r.state, s);
    });

    test('moveDown mid-list returns next', () {
      final s = const PromptHistoryState(
        items: [
          PromptHistoryEntry(text: 'a'),
          PromptHistoryEntry(text: 'b'),
          PromptHistoryEntry(text: 'c'),
        ],
        index: 0,
        draft: 'd',
      );
      final r = moveHistoryDownResult(s);
      expect(r.entry?.text, 'b');
      expect(r.state.index, 1);
    });
  });

  group('PromptHistoryCodec', () {
    test('round-trip with files', () {
      final items = [
        entry('hello'),
        entry('image', files: [FileInfo.fromPath('/tmp/1.png')]),
        entry('with "quotes"'),
      ];
      final encoded = PromptHistoryCodec.encode(items);
      final decoded = PromptHistoryCodec.decode(encoded);
      expect(decoded, items);
    });

    test('decode skips broken/empty/non-json lines', () {
      const text = '''
{"input": "a"}
not json
{"input": ""}
{"foo": "bar"}
{"input": "b"}

{"input": 42}
''';
      final decoded = PromptHistoryCodec.decode(text);
      expect(decoded.map((e) => e.text), ['a', 'b']);
      expect(decoded.every((e) => e.files.isEmpty), isTrue);
    });

    test('legacy lines without files load as empty attachments', () {
      final decoded = PromptHistoryCodec.decode('{"input": "old"}');
      expect(decoded.single.text, 'old');
      expect(decoded.single.files, isEmpty);
    });

    test('encodeEntry produces one JSONL line', () {
      final line = PromptHistoryCodec.encodeEntry(entry('hi'));
      expect(line, '{"input":"hi"}');
      expect(PromptHistoryCodec.decode(line).single.text, 'hi');
    });
  });

  group('PromptHistoryController', () {
    test('starts empty with in-memory storage', () {
      final c = PromptHistoryController();
      expect(c.items, isEmpty);
      expect(c.texts, isEmpty);
      expect(c.state.index, isNull);
    });

    test('push appends non-empty, resets nav', () {
      final c = PromptHistoryController();
      c.push('a');
      expect(c.texts, ['a']);
      // push resets nav
      c.moveUp(currentText: 'draft');
      expect(c.state.index, 0);
      c.push('b');
      expect(c.texts, ['a', 'b']);
      expect(c.state.index, isNull);
      expect(c.state.draft, '');
    });

    test('push skips empty and whitespace', () {
      final c = PromptHistoryController();
      c.push('   ');
      expect(c.items, isEmpty);
    });

    test('push dedups consecutive (trim-normalized)', () {
      final c = PromptHistoryController();
      c.push('a');
      c.push('a ');
      expect(c.texts, ['a']);
    });

    test('push trims to capacity', () {
      final c = PromptHistoryController(maxCapacity: 2);
      c.push('a');
      c.push('b');
      c.push('c');
      expect(c.texts, ['b', 'c']);
    });

    test('push respects filter predicate', () {
      final c = PromptHistoryController(filter: (t) => t != 'secret');
      c.push('ok');
      c.push('secret');
      c.push('also ok');
      expect(c.texts, ['ok', 'also ok']);
    });

    test('push stores attachments on the entry', () {
      final c = PromptHistoryController();
      final files = [FileInfo.fromPath('/tmp/a.png')];
      c.push('look', files: files);
      expect(c.items.single.files.single.path, '/tmp/a.png');
      // A recalled entry keeps its files.
      final recalled = c.moveUp(currentText: 'draft');
      expect(recalled?.entry?.files.single.path, '/tmp/a.png');
      expect(recalled?.text, 'look');
    });

    test('moveUp returns null when empty', () {
      final c = PromptHistoryController();
      expect(c.moveUp(currentText: 'x'), isNull);
    });

    test('moveUp saves draft on first step', () {
      final c = PromptHistoryController();
      c.push('a');
      c.push('b');
      final entry = c.moveUp(currentText: 'draft');
      expect(entry?.entry?.text, 'b');
      expect(c.state.index, 1);
      expect(c.state.draft, 'draft');
    });

    test('moveUp at beginning returns null', () {
      final c = PromptHistoryController();
      c.push('a');
      c.moveUp(currentText: 'd');
      expect(c.moveUp(currentText: 'd'), isNull);
    });

    test('moveDown past newest restores draft and clears index', () {
      final c = PromptHistoryController();
      c.push('a');
      c.moveUp(currentText: 'draft');
      final text = c.moveDown()?.text;
      expect(text, 'draft');
      expect(c.state.index, isNull);
    });

    test('moveDown when not browsing returns null', () {
      final c = PromptHistoryController();
      c.push('a');
      expect(c.moveDown(), isNull);
    });

    test('resetNavigation clears index and draft', () {
      final c = PromptHistoryController();
      c.push('a');
      c.moveUp(currentText: 'draft');
      expect(c.state.index, isNotNull);
      c.resetNavigation();
      expect(c.state.index, isNull);
      expect(c.state.draft, '');
      expect(c.texts, ['a']);
    });

    test('clear empties items', () async {
      final c = PromptHistoryController();
      c.push('a');
      c.push('b');
      await c.clear();
      expect(c.items, isEmpty);
    });

    test('loads from storage on construction', () async {
      final dir = await Directory.systemTemp.createTemp('ph');
      final storage = FilePromptHistoryStorage('${dir.path}/h.jsonl');
      await storage.append(entry('stored'));
      final c = PromptHistoryController(storage: storage);
      await c.load();
      expect(c.texts, contains('stored'));
      await dir.delete(recursive: true);
    });

    test('storage append keeps attachments', () async {
      final dir = await Directory.systemTemp.createTemp('ph2');
      final storage = FilePromptHistoryStorage('${dir.path}/h.jsonl');
      final c = PromptHistoryController(storage: storage);
      await c.load();
      c.push('with file', files: [FileInfo.fromPath('/tmp/photo.png')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final loaded = await storage.load();
      expect(loaded.single.text, 'with file');
      expect(loaded.single.files.single.path, '/tmp/photo.png');
      await dir.delete(recursive: true);
    });

    test('storage load self-heals broken lines', () async {
      final dir = await Directory.systemTemp.createTemp('ph3');
      final file = File('${dir.path}/h.jsonl');
      await file.parent.create(recursive: true);
      await file.writeAsString('{"input": "ok"}\nbroken\n{"input": "ok"}\n');
      final storage = FilePromptHistoryStorage(file.path);
      final c = PromptHistoryController(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // consecutive dedup should collapse the two 'ok'
      expect(c.texts, ['ok']);
      await dir.delete(recursive: true);
    });

    test('moveDown keeps entries symmetrical and notifies only on a move', () {
      final c = PromptHistoryController();
      c.push('a', files: [FileInfo.fromPath('/tmp/a.png')]);
      c.push('b', files: [FileInfo.fromPath('/tmp/b.png')]);
      var notified = 0;
      c.addListener(() => notified++);

      // Up twice (older), then down twice (newer, draft).
      expect(c.moveUp(currentText: 'd')?.entry?.text, 'b');
      expect(c.moveUp(currentText: 'd')?.entry?.text, 'a');
      expect(c.moveUp(currentText: 'd'), isNull); // at the beginning
      expect(c.moveDown()?.entry?.text, 'b');
      expect(notified, 3);

      // Down past the newest entry restores the draft once; a second press
      // does nothing and notifies nothing.
      expect(c.moveDown()?.draft, 'd');
      expect(notified, 4);
      expect(c.moveDown(), isNull);
      expect(notified, 4);
    });

    test('moveDown swaps attachments between entries', () {
      final c = PromptHistoryController();
      c.push('a', files: [FileInfo.fromPath('/tmp/a.png')]);
      c.push('b', files: [FileInfo.fromPath('/tmp/b.png')]);

      c.moveUp(currentText: 'd'); // at 'b'
      expect(
        c.moveUp(currentText: 'd')?.entry?.files.single.path,
        '/tmp/a.png',
      );
      final back = c.moveDown();
      expect(back?.entry?.files.single.path, '/tmp/b.png');
    });

    test('moveDown with an empty draft restores an empty field', () {
      final c = PromptHistoryController();
      c.push('only');
      // First Up saves the (empty) current text as draft.
      final up = c.moveUp(currentText: '');
      expect(up?.entry?.text, 'only');
      final down = c.moveDown();
      expect(down, isNotNull);
      expect(down?.draft, '');
      expect(down?.text, '');
      expect(c.state.index, isNull);
    });

    test('storage load restores attachments', () async {
      final dir = await Directory.systemTemp.createTemp('ph4');
      final storage = FilePromptHistoryStorage('${dir.path}/h.jsonl');
      await storage.append(
        entry(
          'with file',
          files: [
            const FileInfo(
              path: '/tmp/photo.png',
              name: 'photo.png',
              extension: 'png',
              type: FileType.image,
            ),
          ],
        ),
      );
      final entries = await storage.load();
      expect(entries.single.files.single.path, '/tmp/photo.png');
      expect(entries.single.files.single.name, 'photo.png');
      expect(entries.single.files.single.type, FileType.image);

      final c = PromptHistoryController(storage: storage);
      await c.load();
      final recalled = c.moveUp(currentText: '');
      expect(recalled?.entry?.files.single.name, 'photo.png');
      await dir.delete(recursive: true);
    });

    test('notifies listeners on push', () {
      final c = PromptHistoryController();
      var notified = 0;
      c.addListener(() => notified++);
      c.push('a');
      expect(notified, 1);
    });

    test('moveUp/moveDown notify listeners when applicable', () {
      final c = PromptHistoryController();
      c.push('a');
      var notified = 0;
      c.addListener(() => notified++);
      expect(c.moveUp(currentText: 'd')?.text, 'a');
      expect(notified, 1);
      expect(c.moveDown()?.text, 'd');
      expect(notified, 2);
    });
  });
}
