import 'dart:io';

import 'package:nocterm/nocterm.dart' hide isEmpty;

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// Creates `<root>/<family>/` and returns the three family directories.
(Directory, Directory, Directory) _conventionRoots(String name) {
  final base = Directory.systemTemp.createTempSync('prompt_index_$name');
  final skills = Directory('${base.path}/skills')..createSync();
  final commands = Directory('${base.path}/commands')..createSync();
  final agents = Directory('${base.path}/agents')..createSync();
  return (skills, commands, agents);
}

void main() {
  group('PromptIndex', () {
    late Directory skillsRoot;
    late Directory commandsRoot;
    late Directory agentsRoot;
    late Directory base;

    setUp(() {
      (skillsRoot, commandsRoot, agentsRoot) = _conventionRoots('setup');
      base = skillsRoot.parent;
      Directory('${skillsRoot.path}/map').createSync();
      File('${skillsRoot.path}/map/SKILL.md').writeAsStringSync(
        '---\nname: map\ndescription: Plan first.\n---\n\nRead the code.\n\n'
        'Focus: \$ARGUMENTS\n',
      );
      File('${commandsRoot.path}/audit.md').writeAsStringSync(
        '---\ndescription: Review.\n---\n\nReview \$ARGUMENTS.\n',
      );
      File('${agentsRoot.path}/reviewer.md').writeAsStringSync(
        '---\ndescription: Reviews code.\n---\n\nYou review.\n',
      );
    });

    tearDown(() {
      base.deleteSync(recursive: true);
    });

    test('load gathers all three families from the extra roots', () async {
      final index = PromptIndex();
      await index.load(
        extraSkillRoots: [skillsRoot.path],
        extraCommandRoots: [commandsRoot.path],
        extraAgentRoots: [agentsRoot.path],
      );

      // The extras feed their own families; the defaults contribute nothing
      // here because this repository ships no `.agents/` tree.
      expect(index.skills.map((s) => s.name), containsAll(['map']));
      expect(index.commands.map((c) => c.name), containsAll(['audit']));
      expect(index.agents.map((a) => a.name), containsAll(['reviewer']));
    });

    test('the shipped defaults stay vendor-neutral', () async {
      // Only the open .agents standard is built in; .claude, .opencode and
      // every host-specific convention go through extra*Roots by design.
      expect(defaultSkillRoots, ['.agents/skills']);
      expect(defaultCommandRoots, ['.agents/commands']);
      expect(defaultAgentRoots, ['.agents/agents']);
    });

    test('the relative defaults keep nested command namespaces', () async {
      // The defaults are relative paths, so a nested command under the working
      // directory must still read `sub:name` — and expand through its full name.
      final base = Directory.systemTemp.createTempSync('prompt_defaults');
      Directory('${base.path}/.agents/commands/session')
          .createSync(recursive: true);
      File('${base.path}/.agents/commands/session/plan.md')
          .writeAsStringSync('Plan the session.\n');

      final previous = Directory.current;
      Directory.current = base;
      try {
        final index = PromptIndex();
        await index.load();
        expect(index.commands.single.name, 'session:plan');
        expect(index.suggestionsFor('/').single.displayLabel, '/session:plan');
        expect(
          index.expandTokens('do /session:plan now'),
          'do Plan the session.\n\nnow',
        );
      } finally {
        Directory.current = previous;
        base.deleteSync(recursive: true);
      }
    });

    test('an empty index expands nothing', () async {
      final index = PromptIndex();
      expect(index.suggestionsFor('/'), isEmpty);
      expect(index.expandTokens('nothing to expand'), 'nothing to expand');
    });

    test('suggestionsFor maps the families onto their kinds', () async {
      final index = PromptIndex();
      await index.load(
        extraSkillRoots: [skillsRoot.path],
        extraCommandRoots: [commandsRoot.path],
        extraAgentRoots: [agentsRoot.path],
      );

      final slash = index.suggestionsFor('/');
      expect(slash.map((s) => s.displayLabel), containsAll(['/audit', '/map']));
      expect(
        slash.every(
          (s) =>
              s.kind == FileTextFieldSuggestionKind.command ||
              s.kind == FileTextFieldSuggestionKind.skill,
        ),
        isTrue,
      );

      final at = index.suggestionsFor('@');
      expect(at.map((s) => s.displayLabel), contains('@reviewer'));
      expect(
        at.every((s) => s.kind == FileTextFieldSuggestionKind.agent),
        isTrue,
      );

      expect(index.suggestionsFor('#'), isEmpty);
    });

    test(
      'expandTokens substitutes command bodies with arguments, then skills',
      () async {
        final index = PromptIndex();
        await index.load(
          extraSkillRoots: [skillsRoot.path],
          extraCommandRoots: [commandsRoot.path],
          extraAgentRoots: [agentsRoot.path],
        );

        // Command first (the field inserts it as a tag), skill after.
        expect(
          index.expandTokens('map [/audit] then /map', arguments: 'the diff'),
          'map Review the diff.Read the code.\n\nFocus: the diff',
          reason:
              'the command consumes only its own arguments span — the '
              'skill token after it still expands',
        );
      },
    );

    test(
      'trailing text after a command fills its ARGUMENTS automatically',
      () async {
        final index = PromptIndex();
        await index.load(
          extraCommandRoots: [commandsRoot.path],
          extraAgentRoots: [agentsRoot.path],
        );

        // Use the tmp audit command — its body reads `Review $ARGUMENTS.`.
        expect(index.trailingArguments('do /audit now'), 'now');
        expect(index.expandTokens('do /audit now'), contains('Review now.'));
        expect(
          index.expandTokens('do /audit carefully'),
          contains('Review carefully.'),
        );
      },
    );

    test('explicit arguments win over the trailing text', () async {
      final index = PromptIndex();
      await index.load(
        extraCommandRoots: [commandsRoot.path],
        extraAgentRoots: [agentsRoot.path],
      );
      expect(
        index.expandTokens('do /audit now', arguments: 'the diff'),
        contains('Review the diff.'),
      );
    });

    test('autoArguments: false substitutes nothing', () async {
      final index = PromptIndex();
      await index.load(extraCommandRoots: [commandsRoot.path]);
      expect(
        index.expandTokens('do /audit now', autoArguments: false),
        contains('Review .'),
      );
    });

    test('auto mode gives every token its own tail', () async {
      final index = PromptIndex();
      await index.load(
        extraSkillRoots: [skillsRoot.path],
        extraCommandRoots: [commandsRoot.path],
      );

      // `map` carries a `Focus: $ARGUMENTS` body and `audit` a
      // `Review $ARGUMENTS.` one — each captures the text typed after ITS
      // token, and neither span leaks into the other.
      expect(
        index.expandTokens('/map fix auth /audit the diff'),
        'Read the code.\n\nFocus: fix authReview the diff.',
      );
      expect(index.expandTokens('/map now'), 'Read the code.\n\nFocus: now');
    });

    test(
      'inlineTokensFor colors the tokens a transcript should show',
      () async {
        final index = PromptIndex();
        await index.load(
          extraCommandRoots: [commandsRoot.path],
          extraSkillRoots: [skillsRoot.path],
        );

        final tokens = index.inlineTokensFor('plan /audit then /map');
        expect(tokens.map((t) => t.token), ['/audit', '/map']);
        // Commands and skills wear their own default plates.
        expect(tokens[0].style, FileTextFieldSuggestion.defaultCommandStyle);
        expect(tokens[1].style, FileTextFieldSuggestion.defaultSkillStyle);

        final custom = index.inlineTokensFor(
          '/audit',
          commandStyle: const FileStyle(
            text: Colors.black,
            background: Colors.blue,
          ),
        );
        expect(custom.single.style.background, Colors.blue);
      },
    );

    test('agents ride the @ menu only and are never expanded', () async {
      final index = PromptIndex();
      await index.load(
        extraSkillRoots: [skillsRoot.path],
        extraCommandRoots: [commandsRoot.path],
        extraAgentRoots: [agentsRoot.path],
      );
      expect(index.expandTokens('ask @reviewer'), 'ask @reviewer');
    });
  });
}
