import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => TerminalColors.setNoColorOverride(null));

  test('an environment without NO_COLOR keeps colors', () {
    expect(TerminalColors.enabledIn(const {}), isFalse);
    expect(TerminalColors.enabledIn(const {'NO_COLOR': ''}), isFalse);
    expect(TerminalColors.enabledIn(const {'NO_COLOR': '1'}), isTrue);
    expect(TerminalColors.enabledIn(const {'NO_COLOR': '0'}), isTrue);
  });

  test('the override wins over the environment', () {
    TerminalColors.setNoColorOverride(true);
    expect(TerminalColors.noColorEnabled, isTrue);
    expect(TerminalColors.resolve(Colors.red), isNull);

    TerminalColors.setNoColorOverride(false);
    expect(TerminalColors.noColorEnabled, isFalse);
    expect(TerminalColors.resolve(Colors.red), Colors.red);
  });

  test('a style drops its colors when colors are off', () {
    const style = FileStyle(
      text: Colors.brightCyan,
      background: Colors.cyan,
      bold: true,
    );

    final plain = style.toTextStyle();
    TerminalColors.setNoColorOverride(true);
    final monochrome = style.toTextStyle();

    expect(plain.color, Colors.brightCyan);
    expect(plain.backgroundColor, Colors.cyan);
    expect(monochrome.color, isNull);
    expect(monochrome.backgroundColor, isNull);
    // Non-color attributes are untouched.
    expect(monochrome.fontWeight, FontWeight.bold);
  });

  test('resolve keeps the layout a host configured', () {
    const style = SuggestionMenuStyle(
      padding: EdgeInsets.zero,
      highlightMarker: '>',
    );

    final monochrome = style.resolve();
    TerminalColors.setNoColorOverride(true);
    final dropped = style.resolve();

    expect(monochrome, style); // colors are on: nothing changes
    expect(dropped.padding, EdgeInsets.zero);
    expect(dropped.highlightMarker, '>');
  });

  test('copyWith forwards the header colours', () {
    const style = SuggestionMenuStyle();
    final changed = style.copyWith(
      groupHeaderTextColor: Colors.red,
      groupHeaderBackgroundColor: Colors.blue,
    );

    expect(changed.groupHeaderTextColor, Colors.red);
    expect(changed.groupHeaderBackgroundColor, Colors.blue);
  });

  test('equality and hashing cover the header colours', () {
    const style = SuggestionMenuStyle();
    final changed = style.copyWith(
      groupHeaderTextColor: Colors.red,
      groupHeaderBackgroundColor: Colors.blue,
    );

    expect(style == changed, isFalse);
    expect(style.hashCode, isNot(changed.hashCode));
  });

  test('the empty-state text honors the colour probe', () async {
    await testNocterm('monochrome empty state', (tester) async {
      final controller = TextEditingController();
      await tester.pumpComponent(
        FileTextField(
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
          onSuggestionsRequested: (trigger, query) => const [],
        ),
      );
      await tester.enterText('@');
      await tester.pump();
      expect(tester.terminalState, containsText('No matches'));

      TerminalColors.setNoColorOverride(true);
      await tester.enterText('x');
      await tester.pump();

      // The fallback gray must survive the probe, so the row is not colored.
      final rendered = tester.terminalState.getCellAt(0, 0);
      expect(rendered?.style.color, isNot(Colors.gray));
    });
  });

  test('a file tag renders without colors when colors are off', () async {
    await testNocterm('monochrome tag', (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      await tester.pumpComponent(
        FileTextField(
          key: key,
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
        ),
      );
      key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
      await tester.pump();

      final colored = tester.terminalState
          .getCellAt(0, 0)
          ?.style
          .backgroundColor;
      expect(colored, isNotNull);

      TerminalColors.setNoColorOverride(true);
      controller.text = '[main.dart] x';
      await tester.pump();
      expect(
        tester.terminalState.getCellAt(0, 0)?.style.backgroundColor,
        isNull,
        reason: 'NO_COLOR must leave the tag background unset',
      );
    });
  });

  test('the inline cursor drops its colors when colors are off', () async {
    await testNocterm('monochrome cursor', (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      await tester.pumpComponent(
        FileTextField(
          key: key,
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
        ),
      );
      key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
      await tester.pump();
      controller.text = '[main.dart] ab';
      // Caret on the plain text, where the cell has no background of its own.
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      // The emulated caret paints the cell with the caret color.
      expect(
        tester.terminalState.getCellAt(12, 0)?.style.backgroundColor,
        isNotNull,
      );
      expect(tester.terminalState.getCellAt(12, 0)?.style.color, Colors.black);

      TerminalColors.setNoColorOverride(true);
      // A text change rebuilds the overlay with the flag on; the caret is
      // placed back on the same cell, so what is observed is its fill under
      // NO_COLOR and not a plain cell the caret happened to leave.
      controller.text = '[main.dart] abc';
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      expect(
        tester.terminalState.getCellAt(12, 0)?.style.backgroundColor,
        isNull,
        reason: 'NO_COLOR must leave the caret fill unset',
      );
    });

    TerminalColors.setNoColorOverride(null);
  });

  test('a selection drops the overlay fill when colors are off', () async {
    await testNocterm('monochrome selection', (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      await tester.pumpComponent(
        FileTextField(
          key: key,
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
        ),
      );
      key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
      await tester.pump();
      controller.text = '[main.dart] ab';
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 5,
      );
      await tester.pump();

      final overlayFill = tester.terminalState
          .getCellAt(2, 0)
          ?.style
          .backgroundColor;
      expect(overlayFill, isNotNull, reason: 'the overlay fills the selection');

      TerminalColors.setNoColorOverride(true);
      // An extent move rebuilds the overlay with the flag on.
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 6,
      );
      await tester.pump();

      expect(
        tester.terminalState.getCellAt(2, 0)?.style.backgroundColor,
        isNot(overlayFill),
        reason: 'the overlay fill must not survive NO_COLOR',
      );
      expect(
        tester.terminalState.getCellAt(2, 0)?.style.backgroundColor,
        isNot(Colors.grey),
        reason: 'the grey fallback must not leak under NO_COLOR either',
      );
    });

    TerminalColors.setNoColorOverride(null);
  });

  test('a host selection color stops emitting under NO_COLOR', () async {
    await testNocterm('monochrome host selection', (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      await tester.pumpComponent(
        FileTextField(
          key: key,
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
          selectionColor: Colors.brightRed,
        ),
      );
      key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
      await tester.pump();
      controller.text = '[main.dart] ab';
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 5,
      );
      await tester.pump();

      expect(
        tester.terminalState.getCellAt(2, 0)?.style.backgroundColor,
        Colors.brightRed,
        reason: 'the host color paints while colors are on',
      );

      TerminalColors.setNoColorOverride(true);
      // An extent move rebuilds the overlay with the flag on.
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 6,
      );
      await tester.pump();

      expect(
        tester.terminalState.getCellAt(2, 0)?.style.backgroundColor,
        isNot(Colors.brightRed),
        reason:
            'a host-supplied selection color must not survive NO_COLOR — '
            'only Nocterm own default may remain',
      );
    });
  });

  test('the block caret stays visible without colors', () async {
    await testNocterm('monochrome block caret', (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FileTextFieldState>();
      await tester.pumpComponent(
        FileTextField(
          key: key,
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
        ),
      );
      key.currentState!.attachFile(FileInfo.fromPath('/tmp/main.dart'));
      await tester.pump();
      controller.text = '[main.dart] ab';
      // Caret on the plain text, where the cell has no background of its own.
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      expect(tester.terminalState.getCellAt(12, 0)?.style.reverse, isFalse);

      TerminalColors.setNoColorOverride(true);
      // A text change rebuilds the overlay with the flag on; the caret is
      // placed back on the same cell, so what is observed is its rendering
      // under NO_COLOR and not a plain cell the caret happened to leave.
      controller.text = '[main.dart] abc';
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      expect(
        tester.terminalState.getCellAt(12, 0)?.style.reverse,
        isTrue,
        reason: 'the caret must stay visible without emitting a colour',
      );
    });
  });

  test('the menu renders without colors when colors are off', () async {
    await testNocterm('monochrome menu', (tester) async {
      final controller = TextEditingController();
      await tester.pumpComponent(
        FileTextField(
          controller: controller,
          focused: true,
          width: 40,
          height: 1,
          suggestionMenuStyle: const SuggestionMenuStyle(
            selectedBackgroundColor: Colors.cyan,
          ),
          onSuggestionsRequested: (trigger, query) => [
            const FileTextFieldSuggestion.agent(name: 'explore'),
          ],
        ),
      );
      await tester.enterText('@');
      await tester.pump();

      Color? fill() {
        final state = tester.terminalState;
        for (var row = 0; row < 4; row++) {
          for (var col = 0; col < 40; col++) {
            final color = state.getCellAt(col, row)?.style.backgroundColor;
            if (color == Colors.cyan) return color;
          }
        }
        return null;
      }

      expect(fill(), Colors.cyan, reason: 'the highlighted row is filled');

      TerminalColors.setNoColorOverride(true);
      // A query change forces the menu to rebuild with the new flag.
      await tester.enterText('e');
      await tester.pump();
      expect(fill(), isNull);
    });
  });

  test('a menu style drops its colors when colors are off', () {
    const style = SuggestionMenuStyle(
      backgroundColor: Colors.black,
      selectedBackgroundColor: Colors.cyan,
      selectedTextColor: Colors.black,
      itemTextColor: Colors.white,
    );

    final colored = style.resolve();
    TerminalColors.setNoColorOverride(true);
    final monochrome = style.resolve();

    expect(colored.backgroundColor, Colors.black);
    expect(monochrome.backgroundColor, isNull);
    expect(monochrome.selectedBackgroundColor, isNull);
    expect(monochrome.selectedTextColor, isNull);
    expect(monochrome.itemTextColor, isNull);
    // Layout attributes survive.
    expect(monochrome.padding, style.padding);
    expect(monochrome.border, isNull);
  });
}
