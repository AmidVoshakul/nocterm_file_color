import 'dart:io';

import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

/// Writes an agent `*.md` file under [root].
Future<File> _writeAgent(
  Directory root,
  String fileName, {
  String frontmatter = '',
  String body = 'You are the reviewer.',
}) async {
  final file = File('${root.path}/$fileName')..createSync(recursive: true);
  file.writeAsStringSync(
    frontmatter.isEmpty ? '$body\n' : '---\n$frontmatter---\n\n$body\n',
  );
  return file;
}

void main() {
  group('AgentIndex', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('agent_index_test');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('the frontmatter name wins over the file stem', () async {
      await _writeAgent(
        root,
        'code-reviewer.md',
        frontmatter:
            'name: reviewer\ndescription: Reviews code.\n'
            'mode: subagent\nmodel: some/model\ntools:\n  read: true\n  write: false\n',
      );
      final agents = await AgentIndex().agentsIn(root.path);
      final agent = agents.single;
      expect(agent.name, 'reviewer');
      expect(agent.description, 'Reviews code.');
      expect(agent.body, 'You are the reviewer.');
      expect(agent.path, '${root.path}/code-reviewer.md');
    });

    test('the file stem is the fallback name', () async {
      await _writeAgent(
        root,
        'explore.md',
        frontmatter: 'description: Explores.\n',
      );
      final agents = await AgentIndex().agentsIn(root.path);
      expect(agents.single.name, 'explore');
    });

    test('a relative root resolves against the working directory', () async {
      await _writeAgent(root, 'agents/explore.md');

      final previous = Directory.current;
      Directory.current = root;
      try {
        final agents = await AgentIndex().agentsIn('agents');
        expect(agents.single.name, 'explore');
        expect(agents.single.path, 'agents/explore.md');
      } finally {
        Directory.current = previous;
      }
    });

    test('toSuggestion maps onto an agent suggestion', () {
      const agent = AgentInfo(name: 'reviewer', description: 'Reviews code.');
      final suggestion = agent.toSuggestion();
      expect(suggestion.kind, FileTextFieldSuggestionKind.agent);
      expect(suggestion.displayLabel, '@reviewer');
      expect(suggestion.description, 'Reviews code.');
    });

    test('a missing root yields an empty list', () async {
      final agents = await AgentIndex().agentsIn('${root.path}/nope');
      expect(agents, isEmpty);
    });
  });

  group('AgentInfo', () {
    test('equality covers every field', () {
      const a = AgentInfo(name: 'reviewer', description: 'Reviews.');
      const b = AgentInfo(name: 'reviewer', description: 'Reviews.');
      const c = AgentInfo(name: 'reviewer', description: 'Other.');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString names the agent', () {
      const agent = AgentInfo(
        name: 'reviewer',
        description: 'Reviews.',
        path: '/repo/.claude/agents/reviewer.md',
      );
      expect(
        agent.toString(),
        contains('AgentInfo(name: reviewer, description: Reviews.'),
      );
    });
  });
}
