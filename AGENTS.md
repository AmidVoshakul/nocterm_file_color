# nocterm_file_color - guide for AI agents

## About the project
A wrapper package for `TextField` from the **Nocterm** framework (TUI, similar to Flutter for the terminal). Allows you to insert external files into the input field and display them as **colored inline marks** (`[image 1]`, `[lib/main.dart]`, `[/home/user/Develop/RustroverProjects/todo/src/main.rs]`), visually separating attachments from plain text. Attached files must be available for transfer to the context of the AI ​​model (chat script).

## Architecture
The approach is a **widget wrapper `FileTextField`** (NOT a fork of Nocterm). Wraps the standard `TextField`, intercepts insert/key/drag events and inserts colored `FileTag` tags in their place.

**hard rule:** the package depends ONLY on the stable public Nocterm APIs (`TextField`, `TextStyle`, `Color`, `RichText`, `TextSpan`, `InlineSpan`). Nocterm updates should not break the package. Don't mess with the insides of the Nocterm core.

**Important:** Nocterm 0.9.0's `TextField` does NOT support inline styles. To display colored inline tags (e.g. `[image 1]`) as colored emoji-like icons within the input field, the package uses `RichText` alongside `TextField` for visual rendering. This is a **new component** approach — not a fork of Nocterm.

### Components
- `FileTextField` — wrapper over `TextField`; accepts parameters `TextField` + `fileConfig`, `slashAnchor` (`SlashAnchor.anywhere`/`startOnly`, where the `/` menu may open), `onFileClick`, `onFilesChanged`, `promptHistory`, `promptHistoryFilter`; method `getAttachedFiles()`. Grows with its content up to `maxLinesVisible` rows (default 8) and scrolls beyond that with caret-following; an explicit `height` governs the box instead. Optional readline-style prompt history (ArrowUp/ArrowDown recall, draft save/restore, consecutive dedup, capacity cap) via an injectable `PromptHistoryController` (in-memory by default; `FilePromptHistoryStorage` for persistence).
- `TokenHighlightTextField` — coloring-only wrapper over `TextField`; colors every occurrence of each `InlineToken` inline (transparent field + `RichText` overlay with selection/cursor emulation); no attachments, no menus, no paste; `onChanged` fires exactly once per controller change (inner field contract). Same grow-then-scroll viewport as `FileTextField`.
- `TokenText` — stateless read-only rendering of a `String` with colored `InlineToken`s (preview lines, lists).
- `InlineToken` — immutable `{token, FileStyle}` record with `==`/`hashCode`.
- `FileTag` - color tag `[type name]`, clickable.
- `FileConfig` - extension map → `FileStyle` (flexible color settings).
- `FileStyle` - `text` (text color), `background` (background color), `prefix` (eg `image`, `document`), plus font knobs `bold`, `italic`, `underline`.
- `FileDetector` - determining the file type by extension → `detectType(extension)`.
- `FileInfo` - model: `path`, `name`, `extension`, `type`, `size`.
- `FileOpener` - cross-platform opening of a file location in the OS (`xdg-open`/`open`/`explorer`).
- `FileChips` — read-only attachment chips for chat messages (colored label plate + gray name plate), with `FileChipItem.file`/`.directory`, `FileConfig`/theme colors and `NO_COLOR` support.
- `FileSystemCache` - LRU+TTL directory listings with a batched tree walk.
- `SkillInfo` / `CommandInfo` / `AgentInfo` - prompt-asset models (`SKILL.md`, command and agent `*.md`): `name`, `description`, `body`, `path` (+`directory`, `disableModelInvocation` for skills); `toSuggestion()` maps each onto its menu kind; `expandSkillTokens(text, skills)` / `expandCommandTokens(text, commands, {arguments})` substitute bodies (`$ARGUMENTS` for commands) before sending.
- `SkillIndex` / `CommandIndex` / `AgentIndex` - read-only discovery per family; the only defaults are the open `.agents/` standard (`.agents/skills`, `.agents/commands` — nested `sub/name.md` namespaces to `sub:name` —, `.agents/agents`) — every other root (`.claude/`, `.opencode/`, host-specific, global, plugin) is host policy passed via `extraRoots`; TTL cache; best-effort; `parser` injection point for full-YAML hosts — the indexes match Markdown files only, so TOML/MDC-style ecosystems are the host's own layer.
- `PromptIndex` - DX facade: one `load()` scans the `.agents/` defaults (+ per-family `extra*Roots`), `suggestionsFor(trigger)` feeds `@`/`/` menus, `expandTokens(text, {arguments, autoArguments})` expands picked command/skill tokens (auto mode feeds `$ARGUMENTS` from the trailing text; `trailingArguments` exposes it), `inlineTokensFor(text)` colors them for a transcript; call `FileTextFieldState.refreshSuggestions()` after the async `load()`; precedence = defaults → extras in order, first source wins; `SkillFrontmatter` is the shared zero-dep frontmatter parser (folded/literal/plain-multi-line blocks, quoted scalars, `when_to_use` appended to the summary, YAML 1.1 truthy `disable-model-invocation`), internals in `prompt_index_core.dart` (not exported).
- `TerminalColors` - `NO_COLOR` support shared by the package's colour output.

### State Management
- `getAttachedFiles(): List<FileInfo>` - current state (called before sending to the model).
- `onFilesChanged(List<FileInfo>)` — notifications about changes (adding/deleting/replacing).
- `onFileClick` - by default opens the file location in the OS (cross-platform), overridden.

### Suggestion menu placement
- `suggestionMenuBuilder` restyles the `@`/`/` menu inside `FileTextField`, above the input.
- To draw the menu elsewhere (e.g. a separate panel above your own prompt container), set `suggestionMenuPlacement: SuggestionMenuPlacement.host` and read `FileTextFieldState.visibleSuggestions` / `.selectedSuggestionIndex` via a `GlobalKey`; select rows with `.selectSuggestion(...)`.
- Keep an external menu in sync with `onSuggestionMenuChanged` (fires on open/close, query change and highlight move — arrow keys change the highlight without editing text, so `onChanged` is not enough). Mouse hover drives the same highlight through `highlightSuggestion(index)`, so a menu never shows two highlighted rows.

### Target file structure
```
lib/
  src/
    file_text_field.dart # widget wrapper over TextField
    file_system_cache.dart # LRU directory listings + batched tree walk
    terminal_colors.dart # NO_COLOR support for the package's colours
    prompt_history.dart # prompt history state, storage, controller, codec
    prompt_edge_step.dart # pure readline edge-stepping helpers
    file_chips.dart # read-only attachment chips for chat messages
    file_text_field_suggestion.dart # @/ menu model + kinds + defaults
    skill.dart # skill model (SKILL.md) + token expansion helper
    skill_index.dart # SKILL.md discovery + zero-dep frontmatter parser
    command.dart # command model + token expansion helper
    command_index.dart # slash-command discovery (*.md, nested ns:name)
    agent.dart # subagent model
    agent_index.dart # subagent discovery (*.md)
    prompt_index.dart # DX facade over skills + commands + agents
    prompt_index_core.dart # internal shared scanner + token expander (not exported)
    suggestion_menu_style.dart # style of the built-in menu
    cursor_blink_mixin.dart # shared caret blink for overlay fields
    text_viewport.dart # shared grow-then-scroll viewport for the fields
    token_highlight_text_field.dart # coloring-only wrapper over TextField
    token_text.dart # stateless read-only colored token text
    inline_token.dart # immutable {token, FileStyle}
    token_spans.dart # internal shared span renderer (not exported)
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
5. `TextField.onKeyEvent: bool Function(KeyboardEvent)?` - interception `@`, Ctrl+V.
6. Nocterm DOES NOT have built-in file/clipboard handling/MIME - it adds a package.
7. `TextField` has NO vertical scroll: `maxLines` is a hard cap that blocks newline input, and the field paints every row it lays out regardless of its own size. Vertical viewports are built from `SingleChildScrollView` + `ScrollController` (child laid out with `maxHeight: infinity`, metrics reported from the layout phase); `ClipRect` cuts the overflow.
8. The root of a Nocterm app is laid out with TIGHT terminal-sized constraints, and `BoxConstraints.enforce` uses `clamp` — a smaller `maxHeight` given above the root is clamped UP to the terminal height. Height caps must be applied below a `Stack` (or other `loosen()` boundary), never at the root level.
9. A `TextField` wraps at the width its CONSTRAINTS give it (minus one column reserved for the caret), not at its `width` parameter; `width` only drives the single-line horizontal scroll window. The overlay and the field must therefore be given the same width by an explicit box.
10. `Transform` is a pass-through stub in 0.9.0; the public bridge into a `RichText` render object's layout (`BuildContext.renderObject`, `RenderParagraph.selectableLayout`) works, but neither type is exported — reach it dynamically. Terminal wheel events never reach a scroll view nested under a text field: the field's own mouse annotation swallows them; wrap the input in a `MouseRegion` to handle wheels.

## Design Rules
- The file type is determined **by extension only** (`.png`, `.pdf`, `.txt`, etc.).
- In the label we show **only the name**: `[image 1]`, `[image 2]` for inserted images, `[lib/main.dart]`, `[/home/user/Develop/RustroverProjects/todo/src/main.rs]` for @-mentions.
- Clicking on the default label opens the file location in the OS; overridden via `onFileClick`.
- Colors are configured per-type in the application code / config file (Nocterm palette + custom colors).
- File insertion triggers: copy-paste, @-menu, programmatic attach. Typed text is NOT parsed into attachments — the controller text is the single truth, and attachments are reconciled from it one way only (a deleted token detaches; a typed path attaches nothing). (Nocterm 0.9.0 has no public API for file drops from outside the terminal, so drag-and-drop is NOT supported.)
- The package does NOT manage the life cycle of files - the application does that; the package just displays the state and returns a list.

## Build and tests
```bash
dart pub get # install dependencies
dart analyze # static analysis
dart test # tests
dart format . # formatting
```
- Coverage: `dart test --coverage=coverage` then `dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib`

## Important constraints

- Core+layout line coverage must stay >=80%.