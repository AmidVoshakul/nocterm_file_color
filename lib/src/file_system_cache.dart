import 'dart:io';

/// Directory listings with an LRU memory and a short time-to-live.
///
/// Hosts that rebuild the `@`/`/` menu on every keystroke re-list the same
/// directory over and over; caching the listing turns those repeats into map
/// lookups. Entries are refreshed after [ttl], so a directory that changed on
/// disk is picked up without any manual invalidation.
///
/// [lister] injects the source of listings — pass a fake in tests, and pass
/// a filtered one (for example one that skips hidden entries) in an app.
/// Return entries the way `Directory.listSync` does: directories (and links
/// to directories, which it follows by default) as `Directory`, so [batches]
/// can descend into them.
class FileSystemCache {
  FileSystemCache({
    this.maxEntries = 64,
    this.ttl = const Duration(seconds: 2),
    List<FileSystemEntity> Function(Directory)? lister,
  }) : assert(maxEntries > 0, 'maxEntries must be greater than zero'),
       assert(!ttl.isNegative, 'ttl must not be negative'),
       _lister = lister ?? _listDirectory;

  /// How many directories to remember. The least recently used is dropped.
  final int maxEntries;

  /// How long a listing stays fresh.
  final Duration ttl;

  final List<FileSystemEntity> Function(Directory) _lister;

  /// Insertion-ordered: the first key is the least recently used entry.
  final Map<String, _Listing> _listings = {};

  /// The current listing of [dir], listing it only when the cached one is
  /// older than [ttl]. Treat the result as read-only.
  List<FileSystemEntity> children(Directory dir) {
    final cached = _listings.remove(dir.path);
    if (cached != null) {
      if (DateTime.now().difference(cached.listedAt) < ttl) {
        _listings[dir.path] = cached; // move to the most-recently-used end
        return cached.entities;
      }
    }

    final entities = List<FileSystemEntity>.unmodifiable(_lister(dir));
    _listings[dir.path] = _Listing(entities, DateTime.now());
    while (_listings.length > maxEntries) {
      _listings.remove(_listings.keys.first);
    }
    return entities;
  }

  /// Walks [root] depth first, emitting the listing of each directory as it
  /// goes. Directories are visited through [children], so the walk benefits
  /// from the cache and a directory is listed once. Each directory is visited
  /// once by its resolved path, so a symlink cycle terminates the walk.
  Stream<List<FileSystemEntity>> batches(Directory root) async* {
    final pending = <Directory>[root];
    // Resolved paths, so a link that points back at an ancestor ends the walk
    // instead of cycling.
    final visited = <String>{};

    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      if (!visited.add(_resolvePath(directory))) continue;
      final listing = children(directory);
      if (listing.isEmpty) continue;
      yield listing;
      pending.addAll(listing.whereType<Directory>());
    }
  }

  /// Forgets [dir], or everything when it is omitted.
  void invalidate([Directory? dir]) {
    if (dir == null) {
      _listings.clear();
      return;
    }
    _listings.remove(dir.path);
  }

  /// Forgets everything.
  void clear() => _listings.clear();

  /// Everything currently remembered, least recently used first.
  int get length => _listings.length;

  static List<FileSystemEntity> _listDirectory(Directory dir) {
    try {
      return dir.listSync();
    } on FileSystemException {
      // Unreadable directories read as empty rather than failing the caller.
      return const [];
    }
  }

  /// A stable key for [directory]: its real path when that can be resolved,
  /// the literal path otherwise.
  static String _resolvePath(Directory directory) {
    try {
      return directory.resolveSymbolicLinksSync();
    } on FileSystemException {
      return directory.path;
    }
  }
}

class _Listing {
  const _Listing(this.entities, this.listedAt);

  final List<FileSystemEntity> entities;
  final DateTime listedAt;
}
