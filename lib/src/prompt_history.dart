import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

import 'file_info.dart';

/// One stored prompt: its text and the files attached when it was sent.
///
/// Attachments are carried so that recalling a prompt restores its files
/// together with the text — re-sending a recalled prompt keeps the files.
class PromptHistoryEntry {
  const PromptHistoryEntry({required this.text, this.files = const []});

  final String text;
  final List<FileInfo> files;
  @override
  bool operator ==(Object other) =>
      other is PromptHistoryEntry &&
      other.text == text &&
      _listEquals(other.files, files);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(files));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Immutable state for a prompt-history ring.
///
/// [items] holds past prompts oldest-first (capped by the controller).
/// [index] is the current browse position while navigating with Up/Down,
/// or `null` when the user edits fresh input. [draft] preserves the
/// unedited text being browsed away from, restored when navigating past
/// the newest entry. Use [copyWith] with `clearIndex: true` to reset
/// [index] to `null`.
class PromptHistoryState {
  const PromptHistoryState({required this.items, this.index, this.draft = ''});

  final List<PromptHistoryEntry> items;
  final int? index;
  final String draft;

  PromptHistoryState copyWith({
    List<PromptHistoryEntry>? items,
    int? index,
    String? draft,
    bool clearIndex = false,
  }) {
    return PromptHistoryState(
      items: items ?? this.items,
      index: clearIndex ? null : (index ?? this.index),
      draft: draft ?? this.draft,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PromptHistoryState &&
      other.draft == draft &&
      other.index == index &&
      _listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(draft, index, Object.hashAll(items));
}

/// Persistence contract for a prompt-history ring.
///
/// The package never touches the disk by default; a host that wants
/// persistence supplies an implementation (for example
/// [FilePromptHistoryStorage]). All methods are best-effort: failures must
/// never propagate into the UI.
abstract class PromptHistoryStorage {
  /// Loads stored entries (oldest-first). Returns an empty list when there
  /// is nothing stored or the read fails.
  Future<List<PromptHistoryEntry>> load();

  /// Appends a single entry. Best-effort; failures are swallowed.
  Future<void> append(PromptHistoryEntry entry);

  /// Rewrites the whole store (used for trimming and self-healing). Best-effort.
  Future<void> rewrite(List<PromptHistoryEntry> items);
}

/// In-memory storage that keeps nothing: load returns empty, append/rewrite
/// are no-ops. Used when no persistence is wanted.
class InMemoryPromptHistoryStorage implements PromptHistoryStorage {
  const InMemoryPromptHistoryStorage();

  @override
  Future<List<PromptHistoryEntry>> load() async => const [];

  @override
  Future<void> append(PromptHistoryEntry entry) async {}

  @override
  Future<void> rewrite(List<PromptHistoryEntry> items) async {}
}

/// File-backed storage that persists entries as JSONL (one
/// `{"input": ..., "files": [...]}` object per line). The host owns the path;
/// the package only writes to it.
///
/// The path is trusted input (host-provided). It is normalized for traversal
/// safety in debug builds.
class FilePromptHistoryStorage implements PromptHistoryStorage {
  FilePromptHistoryStorage(this.path) : assert(!path.contains('..'));

  final String path;

  @override
  Future<List<PromptHistoryEntry>> load() async {
    try {
      final file = File(path);
      if (!file.existsSync()) return const [];
      final lines = await file.readAsLines();
      return PromptHistoryCodec.decode(lines.join('\n'));
    } on Exception {
      return const [];
    }
  }

  @override
  Future<void> append(PromptHistoryEntry entry) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${PromptHistoryCodec.encodeEntry(entry)}\n',
        mode: FileMode.append,
      );
    } on Exception {
      // Best-effort: history is never critical.
    }
  }

  @override
  Future<void> rewrite(List<PromptHistoryEntry> items) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      final buffer = StringBuffer();
      for (final item in items) {
        buffer.writeln(PromptHistoryCodec.encodeEntry(item));
      }
      await file.writeAsString(buffer.toString());
    } on Exception {
      // Best-effort: history is never critical.
    }
  }
}

/// JSONL codec for prompt-history entries. Each line is one object; `files`
/// is optional so older `{"input": ...}` lines still load. Keeps storage
/// implementations dumb.
class PromptHistoryCodec {
  const PromptHistoryCodec._();

  /// Serializes a list of entries to JSONL.
  static String encode(List<PromptHistoryEntry> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln(encodeEntry(item));
    }
    return buffer.toString();
  }

  /// Serializes a single entry to one JSONL line.
  static String encodeEntry(PromptHistoryEntry entry) {
    return jsonEncode({
      'input': entry.text,
      if (entry.files.isNotEmpty)
        'files': [for (final file in entry.files) _encodeFile(file)],
    });
  }

  /// Parses JSONL into a list of entries. Broken/empty/non-JSON lines are
  /// skipped; empty `input` values are filtered out. Files missing from a
  /// line load as an empty list (older format).
  static List<PromptHistoryEntry> decode(String text) {
    final result = <PromptHistoryEntry>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        final input = decoded['input'];
        if (input is! String || input.trim().isEmpty) continue;
        final filesJson = decoded['files'];
        final files = <FileInfo>[];
        if (filesJson is List) {
          for (final item in filesJson) {
            if (item is Map<String, dynamic>) {
              files.add(_decodeFile(item));
            }
          }
        }
        result.add(PromptHistoryEntry(text: input, files: files));
      } on FormatException {
        // skip broken JSON
      } on TypeError {
        // skip unexpected JSON shape
      }
    }
    return result;
  }

  static Map<String, dynamic> _encodeFile(FileInfo file) => {
    'path': file.path,
    'name': file.name,
    'extension': file.extension,
    'type': file.type.name,
    if (file.size != null) 'size': file.size,
  };

  static FileInfo _decodeFile(Map<String, dynamic> map) {
    final path = map['path'] is String ? map['path'] as String : '';
    final name = map['name'] is String ? map['name'] as String : '';
    final extension = map['extension'] is String
        ? map['extension'] as String
        : (name.contains('.') ? name.split('.').last.toLowerCase() : '');
    return FileInfo(
      // Keep the stored path/name/type: images carry a label (`image 1`) as
      // their name, so re-deriving from the path would lose it.
      path: path,
      name: name,
      extension: extension,
      type: FileType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => FileType.other,
      ),
      size: map['size'] is int ? map['size'] as int : null,
    );
  }
}

const _defaultCapacity = 500;

/// Creates an initial [PromptHistoryState] from raw entries.
///
/// - Filters out empty/whitespace-only texts.
/// - Deduplicates consecutive equal entries (comparison normalized by trim).
/// - Trims to the last [maxCapacity] entries.
/// - Resets navigation (`index`/`draft`).
PromptHistoryState createHistory(
  List<PromptHistoryEntry> items, {
  int maxCapacity = _defaultCapacity,
}) {
  final filtered = <PromptHistoryEntry>[];
  for (final item in items) {
    if (item.text.trim().isEmpty) continue;
    final last = filtered.isEmpty ? null : filtered.last;
    if (last != null && last.text.trim() == item.text.trim()) continue;
    filtered.add(item);
  }
  final trimmed = filtered.length > maxCapacity
      ? filtered.sublist(filtered.length - maxCapacity)
      : filtered;
  return PromptHistoryState(items: trimmed, index: null, draft: '');
}

/// Pushes a new entry onto the history ring.
///
/// - Ignores empty/whitespace-only texts.
/// - Deduplicates against the last entry (comparison normalized by trim).
/// - Trims to [maxCapacity] entries.
/// - Resets navigation (`index`/`draft`).
PromptHistoryState pushHistory(
  PromptHistoryState state,
  PromptHistoryEntry entry, {
  int maxCapacity = _defaultCapacity,
}) {
  if (entry.text.trim().isEmpty) return state;

  final last = state.items.isNotEmpty ? state.items.last : null;
  if (last != null && last.text.trim() == entry.text.trim()) {
    return PromptHistoryState(items: state.items, index: null, draft: '');
  }

  final next = List<PromptHistoryEntry>.from(state.items)..add(entry);
  if (next.length > maxCapacity) {
    next.removeRange(0, next.length - maxCapacity);
  }
  return PromptHistoryState(items: next, index: null, draft: '');
}

/// Result of a navigation move: either a stored entry (with its attachments)
/// or the restored draft text.
class PromptHistoryMove {
  const PromptHistoryMove.entry(this.entry) : draft = null;
  const PromptHistoryMove.draft(this.draft) : entry = null;

  final PromptHistoryEntry? entry;

  /// Non-null when navigation moved past the newest entry into the draft.
  /// May be an empty string (an empty draft).
  final String? draft;

  /// The text the field should show.
  String get text => entry?.text ?? draft ?? '';
}

/// Result of a pure state navigation move.
class HistoryMoveResult {
  const HistoryMoveResult(this.state, this.entry);

  final PromptHistoryState state;
  final PromptHistoryEntry? entry;
}

HistoryMoveResult _moveUp(PromptHistoryState state, String currentText) {
  if (state.items.isEmpty) return HistoryMoveResult(state, null);

  final nextIndex = state.index == null
      ? state.items.length - 1
      : state.index! - 1;
  if (nextIndex < 0) return HistoryMoveResult(state, null);

  final draft = state.index == null ? currentText : state.draft;
  return HistoryMoveResult(
    state.copyWith(index: nextIndex, draft: draft),
    state.items[nextIndex],
  );
}

HistoryMoveResult _moveDown(PromptHistoryState state) {
  if (state.items.isEmpty) return HistoryMoveResult(state, null);
  if (state.index == null) return HistoryMoveResult(state, null);

  final nextIndex = state.index! + 1;
  if (nextIndex >= state.items.length) {
    return HistoryMoveResult(
      PromptHistoryState(items: state.items, index: null, draft: state.draft),
      null,
    );
  }

  return HistoryMoveResult(
    state.copyWith(index: nextIndex),
    state.items[nextIndex],
  );
}

/// Moves one step up in history (toward older entries).
PromptHistoryState moveHistoryUpState(PromptHistoryState state, String text) {
  return _moveUp(state, text).state;
}

/// Moves one step down in history (toward newer entries).
PromptHistoryState moveHistoryDownState(PromptHistoryState state) {
  return _moveDown(state).state;
}

/// Combined navigation result for moving up.
HistoryMoveResult moveHistoryUpResult(PromptHistoryState state, String text) {
  return _moveUp(state, text);
}

/// Combined navigation result for moving down.
HistoryMoveResult moveHistoryDownResult(PromptHistoryState state) {
  return _moveDown(state);
}

/// Controller owning a prompt-history ring, optionally backed by storage.
class PromptHistoryController extends ChangeNotifier {
  PromptHistoryController({
    this.storage,
    this.maxCapacity = _defaultCapacity,
    this.filter,
  }) : state = const PromptHistoryState(items: [], index: null, draft: '') {
    if (storage != null) {
      unawaited(load());
    }
  }

  final PromptHistoryStorage? storage;
  final int maxCapacity;
  final bool Function(String text)? filter;

  PromptHistoryState state;

  Future<void>? _loadFuture;

  /// The stored entries, oldest-first.
  List<PromptHistoryEntry> get items => List.unmodifiable(state.items);

  /// The stored texts, oldest-first (convenience for display).
  List<String> get texts =>
      List.unmodifiable([for (final item in state.items) item.text]);

  /// Loads entries from [storage] (if any) and applies filtering/dedup/cap.
  /// Idempotent and concurrency-safe: repeated calls share one future.
  Future<void> load() {
    if (storage == null) {
      return Future<void>.value();
    }
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final loaded = await storage!.load();
      final merged = <PromptHistoryEntry>[...loaded, ...state.items];
      state = createHistory(merged, maxCapacity: maxCapacity);
      await storage!.rewrite(state.items);
    } on Exception {
      // Best-effort: keep empty history.
    }
    notifyListeners();
  }

  /// Appends [text] with its [files] unless the text is blank, filtered out,
  /// or duplicates the newest entry. Resets any in-progress navigation.
  ///
  /// Deduplication compares text only, so re-sending the same text with
  /// different files keeps the files stored with the first entry.
  void push(String text, {List<FileInfo> files = const []}) {
    if (text.trim().isEmpty) return;
    if (filter != null && !filter!(text)) return;

    final lastBefore = state.items.isNotEmpty ? state.items.last : null;
    final appended =
        lastBefore == null || lastBefore.text.trim() != text.trim();

    final previousLength = state.items.length;
    state = pushHistory(
      state,
      PromptHistoryEntry(text: text, files: List.unmodifiable(files)),
      maxCapacity: maxCapacity,
    );
    final trimmed = state.items.length < previousLength + (appended ? 1 : 0);
    if (appended) {
      final entry = state.items.isEmpty ? null : state.items.last;
      if (entry != null) {
        if (trimmed) {
          unawaited(_rewriteBestEffort(state.items));
        } else {
          unawaited(_appendBestEffort(entry));
        }
      }
    }
    notifyListeners();
  }

  Future<void> _rewriteBestEffort(List<PromptHistoryEntry> items) async {
    try {
      await storage?.rewrite(items);
    } on Exception {
      // Best-effort.
    }
  }

  Future<void> _appendBestEffort(PromptHistoryEntry entry) async {
    try {
      await storage?.append(entry);
    } on Exception {
      // Best-effort.
    }
  }

  /// Steps one entry back, saving [currentText] as the draft on the first
  /// step. Returns the entry to display (with its files), or null when
  /// navigation is not applicable — in which case nothing is notified.
  PromptHistoryMove? moveUp({required String currentText}) {
    final result = moveHistoryUpResult(state, currentText);
    if (result.entry == null) return null;
    state = result.state;
    notifyListeners();
    return PromptHistoryMove.entry(result.entry!);
  }

  /// Steps one entry forward, restoring the saved draft (which may be empty)
  /// past the newest entry. Returns null when already at the end — in which
  /// case nothing is notified, so repeated presses do not repeat the draft.
  PromptHistoryMove? moveDown() {
    if (state.index == null || state.items.isEmpty) return null;
    final result = moveHistoryDownResult(state);
    state = result.state;
    notifyListeners();
    final entry = result.entry;
    if (entry != null) return PromptHistoryMove.entry(entry);
    // Past the newest entry: the draft (kept by the transition) is restored.
    return PromptHistoryMove.draft(state.draft);
  }

  /// Drops the browse position and draft, keeping stored entries.
  void resetNavigation() {
    if (state.index == null && state.draft.isEmpty) return;
    state = PromptHistoryState(items: state.items, index: null, draft: '');
    notifyListeners();
  }

  /// Clears all entries and rewrites the store empty.
  Future<void> clear() async {
    state = const PromptHistoryState(items: [], index: null, draft: '');
    _loadFuture = null;
    try {
      await storage?.rewrite(const []);
    } on Exception {
      // Best-effort.
    }
    notifyListeners();
  }
}
