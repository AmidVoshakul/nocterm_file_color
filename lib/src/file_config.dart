import 'package:nocterm/nocterm.dart';

import 'file_detector.dart';
import 'file_info.dart';

/// Visual appearance of a [FileTag].
///
/// A style bundles the foreground/background colors, the label prefix and the
/// font weight used to render an attached file. All fields are optional so a
/// partial style can be layered on top of a default one.
class FileStyle {
  const FileStyle({this.text, this.background, this.prefix, this.bold = false});

  /// Foreground color of the tag text.
  final Color? text;

  /// Background color of the tag.
  final Color? background;

  /// Category word used to label attachments that have no meaningful name.
  ///
  /// Only images are labelled this way, e.g. `[image 1]`. When `null` the
  /// file's [FileType] name is used. Ignored for files labelled by name, such
  /// as `[lib/main.dart]`.
  final String? prefix;

  /// Whether the tag text is rendered bold.
  final bool bold;

  /// Returns a copy of this style with the given fields replaced.
  FileStyle copyWith({
    Color? text,
    Color? background,
    String? prefix,
    bool? bold,
  }) {
    return FileStyle(
      text: text ?? this.text,
      background: background ?? this.background,
      prefix: prefix ?? this.prefix,
      bold: bold ?? this.bold,
    );
  }

  /// Converts this style into a Nocterm [TextStyle].
  TextStyle toTextStyle() {
    return TextStyle(
      color: text,
      backgroundColor: background,
      fontWeight: bold ? FontWeight.bold : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileStyle &&
        other.text == text &&
        other.background == background &&
        other.prefix == prefix &&
        other.bold == bold;
  }

  @override
  int get hashCode => Object.hash(text, background, prefix, bold);
}

/// Maps file categories and extensions to [FileStyle]s.
///
/// A [FileConfig] is the single place where the color scheme of attached files
/// is defined. Lookups are resolved in two steps: first by extension (exact
/// match), then by [FileType]. Extensions always win, so an app can recolor a
/// single extension without touching the category default.
class FileConfig {
  const FileConfig({this._typeStyles, this._extensionStyles});

  /// Builds the built-in color scheme.
  ///
  /// Every [FileType] gets a distinct foreground/background pair drawn from the
  /// Nocterm palette. Use it as a starting point and override what you need.
  factory FileConfig.defaultConfig() {
    return FileConfig(
      typeStyles: {
        FileType.image: const FileStyle(
          text: Colors.brightMagenta,
          background: Colors.magenta,
          prefix: 'image',
          bold: true,
        ),
        FileType.document: const FileStyle(
          text: Colors.brightBlue,
          background: Colors.blue,
          prefix: 'document',
        ),
        FileType.code: const FileStyle(
          text: Colors.brightGreen,
          background: Colors.green,
          prefix: 'code',
        ),
        FileType.archive: const FileStyle(
          text: Colors.brightYellow,
          background: Colors.yellow,
          prefix: 'archive',
        ),
        FileType.audio: const FileStyle(
          text: Colors.brightCyan,
          background: Colors.cyan,
          prefix: 'audio',
        ),
        FileType.video: const FileStyle(
          text: Colors.brightRed,
          background: Colors.red,
          prefix: 'video',
        ),
        FileType.other: const FileStyle(
          text: Colors.brightWhite,
          background: Colors.grey,
          prefix: 'file',
        ),
      },
    );
  }

  final Map<FileType, FileStyle>? _typeStyles;
  final Map<String, FileStyle>? _extensionStyles;

  /// Styles keyed by [FileType].
  Map<FileType, FileStyle> get typeStyles =>
      Map.unmodifiable(_typeStyles ?? const {});

  /// Styles keyed by lowercase extension (without the leading dot).
  Map<String, FileStyle> get extensionStyles => Map.unmodifiable(
    (_extensionStyles ?? const {}).map(
      (key, value) => MapEntry(FileDetector.normalizeExtension(key), value),
    ),
  );

  /// Returns the style that should be used for [file].
  ///
  /// Resolution order: extension override, then category default, then a
  /// neutral fallback so a tag is always renderable.
  FileStyle styleFor(FileInfo file) {
    return styleForExtension(file.extension) ?? styleForType(file.type);
  }

  /// Returns the style registered for [type], or a neutral fallback.
  FileStyle styleForType(FileType type) {
    return _typeStyles?[type] ?? const FileStyle();
  }

  /// Returns the style registered for [extension], or `null` when unset.
  ///
  /// The extension is normalized before lookup, so `DART` and `.dart` both hit
  /// the `dart` entry.
  FileStyle? styleForExtension(String extension) {
    final styles = _extensionStyles;
    if (styles == null || styles.isEmpty) return null;
    return styles[FileDetector.normalizeExtension(extension)];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileConfig &&
        _mapsEqual(other._typeStyles, _typeStyles) &&
        _mapsEqual(other._extensionStyles, _extensionStyles);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(_typeStyles?.entries ?? const []),
    Object.hashAllUnordered(_extensionStyles?.entries ?? const []),
  );
}

bool _mapsEqual<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
