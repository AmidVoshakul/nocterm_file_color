import 'file_info.dart';

/// Resolves a [FileType] from a file extension.
///
/// Detection is intentionally extension-only: the package never reads file
/// contents, so it stays cheap and side-effect free. Unknown extensions map to
/// [FileType.other].
class FileDetector {
  const FileDetector._();

  /// Extensions grouped by the category they belong to.
  ///
  /// Keys are lowercase and stored without the leading dot.
  static const Map<FileType, Set<String>> _extensionsByType = {
    FileType.image: {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'bmp',
      'webp',
      'ico',
      'tiff',
      'tif',
      'svg',
      'psd',
      'heic',
      'avif',
    },
    FileType.document: {
      'txt',
      'md',
      'markdown',
      'rst',
      'pdf',
      'doc',
      'docx',
      'odt',
      'rtf',
      'tex',
      'log',
      'csv',
      'tsv',
      'epub',
    },
    FileType.code: {
      'dart',
      'js',
      'mjs',
      'cjs',
      'ts',
      'tsx',
      'jsx',
      'py',
      'rb',
      'go',
      'rs',
      'c',
      'h',
      'cc',
      'cpp',
      'cxx',
      'hpp',
      'cs',
      'java',
      'kt',
      'kts',
      'swift',
      'm',
      'mm',
      'php',
      'pl',
      'lua',
      'sh',
      'bash',
      'zsh',
      'fish',
      'ps1',
      'sql',
      'html',
      'htm',
      'css',
      'scss',
      'sass',
      'less',
      'vue',
      'svelte',
      'json',
      'yaml',
      'yml',
      'toml',
      'xml',
      'ini',
      'cfg',
      'conf',
      'gradle',
      'cmake',
      'mk',
      'dockerfile',
      'proto',
      'graphql',
      'gql',
    },
    FileType.archive: {
      'zip',
      'tar',
      'gz',
      'tgz',
      'bz2',
      'xz',
      '7z',
      'rar',
      'lz4',
      'zst',
    },
    FileType.audio: {
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'oga',
      'opus',
      'm4a',
      'wma',
      'aiff',
      'mid',
      'midi',
    },
    FileType.video: {
      'mp4',
      'm4v',
      'mov',
      'avi',
      'mkv',
      'webm',
      'flv',
      'wmv',
      'mpeg',
      'mpg',
      '3gp',
    },
  };

  /// Returns the [FileType] for [extension].
  ///
  /// Accepts extensions with or without the leading dot and in any letter case
  /// (`DART`, `.dart` and `dart` are equivalent). Unknown or empty extensions
  /// resolve to [FileType.other].
  static FileType detectType(String extension) {
    final normalized = normalizeExtension(extension);
    if (normalized.isEmpty) return FileType.other;
    for (final entry in _extensionsByType.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return FileType.other;
  }

  /// Returns every extension that maps to [type].
  ///
  /// The returned set is unmodifiable, so callers cannot corrupt the internal
  /// mapping.
  static Set<String> extensionsFor(FileType type) =>
      Set.unmodifiable(_extensionsByType[type] ?? const <String>{});

  /// Lowercases [extension] and strips a single leading dot.
  static String normalizeExtension(String extension) {
    var result = extension.trim().toLowerCase();
    if (result.startsWith('.')) result = result.substring(1);
    return result;
  }
}
