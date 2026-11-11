import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

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
      const a = PromptHistoryState(items: ['x'], index: 1, draft: 'd');
      const b = PromptHistoryState(items: ['x'], index: 1, draft: 'd');
      const c = PromptHistoryState(items: ['y'], index: 1, draft: 'd');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('createHistory', () {
    test('filters empty/whitespace', () {
      final s = createHistory(['', '  ', 'a']);
      expect(s.items, ['a']);
      expect(s.index, isNull);
      expect(s.draft, '');
    });

    test('dedups consecutive (trim-normalized)', () {
      final s = createHistory(['a', 'a ', ' b', 'b']);
      expect(s.items, ['a', ' b']);
    });

    test('trims to capacity', () {
      final items = List.generate(10, (i) => 'e$i');
      final s = createHistory(items, maxCapacity: 3);
      expect(s.items, ['e7', 'e8', 'e9']);
    });

    test('resets navigation', () {
      // createHistory always resets; covered by defaults above.
      final s = createHistory(['a']);
      expect(s.index, isNull);
      expect(s.draft, '');
    });
  });

  group('pushHistory', () {
    test('ignores empty', () {
      final s = pushHistory(
        const PromptHistoryState(items: ['a'], index: null, draft: ''),
        '   ',
      );
      expect(s.items, ['a']);
    });

    test('dedups consecutive', () {
      final s = pushHistory(
        const PromptHistoryState(items: ['a'], index: null, draft: ''),
        'a',
      );
      expect(s.items, ['a']);
      expect(s.index, isNull);
    });

    test('appends new entry', () {
      final s = pushHistory(
        const PromptHistoryState(items: ['a'], index: null, draft: ''),
        'b',
      );
      expect(s.items, ['a', 'b']);
    });

    test('trims to capacity', () {
      final base = const PromptHistoryState(
        items: ['a', 'b'],
        index: null,
        draft: '',
      );
      final s = pushHistory(base, 'c', maxCapacity: 2);
      expect(s.items, ['b', 'c']);
    });

    test('resets navigation', () {
      final base = const PromptHistoryState(items: ['a'], index: 0, draft: 'd');
      final s = pushHistory(base, 'b');
      expect(s.index, isNull);
      expect(s.draft, '');
    });
  });

  group('moveHistoryUp/moveDown', () {
    test('moveUp on empty returns null', () {
      final s = const PromptHistoryState(items: [], index: null, draft: '');
      final r = moveHistoryUpResult(s, 'draft');
      expect(r.text, isNull);
      expect(r.state, s);
    });

    test('moveUp first step saves draft and returns last', () {
      final s = const PromptHistoryState(
        items: ['a', 'b'],
        index: null,
        draft: '',
      );
      final r = moveHistoryUpResult(s, 'draft');
      expect(r.text, 'b');
      expect(r.state.index, 1);
      expect(r.state.draft, 'draft');
    });

    test('moveUp second step goes older', () {
      final s = const PromptHistoryState(
        items: ['a', 'b'],
        index: 1,
        draft: 'draft',
      );
      final r = moveHistoryUpResult(s, 'ignored');
      expect(r.text, 'a');
      expect(r.state.index, 0);
      expect(r.state.draft, 'draft');
    });

    test('moveUp at beginning returns null', () {
      final s = const PromptHistoryState(
        items: ['a', 'b'],
        index: 0,
        draft: 'draft',
      );
      final r = moveHistoryUpResult(s, 'ignored');
      expect(r.text, isNull);
      expect(r.state, s);
    });

    test('moveDown past newest restores draft and clears index', () {
      final s = const PromptHistoryState(
        items: ['a', 'b'],
        index: 1,
        draft: 'draft',
      );
      final r = moveHistoryDownResult(s);
      expect(r.text, 'draft');
      expect(r.state.index, isNull);
      expect(r.state.draft, 'draft');
    });

    test('moveDown when index null returns null', () {
      final s = const PromptHistoryState(
        items: ['a', 'b'],
        index: null,
        draft: '',
      );
      final r = moveHistoryDownResult(s);
      expect(r.text, isNull);
      expect(r.state, s);
    });

    test('moveDown mid-list returns next', () {
      final s = const PromptHistoryState(
        items: ['a', 'b', 'c'],
        index: 0,
        draft: 'd',
      );
      final r = moveHistoryDownResult(s);
      expect(r.text, 'b');
      expect(r.state.index, 1);
    });
  });

  group('PromptHistoryCodec', () {
    test('round-trip', () {
      final items = ['hello', 'world', 'with "quotes"'];
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
      expect(decoded, ['a', 'b']);
    });

    test('encodeEntry produces one JSONL line', () {
      final line = PromptHistoryCodec.encodeEntry('hi');
      expect(line, '{"input":"hi"}');
      expect(PromptHistoryCodec.decode(line), ['hi']);
    });
  });

  group('PromptHistoryController', () {
    test('starts empty with in-memory storage', () {
      final c = PromptHistoryController();
      expect(c.items, isEmpty);
      expect(c.state.index, isNull);
    });

    test('push appends non-empty, resets nav', () {
      final c = PromptHistoryController();
      c.push('a');
      expect(c.items, ['a']);
      // push resets nav
      c.moveUp(currentText: 'draft');
      expect(c.state.index, 0);
      c.push('b');
      expect(c.items, ['a', 'b']);
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
      expect(c.items, ['a']);
    });

    test('push trims to capacity', () {
      final c = PromptHistoryController(maxCapacity: 2);
      c.push('a');
      c.push('b');
      c.push('c');
      expect(c.items, ['b', 'c']);
    });

    test('push respects filter predicate', () {
      final c = PromptHistoryController(filter: (t) => t != 'secret');
      c.push('ok');
      c.push('secret');
      c.push('also ok');
      expect(c.items, ['ok', 'also ok']);
    });

    test('moveUp returns null when empty', () {
      final c = PromptHistoryController();
      expect(c.moveUp(currentText: 'x'), isNull);
    });

    test('moveUp saves draft on first step', () {
      final c = PromptHistoryController();
      c.push('a');
      c.push('b');
      final text = c.moveUp(currentText: 'draft');
      expect(text, 'b');
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
      final text = c.moveDown();
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
      expect(c.items, ['a']);
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
      await storage.append('stored');
      final c = PromptHistoryController(storage: storage);
      await c.load();
      expect(c.items, contains('stored'));
      await dir.delete(recursive: true);
    });

    test('storage append is called on push', () async {
      final dir = await Directory.systemTemp.createTemp('ph2');
      final storage = FilePromptHistoryStorage('${dir.path}/h.jsonl');
      final c = PromptHistoryController(storage: storage);
      await c.load();
      c.push('hello');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final loaded = await storage.load();
      expect(loaded, contains('hello'));
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
      expect(c.items, ['ok']);
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
      expect(c.moveUp(currentText: 'd'), 'a');
      expect(notified, 1);
      expect(c.moveDown(), 'd');
      expect(notified, 2);
    });
  });
}
