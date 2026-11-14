import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';

void main() {
  runApp(const ComposerDemo());
}

/// Demo of a chat composer in the style of a terminal AI client: a prompt
/// pinned to the bottom of the window with an agent/model line inside it, and
/// an `@`/`/` mention menu floated above it as its own panel.
///
/// Three pieces of the package are exercised here: colored inline file tokens,
/// the `@`/`/` suggestion menu, and rendering that menu outside of the widget.
///
/// The menu is drawn by this demo rather than inside [FileTextField]: the widget
/// keeps owning trigger detection, filtering, keyboard navigation and token
/// insertion, while the demo reads [FileTextFieldState.visibleSuggestions] and
/// [FileTextFieldState.selectedSuggestionIndex] through a [GlobalKey] and paints
/// the panel wherever its layout needs it.
class ComposerDemo extends StatefulComponent {
  const ComposerDemo({super.key, this.onQuit = shutdownApp});

  /// Called when the user quits with a bare Escape or Ctrl+C.
  ///
  /// Defaults to Nocterm's [shutdownApp] rather than `exit(0)`: the latter
  /// skips terminal cleanup and leaves the cursor, mouse tracking and the
  /// alternate screen broken. It needs a live [TerminalBinding], so tests
  /// inject their own callback.
  final VoidCallback onQuit;

  @override
  State<ComposerDemo> createState() => _ComposerDemoState();
}

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.chips,
    required this.agentIndex,
  });

  final String text;
  final List<FileChipItem> chips;
  final int agentIndex;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ComposerDemoState extends State<ComposerDemo> {
  // -- Palette --------------------------------------------------------------

  static final _windowColor = const Color.fromRGB(3, 3, 4);
  static final _menuColor = const Color.fromRGB(34, 35, 36);
  static final _promptColor = const Color.fromRGB(34, 35, 36);
  static final _messageCardColor = const Color.fromRGB(21, 22, 23);
  static final _hoverColor = const Color.fromRGB(46, 46, 52);
  static final _borderColor = const Color.fromRGB(46, 46, 50);
  static final _dimColor = const Color.fromRGB(98, 104, 117);
  static final _textColor = const Color.fromRGB(200, 200, 204);
  static final _variantColor = const Color.fromRGB(230, 199, 106);

  // -- Input ----------------------------------------------------------------

  final _controller = TextEditingController();

  /// Entered prompts are recalled with ArrowUp/ArrowDown; the field owns an
  /// in-memory history by default, but a shared controller lets the host
  /// persist it if it wants to.
  final _promptHistory = PromptHistoryController();

  /// Directory listings live here: the provider runs on every keystroke, so
  /// each directory is listed once and reused within the TTL.
  final _directoryCache = FileSystemCache();

  /// Reaches the menu state the demo renders itself; see [_buildMenuPanel].
  final _fieldKey = GlobalKey<FileTextFieldState>();

  /// Sent messages, rendered as cards above the composer.
  final List<_ChatMessage> _messages = [];

  /// Directories picked from the menu for the prompt being composed. The
  /// field inserts folders as inline tokens (not attachments), so the demo
  /// tracks them here to render directory chips in the sent message.
  final List<FileChipItem> _pickedFolders = [];

  /// Keeps the transcript pinned to the newest message.
  final _scrollController = AutoScrollController();

  // -- Agent ----------------------------------------------------------------

  static const _agents = ['Plan', 'Build', 'Ask'];

  /// Accent per agent, aligned with [_agents] by index. The prompt's left
  /// border, the agent name and the caret all take it, so switching agents
  /// recolors the whole prompt at once.
  static const _agentColors = [Colors.yellow, Colors.blue, Colors.green];

  int _agentIndex = 0;
  String get _currentAgent => _agents[_agentIndex];
  Color get _agentColor => _agentColors[_agentIndex];

  // -- Model shown on the agent line -----------------------------------------

  static const _modelName = 'Muse Glimmer 30B';
  static const _modelProvider = 'NVIDIA NIM';
  static const _variantLabel = 'max';

  // -- Lifecycle -------------------------------------------------------------

  @override
  void dispose() {
    _controller.dispose();
    _promptHistory.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -- Exit ------------------------------------------------------------------

  /// Restores the terminal line discipline, then quits via
  /// [ComposerDemo.onQuit].
  ///
  /// Nocterm cancels its stdin subscription before re-enabling the terminal
  /// modes, and dart:io refuses mode changes on a cancelled stdin
  /// (dart-lang/sdk#49961), so the shell is left with `-echo`. The modes must
  /// be restored here, while Nocterm still listens on stdin.
  void _quit() {
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {
      // Piped stdin, tests, or already-closed stdin; best effort.
    }
    component.onQuit();
  }

  // -- Suggestions provider ---------------------------------------------------

  /// Feeds the `@` and `/` menus. The field filters the result case
  /// insensitively on `name` and `searchText`; colors set here dress the
  /// inserted token, not the menu rows this demo paints itself.
  List<FileTextFieldSuggestion> _provideSuggestions(
    String trigger,
    String query,
  ) {
    final config = FileConfig.defaultConfig();
    final suggestions = <FileTextFieldSuggestion>[];

    if (trigger == '/') {
      const commandStyle = FileStyle(
        background: Colors.magenta,
        bold: true,
        openingDelimiter: '',
        closingDelimiter: '',
      );
      suggestions.addAll(const [
        FileTextFieldSuggestion.command(name: 'init', style: commandStyle),
        FileTextFieldSuggestion.command(name: 'review', style: commandStyle),
        FileTextFieldSuggestion.command(name: 'compact', style: commandStyle),
        FileTextFieldSuggestion.command(name: 'help', style: commandStyle),
        FileTextFieldSuggestion.command(name: 'clear', style: commandStyle),
        FileTextFieldSuggestion.command(name: 'model', style: commandStyle),
      ]);
    } else {
      try {
        final state = _fieldKey.currentState;
        final basePath = state?.currentBasePath;
        final root = Directory.current;
        final targetDir = basePath == null || basePath.isEmpty
            ? root
            : Directory('${root.path}${Platform.pathSeparator}$basePath');
        if (!targetDir.existsSync()) return suggestions;
        const folderStyle = FileStyle(background: Colors.yellow, bold: true);
        for (final entity in _directoryCache.children(targetDir)) {
          final relPath = entity.path
              .replaceFirst(root.path + Platform.pathSeparator, '')
              .replaceAll(Platform.pathSeparator, '/');
          final baseName = entity.path.split(Platform.pathSeparator).last;
          if (entity is Directory) {
            suggestions.add(
              FileTextFieldSuggestion.folder(
                name: '$baseName/',
                style: folderStyle,
                path: relPath,
                searchText: '$baseName folder',
              ),
            );
          } else if (entity is File) {
            final fileInfo = FileInfo.fromPath(relPath);
            suggestions.add(
              FileTextFieldSuggestion.file(
                fileInfo,
                style: config.styleFor(fileInfo),
                searchText: '${fileInfo.name} file',
                path: relPath,
              ),
            );
          }
        }
      } catch (_) {}

      const agentStyle = FileStyle(
        background: Colors.cyan,
        bold: true,
        openingDelimiter: '',
        closingDelimiter: '',
      );
      const sessionStyle = FileStyle(
        text: Colors.black,
        background: Colors.magenta,
        bold: true,
        openingDelimiter: '',
        closingDelimiter: '',
      );
      suggestions.addAll(const [
        FileTextFieldSuggestion.agent(name: 'explore', style: agentStyle),
        FileTextFieldSuggestion.agent(name: 'general', style: agentStyle),
        FileTextFieldSuggestion.agent(name: 'code-reviewer', style: agentStyle),
        FileTextFieldSuggestion.session(
          name: 'ses_kd4fk_kiu34_kj82jkahf3k2',
          style: sessionStyle,
        ),
        FileTextFieldSuggestion.session(
          name: 'ses_du43i_8duw8_87dsdsvd7sdd',
          style: sessionStyle,
          prefix: '@',
        ),
        FileTextFieldSuggestion.session(
          name: 'ses_hydsk_ie8ed_8hfd7wwk2ll2',
          style: sessionStyle,
          prefix: '',
        ),
      ]);
    }

    // No query filtering here: the field filters the result itself, so a
    // second filter in the host would be a second authority on the same rule.
    return suggestions;
  }

  // -- Mention menu -----------------------------------------------------------

  // Rendered as its own panel above the prompt instead of inside the field, so
  // the prompt keeps its bar. [FileTextFieldState] supplies the rows, the
  // highlighted index and programmatic selection.
  /// Breadcrumb of the directory the `@` menu is browsing, or `null` at the
  /// root. RightArrow drops into the highlighted folder, LeftArrow leaves it.
  String? _breadcrumb(FileTextFieldState? state) {
    if (state == null || !state.canNavigateBack) return null;
    final basePath = state.currentBasePath;
    if (basePath == null) return null;
    return '$basePath · ← back';
  }

  Component _buildMenuPanel() {
    final state = _fieldKey.currentState;
    final groups = state?.visibleSuggestionGroups ?? const [];
    final selectedIndex = state?.selectedSuggestionIndex ?? -1;
    if (groups.every((group) => group.items.isEmpty)) {
      return const SizedBox.shrink();
    }
    final breadcrumb = _breadcrumb(state);

    final pageSize = state?.suggestionPageSize ?? 8;
    final total = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    final offset = (state?.suggestionScrollOffset ?? 0).clamp(0, total);

    // Walk the package's own sections, numbering rows in the same flat order
    // the field highlights and pages by — the headings come from the groups,
    // not re-derived here.
    final rows = <Component>[];
    var flat = 0;
    for (final group in groups) {
      final groupStart = flat;
      flat += group.items.length;
      final groupEnd = flat;
      final inWindow = groupStart < offset + pageSize && groupEnd > offset;
      if (!inWindow) continue;
      if (group.title != null) {
        rows.add(Text(group.title!, style: TextStyle(color: _dimColor)));
      }
      for (var i = groupStart; i < groupEnd; i++) {
        if (i < offset || i >= offset + pageSize) continue;
        rows.add(
          _buildMenuRow(
            i,
            group.items[i - groupStart],
            highlighted: i == selectedIndex,
          ),
        );
      }
    }

    // A left-only border is what draws the panel's bar; Nocterm also reserves
    // one row above and below it, which is the spacing we want anyway.
    return MouseRegion(
      onHover: (event) {
        if (event.button == MouseButton.wheelUp) {
          state?.moveSuggestionHighlight(-1);
        } else if (event.button == MouseButton.wheelDown) {
          state?.moveSuggestionHighlight(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: _menuColor,
          border: BoxBorder(left: BorderSide(color: _borderColor, width: 1.0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (breadcrumb != null)
              Text(breadcrumb, style: TextStyle(color: _dimColor)),
            ...rows,
          ],
        ),
      ),
    );
  }

  Component _buildMenuRow(
    int index,
    FileTextFieldSuggestion suggestion, {
    required bool highlighted,
  }) {
    return MouseRegion(
      // Hover moves the one highlight the keyboard also drives, so the menu
      // never shows two highlighted rows.
      // Hover moves the one highlight the keyboard also drives, so the menu
      // never shows two highlighted rows.
      onEnter: (_) => _fieldKey.currentState?.highlightSuggestion(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _fieldKey.currentState?.selectSuggestion(suggestion),
        child: Container(
          color: highlighted ? _hoverColor : null,
          child: Row(
            children: [
              // Left: display label — up to 2 lines, then ellipsis. Wider column.
              Expanded(
                flex: 2,
                child: Text(
                  suggestion.displayLabel,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Right: the prompt asset's summary when it has one (commands,
              // skills, agents), its kind name otherwise — one line, then
              // ellipsis.
              Expanded(
                flex: 2,
                child: Text(
                  suggestion.description ?? suggestion.kind.name,
                  style: TextStyle(color: _dimColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Messages --------------------------------------------------------------

  // Sent messages render as cards with the agent's left border color; attached
  // files show as colored chips at the end of the message text.

  Component _buildMessageCard(_ChatMessage msg) {
    final borderColor = _agentColors[msg.agentIndex];
    return Container(
      decoration: BoxDecoration(
        color: _messageCardColor,
        border: BoxBorder(left: BorderSide(color: borderColor, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(msg.text, style: TextStyle(color: _textColor)),
          if (msg.chips.isNotEmpty) ...[
            const SizedBox(height: 1),
            // Chips come from the package: colored label plate + gray name
            // plate, wrapping onto rows; no hand-rolled styling in the demo.
            FileChips(items: msg.chips),
          ],
        ],
      ),
    );
  }

  // -- Prompt ----------------------------------------------------------------

  // Agent-colored left border, the input, and the agent line. `Tab` cycles the
  // agent, which recolors border, agent name and caret together.

  Component _buildPrompt() {
    return Container(
      decoration: BoxDecoration(
        color: _promptColor,
        border: BoxBorder(left: BorderSide(color: _agentColor, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.tab && !event.isShiftPressed) {
                setState(() {
                  _agentIndex = (_agentIndex + 1) % _agents.length;
                });
                return true;
              }
              if (event.logicalKey == LogicalKey.escape) {
                // While the mention menu is open, Escape belongs to the field:
                // it closes the menu. Only a bare Escape quits.
                if (_fieldKey.currentState?.isSuggestionMenuOpen ?? false) {
                  return false;
                }
                _quit();
                return true;
              }
              if (event.logicalKey == LogicalKey.keyC &&
                  event.isControlPressed) {
                // Nocterm's own Ctrl+C shutdown path is affected by the same
                // stdin-ordering issue, so quit here instead (see _quit).
                _quit();
                return true;
              }
              return false;
            },
            child: FileTextField(
              key: _fieldKey,
              controller: _controller,
              focused: true,
              // The composer grows with its input up to eight rows and
              // scrolls after that — the text itself is never capped.
              maxLines: null,
              maxLinesVisible: 8,
              promptHistory: _promptHistory,
              placeholder:
                  'Type a message with @ agent, files or sessions, / commands…',
              cursorColor: _agentColor,
              style: TextStyle(color: _textColor),
              cursorBlinkRate: const Duration(milliseconds: 500),
              onSuggestionsRequested: _provideSuggestions,
              onSuggestionSelected: (suggestion) {
                if (suggestion.kind == FileTextFieldSuggestionKind.folder) {
                  setState(() {
                    _pickedFolders.add(
                      FileChipItem.directory(suggestion.displayLabel),
                    );
                  });
                }
              },
              // The menu is drawn above the prompt by [_buildMenuPanel], so
              // the widget's own in-place menu is switched off here.
              suggestionMenuPlacement: SuggestionMenuPlacement.host,
              onSuggestionMenuChanged: () => setState(() {}),
              onFileClick: (file) => FileOpener.openLocation(file.path),
              // Sending clears the prompt, the way a chat composer would.
              onSubmitted: (text) {
                final files = List<FileInfo>.from(
                  _fieldKey.currentState?.getAttachedFiles() ?? const [],
                );
                final chips = [
                  for (final file in files) FileChipItem.file(file),
                  ..._pickedFolders,
                ];
                final agent = _agentIndex;
                // Clear the field (text + tokens + attachments) first; it
                // calls setState internally, so keep the message append
                // separate to avoid nesting setState.
                _fieldKey.currentState?.clearAttachments();
                setState(() {
                  _pickedFolders.clear();
                  _messages.add(
                    _ChatMessage(text: text, chips: chips, agentIndex: agent),
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 1),
          RichText(text: _buildAgentLine()),
        ],
      ),
    );
  }

  /// `Plan · Muse Glimmer 30B NVIDIA NIM · max`, one color per segment.
  TextSpan _buildAgentLine() {
    return TextSpan(
      children: [
        TextSpan(
          text: _currentAgent,
          style: TextStyle(color: _agentColor, fontWeight: FontWeight.bold),
        ),
        _dimSpan(' · '),
        TextSpan(
          text: _modelName,
          style: TextStyle(color: _textColor),
        ),
        _dimSpan(' $_modelProvider'),
        _dimSpan(' · '),
        TextSpan(
          text: _variantLabel,
          style: TextStyle(color: _variantColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // -- Key hints -------------------------------------------------------------

  /// `Tab switch agent · @ agents and files · / commands · Enter send · Esc
  /// exit`. Keys stay white, descriptions and separators grey.
  TextSpan _buildHintText() {
    const hints = [
      ('Tab', 'switch agent'),
      ('@', 'agents and files'),
      ('/', 'commands'),
      ('Enter', 'send'),
      ('Esc', 'exit'),
    ];
    return TextSpan(
      children: [
        for (var i = 0; i < hints.length; i++) ...[
          if (i > 0) _dimSpan(' · '),
          TextSpan(
            text: '${hints[i].$1} ',
            style: const TextStyle(color: Colors.white),
          ),
          _dimSpan(hints[i].$2),
        ],
      ],
    );
  }

  TextSpan _dimSpan(String text) => TextSpan(
    text: text,
    style: TextStyle(color: _dimColor),
  );

  // -- Layout ----------------------------------------------------------------

  @override
  Component build(BuildContext context) {
    return Container(
      color: _windowColor,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Demo nocterm_file_color · composer prompt',
            style: TextStyle(color: Colors.brightCyan),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final msg in _messages) ...[
                    _buildMessageCard(msg),
                    const SizedBox(height: 1),
                  ],
                  if (_messages.isEmpty)
                    Text(
                      'No messages yet — type below and press Enter.',
                      style: TextStyle(color: _dimColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1),
          _buildMenuPanel(),
          _buildPrompt(),
          const SizedBox(height: 1),
          RichText(text: _buildHintText()),
        ],
      ),
    );
  }
}
