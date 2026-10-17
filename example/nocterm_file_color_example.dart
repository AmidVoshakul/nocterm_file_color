import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';

void main() {
  runApp(FileTextFieldExample());
}

/// Example showing FileTextField with file attachments.
class FileTextFieldExample extends StatelessComponent {
  const FileTextFieldExample({super.key});

  @override
  Component build(BuildContext context) {
    final config = FileConfig.defaultConfig();

    return FileTextField(
      fileConfig: config,
      onFileClick: (file) {
        // Default: open file location in OS file manager
        // Could be customized to show a preview, etc.
      },
      onFilesChanged: (files) {
        // Called whenever attachments change
        // Could update UI or send to model
      },
    );
  }
}
