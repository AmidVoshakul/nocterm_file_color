## 0.0.1

### Features

- `FileTextField`: wrap Nocterm's `TextField` with colored inline file tokens while retaining a plain-text `TextEditingController` value.
- File attachments: attach by pasted path or through the public state API; retrieve them with `getAttachedFiles()` and observe updates with `onFilesChanged`.
- File labels: render regular files by name (`[lib/main.dart]`) and images with a numbered label (`[image 1]`, `[image 2]`).
- Atomic token editing: insert attachments at the current selection with spacing; Backspace/Delete removes a touched token as one unit and detaches its file.
- Click handling: notify `onFileClick`, or reveal the file location with the platform file manager by default.

### Styling

- `FileConfig`: configure defaults by file type and overrides by extension.
- `FileStyle`: set foreground/background colors, bold text, image prefix, and opening/closing delimiters. Empty delimiters render labels without brackets.
- `FileTag`: reusable colored, clickable file label with helpers for building display labels and controller tokens.
- `FileDetector` and `FileInfo`: normalize file paths/extensions and classify files by extension as image, document, code, archive, audio, video, or other.

### Suggestions

- Application-provided `@` mention and `/` command candidates through `onSuggestionsRequested`; the package does not ship or execute a built-in catalog.
- Built-in case-insensitive filtering, keyboard navigation, Enter/Escape handling, and mouse selection.
- Suggestions can represent files, folders, agents, or commands. Selecting a file creates an attachment; other kinds insert app-owned inline tokens and are reported through `onSuggestionSelected`.
- `suggestionMenuBuilder`: replace the neutral default menu with an application-owned Nocterm component. Suggestion colors and delimiters apply to the inserted inline token, not the default menu.

### Platform Support

- `FileOpener`: reveal a file in Explorer on Windows, Finder on macOS, or the containing directory through `xdg-open` on Linux/Unix-like systems.
- Depend only on Nocterm's public component APIs; the package does not modify Nocterm internals or manage file lifecycles.

### Examples and Tests

- Runnable Nocterm example with mock file, folder, agent, and command suggestions.
- Render tests for inline colors, suggestion menus and selection, email input, slash-prefixed paths, spacing, and atomic token deletion.