import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

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

  final List<String> items;
  final int? index;
  final String draft;

  PromptHistoryState copyWith({
    List<String>? items,
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

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
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
  Future<List<String>> load();

  /// Appends a single entry. Best-effort; failures are swallowed.
  Future<void> append(String entry);

  /// Rewrites the whole store (used for trimming and self-healing). Best-effort.
  Future<void> rewrite(List<String> items);
}

/// In-memory storage that keeps nothing: load returns empty, append/rewrite
/// are no-ops. Used when no persistence is wanted.
class InMemoryPromptHistoryStorage implements PromptHistoryStorage {
  const InMemoryPromptHistoryStorage();

  @override
  Future<List<String>> load() async => const <String>[];

  @override
  Future<void> append(String entry) async {}

  @override
  Future<void> rewrite(List<String> items) async {}
}

/// File-backed storage that persists entries as JSONL (one `{"input": ...}`
/// object per line). The host owns the path; the package only writes to it.
///
/// The path is trusted input (host-provided). It is normalized for traversal
/// safety in debug builds.
class FilePromptHistoryStorage implements PromptHistoryStorage {
  FilePromptHistoryStorage(this.path) : assert(!path.contains('..'));

  final String path;

  @override
  Future<List<String>> load() async {
    try {
      final file = File(path);
      if (!file.existsSync()) return const <String>[];
      final lines = await file.readAsLines();
      return PromptHistoryCodec.decode(lines.join('\n'));
    } on Exception {
      return const <String>[];
    }
  }

  @override
  Future<void> append(String entry) async {
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
  Future<void> rewrite(List<String> items) async {
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

/// JSONL codec for prompt-history entries, matching the chatorai/opencode
/// format (`{"input": "..."}` per line). Keeps storage implementations dumb.
class PromptHistoryCodec {
  const PromptHistoryCodec._();

  /// Serializes a list of entries to JSONL.
  static String encode(List<String> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln(encodeEntry(item));
    }
    return buffer.toString();
  }

  /// Serializes a single entry to one JSONL line.
  static String encodeEntry(String input) => jsonEncode({'input': input});

  /// Parses JSONL into a list of prompt strings. Broken/empty/non-JSON
  /// lines are skipped; empty `input` values are filtered out.
  static List<String> decode(String text) {
    final result = <String>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        final input = decoded['input'];
        if (input is String && input.trim().isNotEmpty) {
          result.add(input);
        }
      } on FormatException {
        // skip broken JSON
      } on TypeError {
        // skip unexpected JSON shape
      }
    }
    return result;
  }
}

const _defaultCapacity = 500;

/// Creates an initial [PromptHistoryState] from raw items.
///
/// - Filters out empty/whitespace-only strings.
/// - Deduplicates consecutive equal items (comparison normalized by trim).
/// - Trims to the last [_defaultCapacity] entries.
/// - Resets navigation (`index`/`draft`).
PromptHistoryState createHistory(
  List<String> items, {
  int maxCapacity = _defaultCapacity,
}) {
  final filtered = <String>[];
  for (final item in items) {
    if (item.trim().isEmpty) continue;
    if (filtered.isNotEmpty && filtered.last.trim() == item.trim()) continue;
    filtered.add(item);
  }
  final trimmed = filtered.length > maxCapacity
      ? filtered.sublist(filtered.length - maxCapacity)
      : filtered;
  return PromptHistoryState(items: trimmed, index: null, draft: '');
}

/// Pushes a new entry onto the history ring.
///
/// - Ignores empty/whitespace-only strings.
/// - Deduplicates against the last item (comparison normalized by trim).
/// - Trims to [maxCapacity] entries.
/// - Resets navigation (`index`/`draft`).
PromptHistoryState pushHistory(
  PromptHistoryState state,
  String entry, {
  int maxCapacity = _defaultCapacity,
}) {
  if (entry.trim().isEmpty) return state;

  final last = state.items.isNotEmpty ? state.items.last : null;
  if (last != null && last.trim() == entry.trim()) {
    return PromptHistoryState(items: state.items, index: null, draft: '');
  }

  final next = List<String>.from(state.items)..add(entry);
  if (next.length > maxCapacity) {
    next.removeRange(0, next.length - maxCapacity);
  }
  return PromptHistoryState(items: next, index: null, draft: '');
}

/// Result of a navigation move.
class HistoryMoveResult {
  const HistoryMoveResult(this.state, this.text);

  final PromptHistoryState state;
  final String? text;
}

HistoryMoveResult _moveUp(PromptHistoryState state, String text) {
  if (state.items.isEmpty) return HistoryMoveResult(state, null);

  final nextIndex = state.index == null
      ? state.items.length - 1
      : state.index! - 1;
  if (nextIndex < 0) return HistoryMoveResult(state, null);

  final draft = state.index == null ? text : state.draft;
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
      state.draft,
    );
  }

  return HistoryMoveResult(
    state.copyWith(index: nextIndex),
    state.items[nextIndex],
  );
}

/// Moves one step up in history (toward older entries).
///
/// Returns the updated state. The displayed text is [result.text] (null when
/// navigation is not applicable).
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

  List<String> get items => List.unmodifiable(state.items);

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
      final merged = <String>[...loaded, ...state.items];
      state = createHistory(merged, maxCapacity: maxCapacity);
      await storage!.rewrite(state.items);
    } on Exception {
      // Best-effort: keep empty history.
    }
    notifyListeners();
  }

  /// Appends [entry] unless it is blank, filtered out, or duplicates the
  /// newest item. Resets any in-progress navigation.
  void push(String entry) {
    if (entry.trim().isEmpty) return;
    if (filter != null && !filter!(entry)) return;

    final lastBefore = state.items.isNotEmpty ? state.items.last : null;
    final appended = lastBefore == null || lastBefore.trim() != entry.trim();

    final previousLength = state.items.length;
    state = pushHistory(state, entry, maxCapacity: maxCapacity);
    final trimmed = state.items.length < previousLength + (appended ? 1 : 0);
    if (appended) {
      if (trimmed) {
        unawaited(_rewriteBestEffort(state.items));
      } else {
        unawaited(_appendBestEffort(entry));
      }
    }
    notifyListeners();
  }

  Future<void> _rewriteBestEffort(List<String> items) async {
    try {
      await storage?.rewrite(items);
    } on Exception {
      // Best-effort.
    }
  }

  Future<void> _appendBestEffort(String entry) async {
    try {
      await storage?.append(entry);
    } on Exception {
      // Best-effort.
    }
  }

  /// Steps one entry back, saving [currentText] as the draft on the first
  /// step. Returns the entry text to display, or null when navigation is
  /// not applicable.
  String? moveUp({required String currentText}) {
    final result = moveHistoryUpResult(state, currentText);
    if (result.text == null) return null;
    state = result.state;
    notifyListeners();
    return result.text;
  }

  /// Steps one entry forward, restoring the saved draft past the newest
  /// entry. Returns the text to display, or null when already at the end.
  String? moveDown() {
    final result = moveHistoryDownResult(state);
    if (result.text == null) return null;
    state = result.state;
    notifyListeners();
    return result.text;
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
      await storage?.rewrite(const <String>[]);
    } on Exception {
      // Best-effort.
    }
    notifyListeners();
  }
}
