import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// Writes a command `*.md` file under [root] (optionally nested).
Future<File> _writeCommand(
  Directory root,
  String relativePath, {
  String frontmatter = '',
  String body = 'Run the review.',
}) async {
  final file = File('${root.path}/$relativePath')..createSync(recursive: true);
  file.writeAsStringSync(
    frontmatter.isEmpty ? '$body\n' : '---\n$frontmatter---\n\n$body\n',
  );
  return file;
}

void main() {
  group('CommandIndex', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('command_index_test');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('flat commands are named after their file', () async {
      await _writeCommand(
        root,
        'review.md',
        frontmatter: 'description: Review the change.\n',
      );
      await _writeCommand(root, 'compact.md', body: 'Compact the session.');

      final commands = await CommandIndex().commandsIn(root.path);
      expect(commands.map((c) => c.name), containsAll(['review', 'compact']));

      final review = commands.firstWhere((c) => c.name == 'review');
      expect(review.description, 'Review the change.');
      expect(review.body, 'Run the review.');
      expect(review.path, '${root.path}/review.md');

      final compact = commands.firstWhere((c) => c.name == 'compact');
      expect(compact.description, '');
      expect(
        compact.body,
        'Compact the session.',
        reason: 'a command file without frontmatter is its own body',
      );
    });

    test('nested commands namespace to ns:name', () async {
      await _writeCommand(
        root,
        'session/plan.md',
        frontmatter: 'description: Plan a session.\n',
      );
      final commands = await CommandIndex().commandsIn(root.path);
      expect(commands.single.name, 'session:plan');
    });

    test('a relative root keeps nested namespaces', () async {
      // The shipped defaults are relative to the working directory, so the
      // relative path must survive the scan no matter how the root was spelled.
      await _writeCommand(
        root,
        'commands/session/plan.md',
        frontmatter: 'description: Plan a session.\n',
      );
      await _writeCommand(root, 'commands/review.md');

      final previous = Directory.current;
      Directory.current = root;
      try {
        final commands = await CommandIndex().commandsIn('commands');
        expect(
          commands.map((c) => c.name),
          containsAll(['session:plan', 'review']),
        );
      } finally {
        Directory.current = previous;
      }
    });

    test('toSuggestion maps onto a command suggestion', () {
      const command = CommandInfo(
        name: 'session:plan',
        description: 'Plan a session.',
      );
      final suggestion = command.toSuggestion();
      expect(suggestion.kind, FileTextFieldSuggestionKind.command);
      expect(suggestion.displayLabel, '/session:plan');
      expect(suggestion.description, 'Plan a session.');
    });

    test('a missing root yields an empty list', () async {
      final commands = await CommandIndex().commandsIn(
        '${root.path}/does-not-exist',
      );
      expect(commands, isEmpty);
    });

    test('the ttl cache serves a second scan without disk access', () async {
      await _writeCommand(root, 'review.md');
      final index = CommandIndex();

      expect(await index.commandsIn(root.path), hasLength(1));

      await _writeCommand(root, 'late.md');
      expect((await index.commandsIn(root.path)).map((c) => c.name), [
        'review',
      ]);

      index.clear();
      expect(
        (await index.commandsIn(root.path)).map((c) => c.name),
        containsAll(['review', 'late']),
      );
    });
  });

  group('expandCommandTokens', () {
    const commands = [
      CommandInfo(
        name: 'review',
        description: 'Review.',
        body: r'Review $ARGUMENTS carefully.',
      ),
      CommandInfo(
        name: 'shell',
        description: 'Shell.',
        body: r'Echo $5 and $ARGUMENTS',
      ),
    ];

    test('substitutes the body and its ARGUMENTS', () {
      expect(
        expandCommandTokens('run /review now', commands, arguments: 'the diff'),
        'run Review the diff carefully.',
        reason: 'the typed tail moves inside the body, it is not appended',
      );
    });

    test('consumes the tag delimiters the field inserts', () {
      expect(
        expandCommandTokens('do [/review] please', commands),
        'do Review please carefully.',
      );
    });

    test('a body without the placeholder gets the tail after a blank line', () {
      const plain = [
        CommandInfo(name: 'review', description: 'd', body: 'Look around.'),
      ];
      expect(
        expandCommandTokens('run /review now', plain),
        'run Look around.\n\nnow',
        reason:
            'no ARGUMENTS placeholder to fill — the typed tail joins the '
            'body, Gemini-CLI style',
      );
    });

    test('dollar literals other than the ARGUMENTS placeholder survive', () {
      expect(expandCommandTokens('/shell', commands), r'Echo $5 and ');
    });

    test('tokens without a command or body stay untouched', () {
      expect(expandCommandTokens('run /unknown', commands), 'run /unknown');
      const noBody = [CommandInfo(name: 'review', description: 'd')];
      expect(expandCommandTokens('run /review', noBody), 'run /review');
    });
  });

  group('CommandInfo', () {
    test('equality covers every field', () {
      const a = CommandInfo(name: 'review', description: 'Review.', body: 'b');
      const b = CommandInfo(name: 'review', description: 'Review.', body: 'b');
      const c = CommandInfo(
        name: 'review',
        description: 'Review.',
        body: 'other',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString names the command', () {
      const command = CommandInfo(
        name: 'review',
        description: 'Review.',
        path: '/repo/.claude/commands/review.md',
      );
      expect(
        command.toString(),
        contains('CommandInfo(name: review, description: Review.'),
      );
    });
  });
}
