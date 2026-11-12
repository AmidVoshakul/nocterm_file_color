## 0.0.7

### Features

- **`FileChips`**: read-only chips row for attached files, as used at the end of a chat message — a colored `File`/`dir` label plate (from `FileConfig` or the theme) followed by a gray name plate (theme `surface`/`onSurface`), wrapped onto rows (or a single scrolling row). Per-item style override, `labelBuilder`, `nameTextColor`/`nameBackgroundColor`, `gap` and `onChipTap`; all colors honor `NO_COLOR`. `FileChipItem.file(...)`/`.directory(...)` build the items.
- **Prompt history**: `FileTextField` stores submitted prompts and recalls them with ArrowUp/ArrowDown (readline edge-stepping: cursor snaps to the line edge first, then history; draft save/restore, including an empty draft; consecutive dedup; capacity cap). Attached files are carried with each entry, so recalling — and moving up or down between — entries restores their file tags and re-sending keeps them. In-memory by default, injectable `PromptHistoryStorage` (with a ready `FilePromptHistoryStorage` + `PromptHistoryCodec` JSONL) for persistence. `TokenHighlightTextField` stays coloring-only but the controller is exported for reuse.

### Fixes

- The collapsed `[Pasted ~N lines]` tag now uses dark text on its background like every other tag, instead of white on grey.

## 0.0.6

### Features

- **Growing input**: `FileTextField` and `TokenHighlightTextField` grow with their content up to `maxLinesVisible` rows (8 by default) and scroll beyond that, keeping the caret in view — a composer that never grows without bound and breaks the layout. The text itself is never capped, the wheel and the arrow keys share one scroll logic where the caret leads and the view follows (the boundary arrows acting as Home and End), and an explicit `height` still governs the box.
- **`FileSystemCache`**: LRU memory with a TTL for directory listings, so a menu that rebuilds on every keystroke lists a directory once instead of once per character. A non-positive `maxEntries` or a negative `ttl` is rejected instead of silently disabling the cache. The source is injectable, and `batches(dir)` walks a tree depth first as a stream, visiting every directory once by its resolved path so a symlink cycle terminates.
- **`FileTextFieldState.attachFiles(List<FileInfo>)`** and **`attachFilePaths(List<String>)`**: attach a batch in one rebuild, so a folder of files costs a single repaint and a single `onFilesChanged`. An empty batch is a no-op.
- **`NO_COLOR`**: `TerminalColors` honours the environment variable — when it is present and non-empty, every colour the package emits stops: file and token tags, the suggestion menu, and the caret and selection the inline overlays draw, all fall back to the terminal defaults, while Nocterm's own colours belong to the framework and stay. Overridable through `TerminalColors.setNoColorOverride`, and colors can be probed with `TerminalColors.resolve`.

### Fixes

- Pasting several paths at once now attaches them in a single rebuild with a single `onFilesChanged` notification, instead of one notification per file.

### Breaking

- `SuggestionMenuStyle` colour fields (`selectedBackgroundColor`,
  `selectedTextColor`, `itemTextColor`) are now `Color?`. Assignments that
  require a non-nullable `Color` need a non-null assertion or a fallback;
  the defaults are unchanged.

### Refactor

- `SuggestionMenuStyle` colours are nullable, which lets `resolve()` drop every colour at once. `NO_COLOR` clears colours and the gray border, while padding and the highlight marker keep their configured values; Nocterm's own caret and selection colours belong to the framework and stay.

## 0.0.5

### Features
- Added new suggestion kind `FileTextFieldSuggestionKind.session` with factory `FileTextFieldSuggestion.session`.
- Sessions are inserted as a colored inline token `@session <name>` and can be selected from the `@`/`/` menu.
- Session prefix is configurable via `prefix` parameter, allowing `@session <name>`, `@<name>` or plain `<name>` with custom colors and delimiters via `FileStyle`.
- **Sectioned suggestion menu**: `SuggestionMenuGrouping` (and `SuggestionMenuGroup`) order, rename and merge the sections — the package hardcodes no layout. `Files & folders`, `Agents`, `Sessions`, `Commands` by default; the file/folder section drops its heading while browsing a directory, where the breadcrumb already carries it. Headings draw only when more than one section is present. Host-rendered menus get `visibleSuggestionGroups` to render the same headings, and `SuggestionMenuStyle.groupHeaderTextColor` / `.groupHeaderBackgroundColor` color them.
- **Folder navigation in the suggestion menu**: `path` on a suggestion marks it as a tree node, `RightArrow` drops into the highlighted folder and `LeftArrow` leaves it. The caret stays put while the menu is open. Breadcrumb and state are available through `navigationDepth`, `canNavigateBack` and `currentBasePath`; the demo scans its working directory and shows a breadcrumb.

### Fixes
- Inline token tap now uses anchored `start/end`, correctly handling duplicate labels.
- Entering a folder now clears the typed query from the field, so a pick inside the folder inserts just the token.
- Typing `@` or `/` in the middle of text no longer eats the character after the caret, and a range selection is replaced by the trigger exactly as typing would — both inherited from 0.0.4.
- The menu query now honors `maxLength`; previously the query and inserted tokens bypassed it.
- `FileOpener`: the Windows command quotes the path (a comma ended it early), and a non-zero exit code now raises instead of silently doing nothing.
- The directory-child filter matches on a path boundary, so a sibling such as `library.txt` is no longer listed as a child of `lib`.
- Removed the duplicated arrow-key handler in the suggestion menu.
- `getExpandedText` is now pure — does not mutate state or call `_anchorTokens`.
- Emulated cursors match Nocterm's own field cursor: block and block-outline are dark glyphs over the caret color, underline falls back to white when the style sets no color. `blockOutline` no longer renders as an underline.
- `FileOpener.buildLocationCommand` rejects real NUL bytes — `'\0'` in Dart is the digit `0`, which had made every path containing a zero fail.

### Refactor
- Extracted `CursorBlinkMixin` to unify cursor blinking in `FileTextField` and `TokenHighlightTextField`.
- Added additional lints to `analysis_options.yaml`.

## 0.0.4

### Features

- **Paste collapse**: large pastes (3+ lines, or 150+ characters) are shown as a `[Pasted ~N lines]` tag, expanded automatically on submit; removable as one unit. Line count and length are measured on the trimmed text, and the collapsed text is stored trimmed — the tag supplies its own separators. Thresholds match opencode's `[Pasted ~N lines]` behaviour and are configurable via `enablePasteCollapse`, `pasteCollapseMinLines` (default 3), `pasteCollapseMinChars` (default 150), `pasteStyle`.
- Pasted paths are no longer guessed from prose: a line counts as a pasted path only when every token on it is path-shaped (carries a separator or an extension). A paragraph that merely mentions `/commands` or `[lib/main.dart]` collapses into one paste tag instead of shredding into attachments.
- Collapsed pastes are anchored to the text range they occupy (extmark-style) rather than to their label, so identical paste labels keep their own spans and expand to their own content.
- Token removal keeps the separator the user typed: a tag carries its own trailing separator, and removing a tag consumes only that one instead of reaching back for the space before it.

## 0.0.3

### Features

- **Multiline breaks**: Ctrl+Enter / Shift+Enter / Alt+Enter / Ctrl+J insert a newline in multiline fields instead of submitting, including while the suggestion menu is open.
- **Suggestion menu styling**: new `SuggestionMenuStyle` configures background, border (any sides or none), selected/item/description colors, padding, and the highlight marker (default none), for the built-in menu.
- **Suggestion menu pagination and navigation**: configurable `suggestionPageSize` (default 8), `suggestionCyclicScroll` (default true), and `suggestionScrollThreshold` (default 1). Adds PgUp/PgDn/Home/End, mouse wheel scrolling, matched substring highlighting, and public API `suggestionScrollOffset`, `suggestionPageSize`, `moveSuggestionHighlight`.

### Fixes

- **Default tag colors**: `FileConfig.defaultConfig()` now uses black text on colored backgrounds for consistent rendering of pasted and menu-inserted tags.
- **Image label counter**: reuses freed numbers to avoid gaps.
- **Cursor blink**: restored in overlay mode with Timer-based emulation matching Nocterm.
- **Suggestion menu reopen**: menu repopulates when a previously empty query matches again.
- **Modified-Enter selection**: modified Enter now replaces a non-collapsed selection like native editing.
- **Example app exit**: `_quit()` restores stdin modes before shutdown to fix echo bug.

### Refactor

- Removed duplicated newline-insertion logic; text editing now relies on Nocterm.

### Examples

- Host menu example now paginates to `pageSize` and forwards mouse wheel events.

## 0.0.2

### Fixes

- **`FileConfig.hashCode`**: equal configurations could hash differently because `MapEntry` implements `==` but not `hashCode`, so the entries hashed by object identity. Configs are now equal and identically hashed regardless of map insertion order, which matters when a `FileConfig` is used as a map key or stored in a set.
- **Pasting several paths**: `/tmp/a.txt /tmp/b.txt` was attached as a single broken file named `b.txt`, even though the behavior was documented as space-separated. Lines are now split on spaces when every token ends in a file extension, so a path that legitimately contains a space (`/home/user/My Docs/notes.txt`) still stays whole.

### Features

- **Host-rendered suggestion menu**: `FileTextFieldState` exposes `visibleSuggestions`, `selectedSuggestionIndex` and `isSuggestionMenuOpen`, plus a `selectSuggestion` method, so an application can draw the `@`/`/` menu anywhere in its layout instead of only inside the field. Set `SuggestionMenuPlacement.host` to switch off the in-place menu.
- **Suggestion menu notifications**: `onSuggestionMenuChanged` fires when the menu opens or closes, its query changes, or the highlighted row moves — arrow-key navigation moves the highlight without editing the text, so `onChanged` alone was not enough to keep an external menu in sync.
- **Suggestion styles are optional**: `FileTextFieldSuggestion.agent`, `.folder`, and `.command` fall back to a per-kind default token color, so `agent(name: 'explore')` needs no `FileStyle`. Override with `style` where you want; `FileTextFieldSuggestion.defaultAgentStyle` and friends expose the defaults.
- **Token components**: `TokenHighlightTextField` and `TokenText` color arbitrary strings — `@mentions`, `/commands`, or any token — inline; each `InlineToken` entry colors one occurrence of its token string.
- **FileStyle**: new `italic` and `underline` options next to `bold`.
- **slashAnchor**: `FileTextField` accepts `SlashAnchor.startOnly` to open the `/` menu only at the very start of the field text; the default (`SlashAnchor.anywhere`) preserves 0.0.1 behavior.
- **Shared rendering**: the inline span machinery is now shared between `FileTextField` and the new token components; `FileTextField` behavior is unchanged.

### Examples

- `example/` rewritten as a focused chat-composer demo: an agent/model line inside the prompt, the mention menu floated above it as its own panel, and `Tab` cycling agents. Dropped ~230 lines of text-layout mirroring that existed only to size the field — Nocterm's `TextField` already grows with its content.

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