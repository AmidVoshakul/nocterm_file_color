# nocterm_file_color - guide for AI agents

## About the project
A wrapper package for `TextField` from the **Nocterm** framework (TUI, similar to Flutter for the terminal). Allows you to insert external files into the input field and display them as **colored inline marks** (`[image 1]`, `[lib/main.dart]`, `[/home/user/Develop/RustroverProjects/todo/src/main.rs]`), visually separating attachments from plain text. Attached files must be available for transfer to the context of the AI ​​model (chat script).

## Architecture
The approach is a **widget wrapper `FileTextField`** (NOT a fork of Nocterm). Wraps the standard `TextField`, intercepts insert/key/drag events and inserts colored `FileTag` tags in their place.

**hard rule:** the package depends ONLY on the stable public Nocterm APIs (`TextField`, `TextStyle`, `Color`, `RichText`, `TextSpan`, `InlineSpan`). Nocterm updates should not break the package. Don't mess with the insides of the Nocterm core.

**Important:** Nocterm 0.9.0's `TextField` does NOT support inline styles. To display colored inline tags (e.g. `[image 1]`) as colored emoji-like icons within the input field, the package uses `RichText` alongside `TextField` for visual rendering. This is a **new component** approach — not a fork of Nocterm.

### Components
- `FileTextField` — wrapper over `TextField`; accepts parameters `TextField` + `fileConfig`, `onFileClick`, `onFilesChanged`; method `getAttachedFiles()`.
- `FileTag` - color tag `[type name]`, clickable.
- `FileConfig` - extension map → `FileStyle` (flexible color settings).
- `FileStyle` - `text` (text color), `background` (background color), `prefix` (eg `image`, `document`).
- `FileDetector` - determining the file type by extension → `detectType(extension)`.
- `FileInfo` - model: `path`, `name`, `extension`, `type`, `size`.
- `FileOpener` - cross-platform opening of a file location in the OS (`xdg-open`/`open`/`explorer`).

### State Management
- `getAttachedFiles(): List<FileInfo>` - current state (called before sending to the model).
- `onFilesChanged(List<FileInfo>)` — notifications about changes (adding/deleting/replacing).
- `onFileClick` - by default opens the file location in the OS (cross-platform), overridden.

### Target file structure
```
lib/
  src/
    file_text_field.dart # widget wrapper over TextField
    file_tag.dart # color tag [type name]
    file_config.dart # configuration of colors by extensions
    file_detector.dart # type detection by extension
    file_info.dart # file data model
    file_opener.dart # open location in OS
  nocterm_file_color.dart # public API export
```

## Facts and limitations of Nocterm 0.9.0 (checked against sources)
1. `TextField` does NOT support inline styles: it uses `TextEditingController` with a regular `String`, colors all the text with one `TextStyle`.
2. `RichText` supports mixed styles via `TextSpan`/`InlineSpan`, but **for display only**, not for editing.
3. `TextStyle`: fields `color`, `backgroundColor`, `fontWeight`, `fontStyle`, `decoration`, `reverse`; method `toAnsi()`; built-in `Colors` palette; custom via `Color.fromRGB()`/`Color.fromARGB()`.
4. `TextField.onPaste: bool Function(String)?` - return `true` to intercept the paste yourself.
5. `TextField.onKeyEvent: bool Function(KeyboardEvent)?` - interception `@`, Ctrl+V, drag&drop.
6. Nocterm DOES NOT have built-in file/clipboard handling/MIME - it adds a package.

## Design Rules
- The file type is determined **by extension only** (`.png`, `.pdf`, `.txt`, etc.).
- In the label we show **only the name**: `[image 1]`, `[image 2]` for inserted images, `[lib/main.dart]`, `[/home/user/Develop/RustroverProjects/todo/src/main.rs]` for @-mentions.
- Clicking on the default label opens the file location in the OS; overridden via `onFileClick`.
- Colors are configured per-type in the application code / config file (Nocterm palette + custom colors).
- File insertion triggers: copy-paste, @-menu, drag-and-drop, attach button, manual path entry.
- The package does NOT manage the life cycle of files - the application does that; the package just displays the state and returns a list.

## Build and tests
```bash
dart pub get # install dependencies
dart analyze # static analysis 
dart test # tests
dart format . # formatting
```