import 'file_detector.dart';

/// Category of an attached file, derived from its extension.
///
/// The category drives the default color scheme used by [FileTag] and can be
/// customized through [FileConfig].
enum FileType {
  /// Raster or vector images (`.png`, `.jpg`, `.svg`, ...).
  image,

  /// Text documents and PDFs (`.txt`, `.md`, `.pdf`, ...).
  document,

  /// Source code files (`.dart`, `.ts`, `.go`, ...).
  code,

  /// Compressed archives (`.zip`, `.tar`, `.gz`, ...).
  archive,

  /// Audio files (`.mp3`, `.wav`, ...).
  audio,

  /// Video files (`.mp4`, `.mov`, ...).
  video,

  /// Anything that does not match a known category.
  other,
}

/// Immutable description of a file attached to a [FileTextField].
///
/// Instances are created by the package whenever a file is inserted (paste,
/// `@`-mention, drag & drop, ...) and handed back to the host application via
/// [FileTextField.getAttachedFiles] and the `onFilesChanged` callback.
class FileInfo {
  const FileInfo({
    required this.path,
    required this.name,
    required this.extension,
    required this.type,
    this.size,
  });

  /// Builds a [FileInfo] from a filesystem [path].
  ///
  /// The file name and extension are derived from the path, and the type is
  /// resolved with `FileDetector.detectType`. [size] is optional because the
  /// host application may not know it (e.g. for a path typed by hand).
  factory FileInfo.fromPath(String path, {int? size}) {
    final normalized = _normalizePath(path);
    final fileName = _fileNameOf(normalized);
    final extension = _extensionOf(fileName);
    return FileInfo(
      path: normalized,
      name: fileName,
      extension: extension,
      type: FileDetector.detectType(extension),
      size: size,
    );
  }

  /// Absolute or relative path of the file on disk.
  final String path;

  /// File name including the extension (e.g. `main.dart`).
  final String name;

  /// Lowercase extension without the leading dot (e.g. `dart`).
  ///
  /// Empty string when the file has no extension.
  final String extension;

  /// Category resolved from [extension].
  final FileType type;

  /// File size in bytes, or `null` when unknown.
  final int? size;

  /// Human readable label used inside the inline tag.
  ///
  /// Images are labelled by their type (`image`) so that repeated attachments
  /// read as `[image 1]`, `[image 2]`, ...; every other file shows its name.
  String get displayLabel => type == FileType.image ? 'image' : name;

  /// Returns a copy of this file with the given fields replaced.
  FileInfo copyWith({
    String? path,
    String? name,
    String? extension,
    FileType? type,
    int? size,
  }) {
    return FileInfo(
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      type: type ?? this.type,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileInfo &&
        other.path == path &&
        other.name == name &&
        other.extension == extension &&
        other.type == type &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(path, name, extension, type, size);

  @override
  String toString() =>
      'FileInfo(path: $path, name: $name, extension: $extension, '
      'type: ${type.name}, size: $size)';
}

/// Collapses redundant separators and strips a trailing separator.
String _normalizePath(String path) {
  var result = path.trim();
  if (result.isEmpty) return result;
  result = result.replaceAll(RegExp(r'[\\/]+'), '/');
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

/// Returns the last path segment of an already normalized path.
String _fileNameOf(String normalizedPath) {
  if (normalizedPath.isEmpty) return '';
  final separator = normalizedPath.lastIndexOf('/');
  return separator == -1
      ? normalizedPath
      : normalizedPath.substring(separator + 1);
}

/// Returns the lowercase extension without the leading dot.
String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}
