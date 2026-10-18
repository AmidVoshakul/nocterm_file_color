import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';

/// Inline, colored label representing a single attached file.
///
/// A tag renders with the delimiters and colors of its [FileStyle]. By default
/// the delimiters are square brackets, but they can be omitted or customized.
/// Files that carry a meaningful name (everything but images) show that name,
/// e.g. `[lib/main.dart]`; images are identified by their category and a
/// one-based [index], e.g. `[image 1]`, `[image 2]`.
///
/// Tags are clickable when [onTap] is provided. [FileTextField] wires that tap
/// to its `onFileClick` callback, which by default opens the file location in
/// the OS file manager.
class FileTag extends StatelessComponent {
  const FileTag({
    super.key,
    required this.file,
    required this.style,
    this.index,
    this.onTap,
  });

  /// The file this tag represents.
  final FileInfo file;

  /// Visual appearance of the tag.
  final FileStyle style;

  /// One-based position of the attachment, used to disambiguate images.
  ///
  /// Ignored for files that are labelled by name.
  final int? index;

  /// Called when the tag is tapped, receiving the represented [file].
  final ValueChanged<FileInfo>? onTap;

  /// Builds the plain text placed between the brackets.
  ///
  /// Shared with [FileTextField] so the text inserted into the editing
  /// controller is byte-for-byte identical to the rendered label.
  static String labelFor(FileInfo file, FileStyle style, {int? index}) {
    if (file.type == FileType.image) {
      final word = style.prefix ?? file.displayLabel;
      if (index != null) return '$word $index';
      if (file.name.startsWith('$word ')) return file.name;
      return word;
    }
    return file.name;
  }

  /// Returns the complete token stored in the editing controller.
  static String tokenFor(FileInfo file, FileStyle style, {int? index}) =>
      '${style.openingDelimiter}${labelFor(file, style, index: index)}${style.closingDelimiter}';

  /// Label of this tag, without the surrounding brackets.
  String get label => labelFor(file, style, index: index);

  @override
  Component build(BuildContext context) {
    final text = Text(
      '${style.openingDelimiter}$label${style.closingDelimiter}',
      style: style.toTextStyle(),
    );
    if (onTap == null) return text;
    return GestureDetector(onTap: () => onTap!(file), child: text);
  }
}
