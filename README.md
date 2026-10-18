# nocterm_file_color

A Nocterm TextField wrapper that displays attached files as colored inline tags.

## Features

- **Inline file attachments** – paste a file path or attach one programmatically
- **Color-coded tokens** – `[image 1]` and `[lib/main.dart]` are colored in place in the input line
- **Mention and command menu** – provide application-owned file, folder, agent, and command suggestions for `@` and `/`
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

File and special-token suggestions belong to the host application. Supply them
through `onSuggestionsRequested`; the field handles filtering, keyboard/mouse
selection, and colored inline rendering.

```dart
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';

final config = FileConfig.defaultConfig();

final fileTextField = FileTextField(
  fileConfig: config,
  onSuggestionsRequested: (trigger, query) {
    if (trigger == '/') {
      return [
        FileTextFieldSuggestion.command(
          name: 'help',
          style: const FileStyle(
            text: Colors.brightMagenta,
            background: Colors.magenta,
            openingDelimiter: '',
            closingDelimiter: '',
          ),
        ),
      ];
    }
    return [
      FileTextFieldSuggestion.agent(
        name: 'explore',
        style: const FileStyle(text: Colors.brightCyan),
      ),
    ];
  },
  onSuggestionSelected: (suggestion) {
    // The host application decides what an agent or command should do.
  },
  suggestionMenuBuilder: (context, suggestions, selectedIndex, onSelected) {
    // Optionally return any Nocterm component for a custom menu.
    return Column(
      children: [
        for (final suggestion in suggestions)
          GestureDetector(
            onTap: () => onSelected(suggestion),
            child: Text(suggestion.displayLabel),
          ),
      ],
    );
  },
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
The demo suggestion catalog is local mock data; it does not scan the filesystem
or execute agents and commands.

### Suggestion items

- Use `FileTextFieldSuggestion.file(file, style: ...)` for an actual attachment.
  Selecting it inserts the colored token and adds the file to `getAttachedFiles()`.
- Use `.folder(...)`, `.agent(...)`, or `.command(...)` for app-specific tokens.
  These are inserted into the text but are not treated as file attachments.
- `FileStyle.text`, `background`, `openingDelimiter`, and `closingDelimiter`
  configure the inline token only. Empty delimiters omit the default brackets;
  suggestion menu labels are rendered neutrally by the package.
- The provider receives `@` or `/` and the current query. It may return the full
  candidate list; the field applies a case-insensitive filter using each item's
  `name` and optional `searchText`.
- `onSuggestionSelected` reports the selected item to the host. It does not
  execute an agent or command.
- By default, suggestion labels are plain, uncolored text. Provide
  `suggestionMenuBuilder` to fully customize the menu component; token styles
  still affect only the selected inline token.

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
