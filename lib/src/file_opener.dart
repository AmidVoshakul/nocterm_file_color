import 'dart:io';

/// Thrown when the operating system could not be asked to reveal a file.
class FileOpenerException implements Exception {
  const FileOpenerException(this.message, {this.path});

  /// Human readable description of what went wrong.
  final String message;

  /// The path involved in the failure, when known.
  final String? path;

  @override
  String toString() {
    final suffix = path == null ? '' : ' (path: $path)';
    return 'FileOpenerException: $message$suffix';
  }
}

/// Reveals files in the host operating system's file manager.
///
/// The package never manages the lifecycle of attached files; this helper only
/// asks the OS where a file lives, which is the default action taken when a
/// [FileTag] is clicked.
class FileOpener {
  const FileOpener._();

  /// Builds the platform command that reveals [path] in the file manager.
  ///
  /// Returns `[executable, argument, ...]`. Exposed for testing so the command
  /// can be asserted without spawning a real process.
  ///
  /// Throws [FileOpenerException] when [path] is empty or does not exist.
  static List<String> buildLocationCommand(String path) {
    if (path.isEmpty) {
      throw const FileOpenerException('Cannot open an empty path.');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw FileOpenerException('File does not exist: $path', path: path);
    }

    if (Platform.isWindows) {
      return ['explorer', '/select,${file.path}'];
    }
    if (Platform.isMacOS) {
      return ['open', '-R', file.path];
    }
    return ['xdg-open', file.parent.path];
  }

  /// Reveals [path] in the host file manager.
  ///
  /// Uses `explorer /select` on Windows, `open -R` on macOS and `xdg-open` on
  /// Linux and other Unix-like systems. Throws [FileOpenerException] when the
  /// path is missing or the OS command cannot be started.
  static Future<void> openLocation(String path) async {
    final command = buildLocationCommand(path);
    try {
      await Process.run(command.first, command.sublist(1));
    } on ProcessException catch (error) {
      throw FileOpenerException(
        'Could not run "${command.first}" to open "$path": ${error.message}',
        path: path,
      );
    }
  }
}
