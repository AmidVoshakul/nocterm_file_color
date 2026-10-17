import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';
import 'package:nocterm/nocterm.dart' show Colors, FontWeight;

void main() {
  group('FileDetector', () {
    test('detects image extensions', () {
      expect(FileDetector.detectType('png'), FileType.image);
      expect(FileDetector.detectType('jpg'), FileType.image);
      expect(FileDetector.detectType('svg'), FileType.image);
    });

    test('detects code extensions', () {
      expect(FileDetector.detectType('dart'), FileType.code);
      expect(FileDetector.detectType('ts'), FileType.code);
      expect(FileDetector.detectType('go'), FileType.code);
    });

    test('detects document extensions', () {
      expect(FileDetector.detectType('pdf'), FileType.document);
      expect(FileDetector.detectType('md'), FileType.document);
      expect(FileDetector.detectType('txt'), FileType.document);
    });

    test('detects archive extensions', () {
      expect(FileDetector.detectType('zip'), FileType.archive);
      expect(FileDetector.detectType('tar'), FileType.archive);
    });

    test('detects audio extensions', () {
      expect(FileDetector.detectType('mp3'), FileType.audio);
      expect(FileDetector.detectType('wav'), FileType.audio);
    });

    test('detects video extensions', () {
      expect(FileDetector.detectType('mp4'), FileType.video);
      expect(FileDetector.detectType('mov'), FileType.video);
    });

    test('returns other for unknown extensions', () {
      expect(FileDetector.detectType('xyz'), FileType.other);
      expect(FileDetector.detectType(''), FileType.other);
    });

    test('normalizes extensions with leading dot and uppercase', () {
      expect(FileDetector.detectType('.PNG'), FileType.image);
      expect(FileDetector.detectType('DART'), FileType.code);
    });
  });

  group('FileInfo', () {
    test('fromPath extracts name and extension', () {
      final file = FileInfo.fromPath('/home/user/lib/main.dart');
      expect(file.name, 'main.dart');
      expect(file.extension, 'dart');
      expect(file.type, FileType.code);
    });

    test('fromPath handles files without extension', () {
      final file = FileInfo.fromPath('/home/user/Makefile');
      expect(file.name, 'Makefile');
      expect(file.extension, '');
      expect(file.type, FileType.other);
    });

    test('fromPath normalizes path separators', () {
      final file = FileInfo.fromPath(r'C:\Users\test\file.txt');
      expect(file.name, 'file.txt');
      expect(file.extension, 'txt');
      expect(file.type, FileType.document);
    });

    test('displayLabel returns image for image type', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      expect(file.displayLabel, 'image');
    });

    test('displayLabel returns name for non-image types', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      expect(file.displayLabel, 'main.dart');
    });

    test('equality is based on all fields', () {
      final a = FileInfo.fromPath('/tmp/test.txt');
      final b = FileInfo.fromPath('/tmp/test.txt');
      expect(a, equals(b));
    });

    test('copyWith returns a new instance with updated fields', () {
      final file = FileInfo.fromPath('/tmp/test.txt');
      final copy = file.copyWith(name: 'renamed.txt');
      expect(copy.name, 'renamed.txt');
      expect(copy.path, file.path);
    });
  });

  group('FileConfig', () {
    test('defaultConfig provides styles for all file types', () {
      final config = FileConfig.defaultConfig();
      for (final type in FileType.values) {
        final file = FileInfo(
          path: 'test.$type',
          name: 'test.$type',
          extension: type.name,
          type: type,
        );
        expect(config.styleFor(file), isNotNull);
      }
    });

    test('styleForExtension returns extension override or null', () {
      final config = FileConfig(
        typeStyles: {FileType.code: const FileStyle(text: Colors.red)},
        extensionStyles: {'dart': const FileStyle(text: Colors.green)},
      );
      expect(config.styleForExtension('dart')?.text, Colors.green);
      expect(
        config.styleForExtension('go'),
        isNull,
      ); // No extension override -> nullension override -> null
    });

    test('styleFor returns null for unknown extension without default', () {
      final config = const FileConfig();
      expect(config.styleForExtension('unknown'), isNull);
    });

    test('FileStyle.toTextStyle converts correctly', () {
      const style = FileStyle(
        text: Colors.red,
        background: Colors.blue,
        bold: true,
      );
      final textStyle = style.toTextStyle();
      expect(textStyle.color, Colors.red);
      expect(textStyle.backgroundColor, Colors.blue);
      expect(textStyle.fontWeight, FontWeight.bold);
    });

    test('FileStyle.copyWith returns updated style', () {
      const style = FileStyle(text: Colors.red);
      final copy = style.copyWith(background: Colors.blue);
      expect(copy.text, Colors.red);
      expect(copy.background, Colors.blue);
    });
  });

  group('FileTag', () {
    test('labelFor returns image prefix for images', () {
      final file = FileInfo.fromPath('/tmp/photo.png');
      final style = const FileStyle(prefix: 'image');
      expect(FileTag.labelFor(file, style, index: 1), 'image 1');
    });

    test('labelFor returns file name for non-images', () {
      final file = FileInfo.fromPath('/tmp/main.dart');
      final style = const FileStyle(prefix: 'code');
      expect(FileTag.labelFor(file, style), 'main.dart');
    });
  });
}
