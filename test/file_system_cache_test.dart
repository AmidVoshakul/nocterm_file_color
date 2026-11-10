import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// Replaces the disk for the cache under test: a directory of fabricated
/// entities plus a call counter.
class _FakeLister {
  _FakeLister(this._byDirectory);

  final Map<String, List<FileSystemEntity>> _byDirectory;
  var calls = 0;

  List<FileSystemEntity> call(Directory dir) {
    calls++;
    return _byDirectory[dir.path] ?? const [];
  }
}

Directory _dir(String name) => Directory('/fake/$name');
FileSystemEntity _entry(String name, {bool isDir = false}) =>
    isDir ? Directory('/fake/$name') : File('/fake/$name');

Directory get fakeRoot => Directory('/fake');

void main() {
  test('a non-positive entry budget is rejected', () {
    expect(
      () => FileSystemCache(maxEntries: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a negative ttl is rejected', () {
    expect(
      () => FileSystemCache(ttl: const Duration(seconds: -1)),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a zero ttl always lists fresh', () {
    final lister = _FakeLister({
      '/fake/a': [_entry('x.txt')],
    });
    final cache = FileSystemCache(lister: lister.call, ttl: Duration.zero);

    cache.children(_dir('a'));
    cache.children(_dir('a'));

    expect(lister.calls, 2);
  });

  test('a repeat listing is served from the cache', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('x.txt')],
    });
    final cache = FileSystemCache(lister: lister.call);

    cache.children(_dir('a'));
    cache.children(_dir('a'));

    expect(lister.calls, 1);
  });

  test('a listing older than the ttl is refreshed', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('x.txt')],
    });
    final cache = FileSystemCache(
      lister: lister.call,
      ttl: const Duration(milliseconds: 1),
    );

    cache.children(_dir('a'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cache.children(_dir('a'));

    expect(lister.calls, 2);
  });

  test('a caller cannot corrupt the cache by mutating the result', () {
    final lister = _FakeLister({
      '/fake/a': [_entry('x.txt')],
    });
    final cache = FileSystemCache(lister: lister.call);

    final first = cache.children(_dir('a'));
    // A host sorting in place cannot silently corrupt the cache.
    expect(() => first.sort(), throwsUnsupportedError);

    final second = cache.children(_dir('a'));
    expect(first.length, second.length);
    expect(lister.calls, 1);
  });

  test('the least recently used directory is evicted', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('a.txt')],
      '/fake/b': [_entry('b.txt')],
      '/fake/c': [_entry('c.txt')],
    });
    final cache = FileSystemCache(maxEntries: 2, lister: lister.call);

    cache.children(_dir('a'));
    cache.children(_dir('b'));
    cache.children(_dir('c')); // evicts 'a'

    cache.children(_dir('a')); // must list again
    expect(lister.calls, 4);
  });

  test('a touched entry counts as recently used', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('a.txt')],
      '/fake/b': [_entry('b.txt')],
      '/fake/c': [_entry('c.txt')],
    });
    final cache = FileSystemCache(maxEntries: 2, lister: lister.call);

    cache.children(_dir('a'));
    cache.children(_dir('b'));
    cache.children(_dir('a')); // refresh 'a' in the LRU order
    cache.children(_dir('c')); // evicts 'b', not 'a'

    cache.children(_dir('a'));
    expect(lister.calls, 3);
    cache.children(_dir('b'));
    expect(lister.calls, 4);
  });

  test('invalidate drops one directory', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('a.txt')],
      '/fake/b': [_entry('b.txt')],
    });
    final cache = FileSystemCache(lister: lister.call);

    cache.children(_dir('a'));
    cache.children(_dir('b'));
    cache.invalidate(_dir('a'));
    cache.children(_dir('a'));
    cache.children(_dir('b'));

    expect(lister.calls, 3);
  });

  test('invalidate clears everything', () async {
    final lister = _FakeLister({
      '/fake/a': [_entry('a.txt')],
    });
    final cache = FileSystemCache(lister: lister.call);

    cache.children(_dir('a'));
    cache.clear();
    cache.children(_dir('a'));

    expect(lister.calls, 2);
  });

  test('batches walk the tree depth first and reuse the cache', () async {
    final lister = _FakeLister({
      '/fake': [_entry('root.txt'), Directory('/fake/sub')],
      '/fake/sub': [File('/fake/sub/leaf.txt'), Directory('/fake/sub/deep')],
      '/fake/sub/deep': [File('/fake/sub/deep/deep.txt')],
    });
    final cache = FileSystemCache(lister: lister.call);

    final walked = <String>[];
    await for (final batch in cache.batches(fakeRoot)) {
      walked.add(batch.map((entity) => entity.path).join(','));
    }

    expect(walked, [
      '/fake/root.txt,/fake/sub',
      '/fake/sub/leaf.txt,/fake/sub/deep',
      '/fake/sub/deep/deep.txt',
    ]);
    expect(lister.calls, 3);
  });

  test('a symlink cycle stops the walk', () async {
    final root = Directory.systemTemp.createTempSync();
    final nested = Directory('${root.path}/a/b')..createSync(recursive: true);
    File('${nested.path}/file.txt').writeAsStringSync('x');
    // A link back to the ancestor: `node_modules` and workspace roots can
    // produce these.
    Link('${nested.path}/loop').createSync('${root.path}/a');

    final cache = FileSystemCache();
    var batches = 0;
    await for (final _ in cache.batches(root)) {
      batches++;
      if (batches > 10) fail('the walk must stop, not cycle');
    }

    expect(batches, 3); // root, a, a/b
    root.deleteSync(recursive: true);
  });

  test('an unreadable directory does not stop the walk', () async {
    final lister = _FakeLister({
      // '/fake/broken' is missing, so it reads as an empty listing.
      '/fake': [_entry('ok.txt'), Directory('/fake/broken')],
    });
    final cache = FileSystemCache(lister: lister.call);

    final walked = <int>[];
    await for (final batch in cache.batches(fakeRoot)) {
      walked.add(batch.length);
    }

    expect(walked, [2]);
  });
}
