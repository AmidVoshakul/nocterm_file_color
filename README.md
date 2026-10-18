# nocterm_file_color

A Nocterm TextField wrapper that displays attached files as colored inline tags.

## Features

- **Inline file attachments** – paste a file path or attach one programmatically
- **Color-coded tokens** – `[image 1]` and `[lib/main.dart]` are colored in place in the input line
- **Cross-platform** – works on Windows, macOS, and Linux
- **Lightweight** – uses Nocterm's public APIs without modifying framework internals

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

This package wraps Nocterm's editable `TextField` and overlays `RichText` at the
same position to paint attachment tokens with per-file colors. The controller
continues to contain plain-text tokens, so normal editing and message submission
remain available. It uses only Nocterm's public APIs and does not modify Nocterm
internals.

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
