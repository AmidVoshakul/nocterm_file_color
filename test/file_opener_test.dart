import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

void main() {
  group('FileOpener', () {
    test('buildLocationCommand rejects empty path', () {
      expect(
        () => FileOpener.buildLocationCommand(''),
        throwsA(isA<FileOpenerException>()),
      );
    });

    test('buildLocationCommand rejects control characters', () {
      expect(
        () => FileOpener.buildLocationCommand('path\u0000withnull'),
        throwsA(isA<FileOpenerException>()),
      );
      expect(
        () => FileOpener.buildLocationCommand('path\nwithnewline'),
        throwsA(isA<FileOpenerException>()),
      );
    });

    test('buildLocationCommand accepts a path containing the digit 0', () {
      final directory = Directory.systemTemp.createTempSync();
      final file = File('${directory.path}/img0.txt')..writeAsStringSync('x');

      expect(
        FileOpener.buildLocationCommand(file.path).first,
        Platform.isWindows ? 'explorer' : 'xdg-open',
      );
      directory.deleteSync(recursive: true);
    });

    test('buildLocationCommand rejects non-existent file', () {
      expect(
        () => FileOpener.buildLocationCommand('/this/path/does/not/exist.txt'),
        throwsA(isA<FileOpenerException>()),
      );
    });
  });
}
