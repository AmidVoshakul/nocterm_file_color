A Nocterm `TextField` wrapper that displays attached files and colored tokens
inline in the input line.

![A composer prompt with colored inline tokens: a pasted file and an agent
mention shown as colored tags, plus the agent and model line below the
input](https://raw.githubusercontent.com/AmidVoshakul/nocterm_file_color/HEAD/screenshots/input.png)

![The same prompt with the @ mention menu open above it: files, folders, and
subagents listed with a keyboard-highlighted row](https://raw.githubusercontent.com/AmidVoshakul/nocterm_file_color/HEAD/screenshots/input-menu.png)

## Features

- **Inline file attachments** – paste a path or attach programmatically;
  `[lib/main.dart]` and `[image 1]` labels are colored in place; Backspace
  removes a token and detaches the file as one unit.
- **Colored tokens** – `InlineToken` entries paint `@mentions`, `/commands`, or
  any substring; styles support colors, `bold`, `italic`, `underline`, and
  square, custom, or no brackets around the label.
- **Host-owned suggestion menus** – the application supplies `@` and `/`
  candidates (`FileTextFieldSuggestion.file`, `.folder`, `.agent`, `.command`);
  the field filters, selects, and inserts them.
- **Configurable suggestion menu** – `suggestionPageSize`, `suggestionCyclicScroll`, `suggestionScrollThreshold`, PgUp/PgDn/Home/End, mouse wheel, and matched substring highlighting.
- **Multiline input** – Ctrl+Enter / Shift+Enter / Alt+Enter / Ctrl+J insert newlines in multiline fields, even with the suggestion menu open.
- **Optional `/` anchor** – `slashAnchor: SlashAnchor.startOnly` restricts the
  slash menu to the very start of the field; the default opens it at any word
  boundary.
- **Token components** – `TokenHighlightTextField` for editable input and
  `TokenText` for read-only previews.

## Getting Started

```yaml
dependencies:
  nocterm: ^0.9.0
  nocterm_file_color: ^0.0.3
```

## Usage

File and token suggestions belong to the host application. Supply them through
`onSuggestionsRequested`; the field handles filtering, keyboard and mouse
selection, and colored inline rendering.

```dart
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';

final input = FileTextField(
  onSuggestionsRequested: (trigger, query) {
    if (trigger == '/') {
      return [const FileTextFieldSuggestion.command(name: 'help')];
    }
    return const [FileTextFieldSuggestion.agent(name: 'explore')];
  },
  onSuggestionSelected: (suggestion) {
    // The host decides what a command or agent should do.
  },
  onFilesChanged: (files) {
    // Attached files, ready to send to your model.
  },
);
```

Agents, folders, and commands need no `style`: each kind falls back to a
default token color, and `FileStyle` overrides it where you want:

```dart
FileTextFieldSuggestion.agent(name: 'explore')                     // default cyan
FileTextFieldSuggestion.agent(
  name: 'explore',
  style: FileStyle(text: Colors.brightCyan, openingDelimiter: ''),
)
```

Files take their colors from a `FileConfig`, exactly like attachments:

```dart
final config = FileConfig.defaultConfig();
FileTextFieldSuggestion.file(file, style: config.styleFor(file));
```

## Coloring tokens

Beyond files, arbitrary strings are colored by `InlineToken` entries. Each
entry colors one occurrence of its token string (the leftmost match not yet
colored), so register one entry per inserted label.

```dart
const tokens = [
  InlineToken(
    token: '@explore',
    style: FileStyle(text: Colors.brightCyan, openingDelimiter: ''),
  ),
  InlineToken(
    token: '/help',
    style: FileStyle(text: Colors.brightMagenta, openingDelimiter: ''),
  ),
];

// Editable input with colored tokens.
TokenHighlightTextField(controller: controller, tokens: tokens);

// Read-only preview for transcripts and lists.
TokenText(text: 'Run @explore or /help', tokens: tokens);
```

Token styles accept foreground and background colors, `bold`, `italic`, and
`underline`. Delimiters wrap the token label; the default is `[` and `]`, any
other string works, and empty strings render the bare token text:

```dart
FileStyle()                                              // → [lib/main.dart]
FileStyle(openingDelimiter: '<', closingDelimiter: '>')  // → <lib/main.dart>
FileStyle(openingDelimiter: '', closingDelimiter: '')    // →  lib/main.dart
```

## Suggestions

- `FileTextFieldSuggestion.file` inserts a colored token and registers an
  attachment, retrievable via `getAttachedFiles()`; `.folder`, `.agent`, and
  `.command` insert app-specific tokens only.
- Clicking a colored file token reports `onFileClick`, or opens the file
  location in the platform file manager by default.
- The provider receives `@` or `/` plus the query; the field filters the
  returned candidates case-insensitively by `name` and `searchText`.
- `FileStyle` colors the inserted token; menu labels render neutrally unless
  a `suggestionMenuBuilder` provides a custom menu component.
- `onSuggestionSelected` reports the selection to the host; the package never
  executes agents or commands.

### Rendering the menu yourself

By default `FileTextField` paints a neutral menu directly above the input.
Replace it in place with `suggestionMenuBuilder`, or drop it entirely with
`SuggestionMenuPlacement.host` and draw it wherever your layout needs — for
instance as a separate panel above your own prompt container.

```dart
class _MyComposerState extends State<MyComposer> {
  final fieldKey = GlobalKey<FileTextFieldState>();
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final menu = fieldKey.currentState?.visibleSuggestions ?? const [];
    final selected = fieldKey.currentState?.selectedSuggestionIndex ?? -1;

    return Column(
      children: [
        // Only rendered while the menu is open.
        if (menu.isNotEmpty)
          MyMenu(
            rows: menu,
            highlighted: selected,
            onPick: (row) => fieldKey.currentState!.selectSuggestion(row),
          ),
        FileTextField(
          key: fieldKey,
          controller: controller,
          focused: true,
          onSuggestionsRequested: (trigger, query) => myCandidates(trigger),
          // The field stops painting its own menu; trigger detection,
          // filtering and keyboard navigation stay inside it either way.
          suggestionMenuPlacement: SuggestionMenuPlacement.host,
          // Rebuilds this widget so the panel tracks the menu.
          onSuggestionMenuChanged: () => setState(() {}),
        ),
      ],
    );
  }
}
```

- `visibleSuggestions` — the candidates for the open menu, empty when closed.
- `selectedSuggestionIndex` — the highlighted row, `-1` when closed.
- `selectSuggestion(candidate)` — pick a row programmatically, e.g. on click.
- `onSuggestionMenuChanged` — fires when the menu opens/closes, its query
  changes, or the highlight moves. Arrow keys move the highlight without
  editing text, so `onChanged` alone is not enough.

Trigger detection, filtering, keyboard navigation and token insertion stay
inside the package either way. See `example/` for a full implementation.

## Default file colors

| Type | Color |
|------|-------|
| Image | Magenta |
| Document | Blue |
| Code | Green |
| Archive | Yellow |
| Audio / Video | Cyan |
| Other | Grey |

Tune defaults per type and overrides per extension with `FileConfig`.

## Example

See `example/nocterm_file_color_example.dart` for a complete runnable demo.

## License

MIT
