import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

void main() {
  group('FileTextFieldSuggestion.skill', () {
    test('defaults: / label, skill plate, searchable description', () {
      const suggestion = FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'Plan the work.',
      );

      expect(suggestion.kind, FileTextFieldSuggestionKind.skill);
      expect(suggestion.displayLabel, '/plan');
      expect(suggestion.style, FileTextFieldSuggestion.defaultSkillStyle);
      expect(suggestion.prefix, isNull);
      expect(suggestion.file, isNull);
      expect(suggestion.description, 'Plan the work.');
      expect(
        suggestion.searchableText,
        contains('plan the work.'),
        reason: 'the description takes part in query filtering',
      );
    });

    test('style override wins over the default plate', () {
      const suggestion = FileTextFieldSuggestion.skill(
        name: 'plan',
        style: FileStyle(text: Colors.black, background: Colors.blue),
      );
      expect(suggestion.style.background, Colors.blue);
    });

    test('every kind accepts a description without changing tokens', () {
      const skill = FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'd',
      );
      const agent = FileTextFieldSuggestion.agent(
        name: 'explore',
        description: 'Reads code.',
      );
      expect(agent.displayLabel, '@explore');
      expect(agent.searchableText, contains('reads code.'));
      expect(skill.displayLabel, '/plan');
    });

    test('the default grouping owns a Skills section', () {
      expect(
        SuggestionMenuGrouping.defaultGroups.map((g) => g.title),
        contains('Skills'),
      );
      expect(SuggestionMenuGrouping.defaultGroups.last.kinds, [
        FileTextFieldSuggestionKind.skill,
      ]);
    });

    test('defaultSkillStyle follows the bright-on-regular pattern', () {
      expect(
        FileTextFieldSuggestion.defaultSkillStyle.text,
        Colors.brightWhite,
      );
      expect(
        FileTextFieldSuggestion.defaultSkillStyle.background,
        Colors.white,
      );
    });

    test('suggestions compare by value', () {
      const a = FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'Plan.',
      );
      const b = FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'Plan.',
      );
      const differentDescription = FileTextFieldSuggestion.skill(
        name: 'plan',
        description: 'Other.',
      );
      const differentKind = FileTextFieldSuggestion.command(name: 'plan');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentDescription));
      expect(a, isNot(differentKind));
    });

    test('file-kind suggestions compare with their payload', () {
      final file = FileInfo.fromPath('README.md');
      final a = FileTextFieldSuggestion.file(file, style: const FileStyle());
      final b = FileTextFieldSuggestion.file(file, style: const FileStyle());
      final other = FileTextFieldSuggestion.file(
        FileInfo.fromPath('pubspec.yaml'),
        style: const FileStyle(),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(other));
    });
  });

  group('SkillInfo', () {
    test('toSuggestion maps onto a skill suggestion', () {
      const skill = SkillInfo(
        name: 'plan',
        description: 'Plan the work.',
        directory: '/repo/.claude/skills/plan',
      );
      final suggestion = skill.toSuggestion();
      expect(suggestion.kind, FileTextFieldSuggestionKind.skill);
      expect(suggestion.name, 'plan');
      expect(suggestion.description, 'Plan the work.');
      expect(
        suggestion.path,
        isNull,
        reason:
            'only folder rows navigate; a path would drop the skill '
            'while a folder is browsed',
      );
      expect(skill.directory, '/repo/.claude/skills/plan');
    });

    test('equality covers every field', () {
      const a = SkillInfo(name: 'plan', description: 'd', body: 'b');
      const b = SkillInfo(name: 'plan', description: 'd', body: 'b');
      const c = SkillInfo(name: 'plan', description: 'd', body: 'other');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('expandSkillTokens', () {
    final skills = [
      const SkillInfo(
        name: 'plan',
        description: 'Plan the work.',
        body: 'First read the code.',
      ),
      const SkillInfo(
        name: 'planning-toolkit',
        description: 'Deep planning.',
        body: 'Toolkit body.',
      ),
    ];

    test('replaces a slash token with the skill body', () {
      expect(
        expandSkillTokens('do /plan now', skills),
        'do First read the code.\n\nnow',
        reason:
            'a body without the placeholder receives the tail after a '
            'blank line',
      );
    });

    test('matches on token boundaries only', () {
      expect(
        expandSkillTokens('read /planning-toolkit and /plane', skills),
        'read Toolkit body.\n\nand /plane',
        reason:
            '/plane is no skill, /planning-toolkit is the longer match — '
            'and the tail after it joins the body',
      );
    });

    test('a token at the end of the text still expands', () {
      expect(
        expandSkillTokens('run /plan', skills),
        'run First read the code.',
      );
    });

    test('a skill body with a placeholder captures its own tail', () {
      final withArgs = [
        ...skills,
        const SkillInfo(
          name: 'map',
          description: 'Map the code.',
          body: r'Focus: $ARGUMENTS',
        ),
      ];
      expect(
        expandSkillTokens('run /map fix auth', withArgs),
        'run Focus: fix auth',
        reason:
            'skill bodies expand like commands — the typed tail fills '
            'the placeholder once',
      );
    });

    test('the tag delimiters the field inserts are consumed too', () {
      expect(
        expandSkillTokens('do [/plan] now', skills),
        'do First read the code.\n\nnow',
        reason: 'the field inserts skills as [/plan] tags, like every token',
      );
    });

    test('tokens without a body or skill stay untouched', () {
      final noBody = [
        const SkillInfo(name: 'plan', description: 'd'),
        ...skills.where((s) => s.name != 'plan'),
      ];
      expect(expandSkillTokens('do /plan', noBody), 'do /plan');
      expect(expandSkillTokens('do /unknown', skills), 'do /unknown');
    });

    test('empty input or skill list is a no-op', () {
      expect(expandSkillTokens('', skills), '');
      expect(expandSkillTokens('do /plan', const []), 'do /plan');
    });

    test('dollar signs in bodies are inserted literally', () {
      final dollar = const [
        SkillInfo(
          name: 'shell',
          description: 'd',
          body: r'cost is $5 and $name',
        ),
      ];
      expect(expandSkillTokens('/shell', dollar), r'cost is $5 and $name');
    });
  });
}
