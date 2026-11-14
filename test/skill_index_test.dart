import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// Writes a `SKILL.md` under `<root>/<name>/` and returns the directory.
Future<Directory> _writeSkill(
  Directory root,
  String name, {
  String frontmatter = '',
  String? body,
}) async {
  final dir = Directory('${root.path}/$name')..createSync(recursive: true);
  File(
    '${dir.path}/SKILL.md',
  ).writeAsStringSync('---\n$frontmatter---\n\n${body ?? 'Body of $name.'}\n');
  return dir;
}

void main() {
  group('SkillFrontmatter', () {
    test('parses name, description and body', () {
      final skill = SkillFrontmatter.parse(
        '/skills/plan/SKILL.md',
        '---\nname: plan\ndescription: Plan the work.\n---\n\n'
            'Step one.\nStep two.\n',
      );
      expect(skill, isNotNull);
      expect(skill!.name, 'plan');
      expect(skill.description, 'Plan the work.');
      expect(skill.body, 'Step one.\nStep two.');
      expect(skill.directory, '/skills/plan');
      expect(skill.disableModelInvocation, isFalse);
    });

    test('falls back to the directory name when name is missing', () {
      final skill = SkillFrontmatter.parse(
        '/skills/fallback-name/SKILL.md',
        '---\ndescription: Only a description.\n---\n\nbody\n',
      );
      expect(skill!.name, 'fallback-name');
    });

    test('reads folded and literal description blocks', () {
      final folded = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: >\n  Folded across\n  several lines.\n---\n\n',
      );
      expect(folded!.description, 'Folded across several lines.');

      final literal = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: |\n  Literal keeps\n  its newlines.\n---\n\n',
      );
      // Continuation lines join with spaces, like every other block.
      expect(literal!.description, 'Literal keeps its newlines.');
    });

    test('strips quotes from scalar values', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: "quoted-name"\ndescription: \'A quoted summary.\'\n---\n\n',
      );
      expect(skill!.name, 'quoted-name');
      expect(skill.description, 'A quoted summary.');
    });

    test('reads disable-model-invocation', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: d\ndisable-model-invocation: true\n---\n\n',
      );
      expect(skill!.disableModelInvocation, isTrue);
    });

    test('a folded description keeps url-like continuation lines', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: >\n  Read the rules at\n'
            '  https://docs.example.com/skills\n  and follow them.\n---\n\n',
      );
      expect(
        skill!.description,
        'Read the rules at https://docs.example.com/skills and follow them.',
        reason: 'a `https:` line inside a block is not a new key',
      );
    });

    test('a plain multi-line description joins its lines', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription:\n  First line\n  Second line\n---\n\n',
      );
      expect(skill!.description, 'First line Second line');
    });

    test('disable-model-invocation is case-insensitive', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: d\ndisable-model-invocation: True\n---\n\n',
      );
      expect(skill!.disableModelInvocation, isTrue);
    });

    test('when_to_use extends the description', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\nname: s\ndescription: Plan the work.\n'
            'when_to_use: the user asks for a plan\n---\n\n',
      );
      expect(skill!.description, 'Plan the work. the user asks for a plan');
    });

    test('disable-model-invocation accepts the yaml 1.1 truthy family', () {
      for (final value in ['true', 'True', 'TRUE', 'yes', 'On', '1']) {
        final skill = SkillFrontmatter.parse(
          '/s/SKILL.md',
          '---\nname: s\ndescription: d\ndisable-model-invocation: $value\n---\n\n',
        );
        expect(skill!.disableModelInvocation, isTrue, reason: 'value: $value');
      }
      for (final value in ['false', 'no', 'off', '0', 'maybe']) {
        final skill = SkillFrontmatter.parse(
          '/s/SKILL.md',
          '---\nname: s\ndescription: d\ndisable-model-invocation: $value\n---\n\n',
        );
        expect(skill!.disableModelInvocation, isFalse, reason: 'value: $value');
      }
    });

    test('normalizes CRLF line endings out of the body', () {
      final skill = SkillFrontmatter.parse(
        '/s/SKILL.md',
        '---\r\nname: s\r\ndescription: d\r\n---\r\n\r\nline one\r\nline two\r\n',
      );
      expect(skill!.name, 's');
      expect(skill.description, 'd');
      expect(skill.body, 'line one\nline two');
    });

    test('returns null for missing delimiters or empty body-less files', () {
      expect(
        SkillFrontmatter.parse('/s/SKILL.md', 'name: s\ndescription: d'),
        isNull,
        reason: 'no frontmatter fence',
      );
      expect(
        SkillFrontmatter.parse('/s/SKILL.md', '---\nname: s\n---\n\n'),
        isNull,
        reason: 'no description',
      );
    });
  });

  group('SkillIndex', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('skill_index_test');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('discovers skills from SKILL.md files', () async {
      await _writeSkill(
        root,
        'plan',
        frontmatter: 'name: plan\ndescription: Plan.\n',
      );
      await _writeSkill(
        root,
        'review',
        frontmatter: 'name: review\ndescription: Review.\n',
      );

      final skills = await SkillIndex().skillsIn(root.path);
      expect(skills.map((s) => s.name), containsAll(['plan', 'review']));
      expect(
        skills.firstWhere((s) => s.name == 'plan').body,
        contains('Body of plan'),
      );
    });

    test('an empty body leaves body null', () async {
      await _writeSkill(
        root,
        'empty',
        frontmatter: 'name: empty\ndescription: d\n',
        body: '',
      );
      final skills = await SkillIndex().skillsIn(root.path);
      expect(skills.single.body, isNull);
    });

    test('skips files without a usable skill', () async {
      await _writeSkill(
        root,
        'good',
        frontmatter: 'name: good\ndescription: d\n',
      );
      await _writeSkill(root, 'bad', frontmatter: 'name: bad\n');
      File('${root.path}/stray.md').writeAsStringSync('not a skill');

      final skills = await SkillIndex().skillsIn(root.path);
      expect(skills.map((s) => s.name), ['good']);
    });

    test('a missing root yields an empty list', () async {
      final skills = await SkillIndex().skillsIn('${root.path}/does-not-exist');
      expect(skills, isEmpty);
    });

    test('an empty root string yields an empty list', () async {
      final skills = await SkillIndex().skillsIn('');
      expect(skills, isEmpty);
    });

    test('a symlink escaping the scanned root is skipped', () async {
      await _writeSkill(
        root,
        'inside',
        frontmatter: 'name: inside\ndescription: d\n',
      );
      final outside = Directory.systemTemp.createTempSync('skill_outside');
      try {
        await _writeSkill(
          outside,
          'escaped',
          frontmatter: 'name: escaped\ndescription: d\n',
        );
        // A sibling whose name merely starts with the root's must not pass
        // either — the check compares against the root plus a separator.
        final sibling = Directory('${root.path}_evil')..createSync();
        try {
          await _writeSkill(
            sibling,
            'sibling',
            frontmatter: 'name: sibling\ndescription: d\n',
          );
          Link('${root.path}/escape').createSync('${outside.path}/escaped');
          Link('${root.path}/evil').createSync(sibling.path);

          final skills = await SkillIndex().skillsIn(root.path);
          expect(skills.map((s) => s.name), [
            'inside',
          ], reason: 'neither the symlink nor the sibling directory leaks in');
        } finally {
          sibling.deleteSync(recursive: true);
        }
      } finally {
        outside.deleteSync(recursive: true);
      }
    });

    test('extra roots merge and dedupe by name (first wins)', () async {
      await _writeSkill(
        root,
        'plan',
        frontmatter: 'name: plan\ndescription: Root plan.\n',
      );
      final extra = Directory.systemTemp.createTempSync('skill_extra');
      try {
        await _writeSkill(
          extra,
          'plan',
          frontmatter: 'name: plan\ndescription: Extra plan.\n',
        );
        await _writeSkill(
          extra,
          'audit',
          frontmatter: 'name: audit\ndescription: Audit.\n',
        );

        final skills = await SkillIndex().skillsIn(
          root.path,
          extraRoots: [extra.path],
        );
        expect(skills.map((s) => s.name), containsAll(['plan', 'audit']));
        expect(
          skills.firstWhere((s) => s.name == 'plan').description,
          'Root plan.',
          reason: 'the first source wins on a name clash',
        );
      } finally {
        extra.deleteSync(recursive: true);
      }
    });

    test('non-recursive scans only look one level deep', () async {
      // A SKILL.md sitting directly in the root is found; the nested one is
      // two levels down (`group/deep/SKILL.md`) and stays invisible.
      File('${root.path}/SKILL.md')
          .writeAsStringSync('---\nname: top\ndescription: d\n---\n\n');
      final nested = Directory('${root.path}/group')..createSync();
      await _writeSkill(
        nested,
        'deep',
        frontmatter: 'name: deep\ndescription: d\n',
      );

      final skills = await SkillIndex().skillsIn(root.path, recursive: false);
      expect(skills.map((s) => s.name), ['top']);

      final deep = await SkillIndex().skillsIn(root.path);
      expect(deep.map((s) => s.name), containsAll(['top', 'deep']));
    });

    test('a root reached through a symlinked parent still works', () async {
      // The root and the candidate resolve to different prefixes only when
      // one of them is compared unresolved — mirror the macOS temp-dir case
      // (/var/folders → /private/var/folders) with an explicit link.
      final parent = Directory.systemTemp.createTempSync('skill_link_parent');
      try {
        final real = Directory('${parent.path}/real')..createSync();
        await _writeSkill(
          real,
          'linked',
          frontmatter: 'name: linked\ndescription: d\n',
        );
        final link = Link('${parent.path}/via-link')
          ..createSync('${parent.path}/real');

        final skills = await SkillIndex().skillsIn(link.path);
        expect(
          skills.map((s) => s.name),
          ['linked'],
          reason:
              'a root whose own path traverses a symlink must still discover '
              'its skills, not silently report none',
        );
      } finally {
        parent.deleteSync(recursive: true);
      }
    });

    test('the ttl cache serves a second scan without disk access', () async {
      await _writeSkill(
        root,
        'plan',
        frontmatter: 'name: plan\ndescription: Plan.\n',
      );
      final index = SkillIndex();

      final first = await index.skillsIn(root.path);
      expect(first, hasLength(1));

      // A brand-new file on disk must not appear within the ttl.
      await _writeSkill(
        root,
        'late',
        frontmatter: 'name: late\ndescription: d\n',
      );
      final cached = await index.skillsIn(root.path);
      expect(cached.map((s) => s.name), ['plan']);

      index.clear();
      final refreshed = await index.skillsIn(root.path);
      expect(refreshed.map((s) => s.name), containsAll(['plan', 'late']));
    });

    test('recursive and shallow scans of one root cache separately', () async {
      File('${root.path}/SKILL.md')
          .writeAsStringSync('---\nname: top\ndescription: d\n---\n\n');
      final nested = Directory('${root.path}/group')..createSync();
      await _writeSkill(
        nested,
        'deep',
        frontmatter: 'name: deep\ndescription: d\n',
      );
      final index = SkillIndex();

      final shallow = await index.skillsIn(root.path, recursive: false);
      expect(shallow.map((s) => s.name), ['top']);

      final deep = await index.skillsIn(root.path);
      expect(
        deep.map((s) => s.name),
        containsAll(['top', 'deep']),
        reason: 'the recursive scan must not reuse the shallow listing',
      );
    });

    test('a custom parser replaces the built-in one', () async {
      await _writeSkill(
        root,
        'plan',
        frontmatter: 'name: plan\ndescription: Plan.\n',
      );
      final skills = await SkillIndex(
        parser: (path, content) =>
            const SkillInfo(name: 'custom', description: 'from parser'),
      ).skillsIn(root.path);
      expect(skills.single.name, 'custom');
    });
  });
}
