import 'package:characters/characters.dart';
import 'package:nocterm/nocterm.dart';

import 'file_config.dart';
import 'file_info.dart';
import 'terminal_colors.dart';
import 'text_viewport.dart';

/// One chip in a [FileChips] row: a file or a directory with an optional
/// per-item style override.
class FileChipItem {
  const FileChipItem({
    required this.name,
    this.isDirectory = false,
    this.style,
    this.file,
  });

  /// A file chip; its colors default to [FileConfig] for the file.
  factory FileChipItem.file(FileInfo file, {FileStyle? style}) =>
      FileChipItem(name: file.name, file: file, style: style);

  /// A directory chip; its label reads `dir`.
  factory FileChipItem.directory(String name, {FileStyle? style}) =>
      FileChipItem(name: name, isDirectory: true, style: style);

  /// Display name shown on the gray plate.
  final String name;

  /// Whether this chip is a directory (label `dir` instead of `File`).
  final bool isDirectory;

  /// Optional color override for the label plate; defaults to the config
  /// style for [file].
  final FileStyle? style;

  /// The file this chip was built from, when any.
  final FileInfo? file;

  @override
  bool operator ==(Object other) =>
      other is FileChipItem &&
      other.name == name &&
      other.isDirectory == isDirectory &&
      other.file == file &&
      other.style == style;

  @override
  int get hashCode => Object.hash(name, isDirectory, file, style);
}

/// Read-only chips row for attached files, as used at the end of a chat
/// message: a colored label plate (`File` / `dir`) followed by a gray name
/// plate, styled like OpenCode's attachment chips.
///
/// Colors come from [FileConfig] (label plate) and the Nocterm theme (name
/// plate), and every color goes through `TerminalColors`, so `NO_COLOR` drops
/// them all. Stateless and non-interactive apart from [onChipTap].
class FileChips extends StatelessComponent {
  const FileChips({
    super.key,
    required this.items,
    this.config,
    this.labelBuilder,
    this.nameTextColor,
    this.nameBackgroundColor,
    this.gap = 2,
    this.wrap = true,
    this.onChipTap,
  });

  /// The chips to render, in order.
  final List<FileChipItem> items;

  /// Colors for the label plates per type/extension. Defaults to
  /// [FileConfig.defaultConfig].
  final FileConfig? config;

  /// Label text builder; defaults to `File` for files and `dir` for
  /// directories.
  final String Function(bool isDirectory)? labelBuilder;

  /// Name plate text color; defaults to the theme's `onSurface`.
  final Color? nameTextColor;

  /// Name plate background; defaults to the theme's `surface`.
  final Color? nameBackgroundColor;

  /// Columns between chips.
  final int gap;

  /// When true, chips flow onto multiple rows to fit the available width
  /// (default). When false, they stay on one row inside a horizontal
  /// scroll view.
  final bool wrap;

  /// Called when a chip is tapped.
  final ValueChanged<FileChipItem>? onChipTap;

  String _labelFor(FileChipItem item) =>
      labelBuilder?.call(item.isDirectory) ??
      (item.isDirectory ? 'dir' : 'File');

  @override
  Component build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = TuiTheme.of(context);
    final chips = [
      for (final item in items)
        _ChipLayout(_buildChip(item, theme), _labelFor(item), item.name),
    ];
    final spacer = SizedBox(width: gap.toDouble());
    if (!wrap) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              chips[i].child,
              if (i != chips.length - 1) spacer,
            ],
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.toInt()
            : chips.fold<int>(0, (sum, chip) => sum + chip.width + gap);
        final rows = <List<_ChipLayout>>[[]];
        var used = 0;
        for (final chip in chips) {
          if (rows.last.isNotEmpty && used + gap + chip.width > maxWidth) {
            rows.add([]);
            used = 0;
          }
          rows.last.add(chip);
          used = rows.last.length == 1 ? chip.width : used + gap + chip.width;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r != 0) const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows[r].length; i++) ...[
                    rows[r][i].child,
                    if (i != rows[r].length - 1) spacer,
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Component _buildChip(FileChipItem item, TuiThemeData theme) {
    final config = this.config ?? FileConfig.defaultConfig();
    final style =
        item.style ?? (item.file != null ? config.styleFor(item.file!) : null);
    final labelBackground = style?.background ?? theme.primary;
    final labelTextColor = style?.text ?? theme.onPrimary;
    final nameBackground = nameBackgroundColor ?? theme.surface;
    final nameForeground = nameTextColor ?? theme.onSurface;

    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: TerminalColors.resolve(labelBackground),
          ),
          child: Text(
            _labelFor(item),
            style: TextStyle(
              color: TerminalColors.resolve(labelTextColor),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: TerminalColors.resolve(nameBackground),
          ),
          child: Text(
            item.name,
            style: TextStyle(color: TerminalColors.resolve(nameForeground)),
          ),
        ),
      ],
    );
    return onChipTap == null
        ? chip
        : GestureDetector(onTap: () => onChipTap!(item), child: chip);
  }
}

/// A rendered chip plus its measured width, for the wrap layout.
class _ChipLayout {
  const _ChipLayout(this.child, this.label, this.name);

  final Component child;
  final String label;
  final String name;

  /// Columns this chip occupies: both plates and their side padding. The two
  /// plates sit adjacent, with no column between them.
  int get width => _columns(label) + 2 + _columns(name) + 2;
}

int _columns(String text) {
  var width = 0;
  for (final grapheme in text.characters) {
    width += TextViewportMixin.terminalColumnWidth(grapheme);
  }
  return width;
}
