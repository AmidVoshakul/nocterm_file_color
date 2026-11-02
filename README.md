# **Nocterm File Color** - A Nocterm `TextField` wrapper that displays attached files and colored tokens inline in the input line.

![A composer prompt with colored inline tokens: a pasted file and an agent
mention shown as colored tags, plus the agent and model line below the
input](https://raw.githubusercontent.com/AmidVoshakul/nocterm_file_color/HEAD/screenshots/input.png)

![The same prompt with the @ mention menu open above it: files, folders, and
subagents listed with a keyboard-highlighted row](https://raw.githubusercontent.com/AmidVoshakul/nocterm_file_color/HEAD/screenshots/input-menu.png)

The `FileTextField` wraps the standard `TextField` and keeps its plain-text
`TextEditingController` value. Paste or mention a file, folder, agent, command and it becomes a
colored tag (`[lib/main.dart]`, `[image 1]`, `[image 2]`, `[lib/]`, `@agent`, `/command`) you can click; a large paste collapses into a single
`[Pasted ~N lines]` tag that expands again when the message is sent; the `@`
and `/` menus are either drawn by the package or handed to your own layout.
Everything attached stays available through `getAttachedFiles()`.

## Getting Started

```yaml
dependencies:
  nocterm: ^0.9.0
  nocterm_file_color: ^0.0.4
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

## Pasting

Pastes of 3+ lines or 150+ characters collapse into a `[Pasted ~N lines]`
tag, which expands again when the message is submitted and deletes as one
unit. Off it, or retune it, with `enablePasteCollapse`,
`pasteCollapseMinLines`, `pasteCollapseMinChars` and `pasteStyle`; read what
back with `getPastedTexts()` or `getExpandedText()`.

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

### Rendering the menu yourself

By default `FileTextField` paints a neutral menu directly above the input.
Replace it in place with `suggestionMenuBuilder`, or drop it entirely with
`SuggestionMenuPlacement.host` and draw it wherever your layout needs — for
instance as a separate panel above your own prompt container.

```dart
class MyComposer extends StatefulComponent {
  const MyComposer({super.key});

  @override
  State<MyComposer> createState() => _MyComposerState();
}

class _MyComposerState extends State<MyComposer> {
  final fieldKey = GlobalKey<FileTextFieldState>();
  final controller = TextEditingController();

  @override
  Component build(BuildContext context) {
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
| **Image** | Magenta |
| **Document** | Blue |
| **Code** | Green |
| **Archive** | Yellow |
| **Audio** / Video | Cyan |
| **Other** | Grey |

Tune defaults per type and overrides per extension with `FileConfig`.

## Example

See `example/nocterm_file_color_example.dart` for a complete runnable demo.

## License

MIT
