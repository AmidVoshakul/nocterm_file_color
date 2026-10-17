# nocterm_file_color

A Nocterm TextField wrapper that displays attached files as colored inline tags.

## Features

- **Inline file attachments** – attach files via paste, `@`-mention, drag & drop, or manual path input
- **Color-coded tags** – files are shown as `[image 1]`, `[image 2]`, `[lib/main.dart]`, etc.
- **Cross-platform** – works on Windows, macOS, and Linux
- **Lightweight** – only depends on Nocterm's public APIs

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  nocterm: ^0.9.0
  nocterm_file_color: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Usage

```dart
final config = FileConfig.defaultConfig();

final fileTextField = FileTextField(
  fileConfig: config,
  onFileClick: (file) {
    // Default: open file location in OS file manager
    FileOpener.openLocation(file.path);
  },
  onFilesChanged: (files) {
    // Handle file attachment changes
  },
);
```

## Example

See `example/nocterm_file_color_example.dart` for a complete runnable example.

## Architecture

This package is a **wrapper** around Nocterm's `TextField`:
- Does **not** modify Nocterm internals
- Provides file attachment UI (tags) without interfering with text editing
- Fully compatible with Nocterm updates (depends only on stable public API)

## File Types & Colors

| Type | Text Color | Background |
|------|------------|------------|
| Image | Magenta | Magenta |
| Document | Blue | Blue |
| Code | Green | Green |
| Archive | Yellow | Yellow |
| Audio/Video | Cyan | Cyan |
| Other | Grey | Grey |

## Integration

1. Add `nocterm_file_color` as a dependency
2. Configure `FileConfig` for custom colors if needed
3. Register `onFileClick` and `onFilesChanged` callbacks

## License

MIT
