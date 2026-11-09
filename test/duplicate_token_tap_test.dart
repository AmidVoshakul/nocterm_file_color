import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

void main() {
  group('duplicate labels', () {
    test('a tap resolves to the token that was tapped', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      FileInfo? clicked;

      await testNocterm('duplicate tap', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: false,
            width: 40,
            height: 1,
            onFileClick: (file) => clicked = file,
          ),
        );
        // Two files in different directories share the basename, so both
        // labels read `[main.dart]`.
        key.currentState!.attachFile(
          FileInfo.fromPath('/home/user/a/main.dart'),
        );
        key.currentState!.attachFile(
          FileInfo.fromPath('/home/user/b/main.dart'),
        );
        await tester.pump();
        expect(controller.text, '[main.dart] [main.dart] ');

        // Column 14 sits inside the second label (columns 12-22).
        await tester.press(14, 0);
        await tester.release(14, 0);

        expect(clicked?.path, '/home/user/b/main.dart');
      });

      controller.dispose();
    });

    test('detaching one duplicate detaches its own span', () async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('duplicate detach', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
          ),
        );
        final first = FileInfo.fromPath('/home/user/a/main.dart');
        final second = FileInfo.fromPath('/home/user/b/main.dart');
        key.currentState!.attachFile(first);
        key.currentState!.attachFile(second);
        await tester.pump();

        key.currentState!.detachFile(second);
        await tester.pump();

        expect(controller.text, '[main.dart] ');
        expect(key.currentState!.getAttachedFiles(), [first]);
      });

      controller.dispose();
    });
  });
}
