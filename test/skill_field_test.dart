import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

List<FileTextFieldSuggestion> skillSuggestions(String trigger, String query) =>
    const [
      FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'Plan the work first.',
      ),
      FileTextFieldSuggestion.command(name: 'help'),
    ];

/// One skill with a summary far wider than any menu box.
List<FileTextFieldSuggestion> longDescriptionSuggestions(
  String trigger,
  String query,
) => const [
  FileTextFieldSuggestion.skill(
    name: 'plan',
    description:
        'Plan the work first by reading the repository conventions end to end '
        'and only then draft the change set for review.',
  ),
];

void main() {
  group('skills in FileTextField', () {
    test('the / menu lists skills under their own section, with the '
        'description', () async {
      final controller = TextEditingController();

      await testNocterm('skill menu', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 50,
            height: 1,
            onSuggestionsRequested: skillSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        expect(tester.terminalState, containsText('Skills'));
        expect(tester.terminalState, containsText('/plan'));
        expect(
          tester.terminalState,
          containsText('Plan the work first.'),
          reason: 'the built-in menu renders the description',
        );
      });

      controller.dispose();
    });

    test('selecting a skill inserts its colored token', () async {
      final controller = TextEditingController();

      await testNocterm('skill insert', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 50,
            height: 1,
            onSuggestionsRequested: skillSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.enter),
        );
        await tester.pump();

        expect(controller.text, '[/plan] ');
        expect(controller.selection.extentOffset, controller.text.length);
      });

      controller.dispose();
    });

    test('a skill query filters on the description too', () async {
      final controller = TextEditingController();

      await testNocterm('skill filter', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 50,
            height: 1,
            onSuggestionsRequested: skillSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();
        await tester.enterText('first');
        await tester.pump();

        // Only the skill matches; the /help command is filtered out.
        expect(tester.terminalState, containsText('/plan'));
        expect(tester.terminalState, isNot(containsText('/help')));
      });

      controller.dispose();
    });

    test('refreshSuggestions updates an open menu when the source settles '
        'late', () async {
      // The async-suggestion story: an empty provider until the scan lands.
      final controller = TextEditingController();
      var ready = false;
      final key = GlobalKey<FileTextFieldState>();

      await testNocterm('skill source refresh', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            key: key,
            controller: controller,
            focused: true,
            width: 40,
            height: 1,
            onSuggestionsRequested: (trigger, query) => ready
                ? const [FileTextFieldSuggestion.command(name: 'help')]
                : const [],
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();
        expect(tester.terminalState, containsText('No matches'));

        ready = true;
        key.currentState!.refreshSuggestions();
        await tester.pump();
        expect(tester.terminalState, containsText('/help'));
      });

      controller.dispose();
    });

    test(
      'refreshSuggestions notifies the host and keeps the highlight',
      () async {
        final controller = TextEditingController();
        var ready = false;
        var notifications = 0;
        final key = GlobalKey<FileTextFieldState>();

        await testNocterm('refresh keeps highlight', (tester) async {
          await tester.pumpComponent(
            FileTextField(
              key: key,
              controller: controller,
              focused: true,
              width: 40,
              height: 1,
              onSuggestionMenuChanged: () => notifications++,
              onSuggestionsRequested: (trigger, query) => ready
                  ? const [
                      FileTextFieldSuggestion.command(name: 'help'),
                      FileTextFieldSuggestion.command(name: 'compact'),
                    ]
                  : const [],
            ),
          );
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
          );
          await tester.pump();
          expect(tester.terminalState, containsText('No matches'));

          ready = true;
          // The source settles: the list changes, so the highlight resets.
          key.currentState!.refreshSuggestions();
          await tester.pump();
          expect(tester.terminalState, containsText('/help'));

          // Move the highlight, then refresh again with the SAME list — the
          // shape of a provider re-running against settled data.
          await tester.sendKeyEvent(
            const KeyboardEvent(logicalKey: LogicalKey.arrowDown),
          );
          await tester.pump();
          expect(key.currentState!.selectedSuggestionIndex, 1);

          // Refresh once more with the settled list: the highlight holds.
          key.currentState!.refreshSuggestions();
          await tester.pump();
          expect(
            key.currentState!.selectedSuggestionIndex,
            1,
            reason: 'the settled list keeps the highlight the keyboard left',
          );
          expect(
            notifications,
            greaterThan(0),
            reason: 'a host-rendered menu rebuilds on the refresh',
          );
        });

        controller.dispose();
      },
    );

    test('a long description is truncated with an ellipsis', () async {
      final controller = TextEditingController();

      await testNocterm('skill description truncation', (tester) async {
        await tester.pumpComponent(
          FileTextField(
            controller: controller,
            focused: true,
            width: 50,
            height: 1,
            onSuggestionsRequested: longDescriptionSuggestions,
          ),
        );
        await tester.sendKeyEvent(
          const KeyboardEvent(logicalKey: LogicalKey.slash, character: '/'),
        );
        await tester.pump();

        final text = tester.terminalState.getText();
        expect(text, contains('…'), reason: 'the summary is capped');
        expect(
          text,
          isNot(containsText('end to end')),
          reason: 'the tail of a long summary does not reach the row',
        );
      });

      controller.dispose();
    });
  });
}
