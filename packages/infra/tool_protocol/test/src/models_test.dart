import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('Contribution', () {
    test('carries a source url and optional title', () {
      const contribution = SourceContribution(
        url: 'https://example.test',
        title: 'Example',
      );

      expect(contribution.url, 'https://example.test');
      expect(contribution.title, 'Example');
      expect(contribution.type, 'source');
    });

    test('round-trips a diff through json under its own type', () {
      const contribution = DiffContribution(
        path: 'lib/main.dart',
        diff: FileDiff(
          hunks: [
            DiffHunk(
              oldStart: 1,
              oldCount: 2,
              newStart: 1,
              newCount: 2,
              lines: [
                DiffLine(kind: DiffLineKind.context, text: 'a'),
                DiffLine(kind: DiffLineKind.removed, text: 'b'),
                DiffLine(kind: DiffLineKind.added, text: 'c'),
              ],
            ),
          ],
          added: 1,
          removed: 1,
        ),
      );

      final json = contribution.toMap();
      final restored = ContributionMapper.fromMap(json);

      expect(json['type'], 'diff');
      expect(restored, isA<DiffContribution>());
      expect(restored.type, 'diff');
      expect(restored, contribution);
      expect((restored as DiffContribution).diff.truncated, isFalse);
    });

    test('round-trips a created file through json under its own type', () {
      const contribution = CreatedFileContribution(
        path: 'lib/new.dart',
        text: 'void main() {}\n',
        lines: 1,
        truncated: true,
      );

      final json = contribution.toMap();
      final restored = ContributionMapper.fromMap(json);

      expect(json['type'], 'created');
      expect(restored, isA<CreatedFileContribution>());
      expect(restored.type, 'created');
      expect(restored, contribution);
    });
  });

  group('JobBackgrounded', () {
    test('carries the call it came from, arguments and all', () {
      const job = JobBackgrounded(
        conversationId: 'conversation',
        agentId: 'agent',
        callId: 'call-1',
        toolName: 'bash',
        arguments: {'command': 'sleep 30'},
      );

      expect(job.conversationId, 'conversation');
      expect(job.agentId, 'agent');
      expect(job.callId, 'call-1');
      expect(job.toolName, 'bash');
      expect(job.arguments, {'command': 'sleep 30'});
    });
  });

  group('ToolCall', () {
    test('distinguishes default from reasoning calls', () {
      const normal = ToolCallDefault(id: 'call', name: 'search', arguments: {});
      const reasoning = ToolCallReasoning(
        id: 'call',
        name: 'search',
        arguments: {},
      );

      expect(normal, isA<ToolCallDefault>());
      expect(reasoning, isA<ToolCallReasoning>());
    });
  });

  group('Job', () {
    test('retains contributions on a successful outcome', () async {
      const contribution = SourceContribution(url: 'https://example.test');
      final outcome = await Job.done(
        'done',
        contributions: [contribution],
      ).settled;

      expect((outcome as JobSucceeded).contributions, [contribution]);
    });

    test('retains partial output on a failed outcome', () async {
      final outcome = await Job.failed('failed', content: 'partial').settled;

      expect((outcome as JobFailed).content, 'partial');
    });
  });

  group('ToolCallResponse', () {
    test('carries identity independently from its terminal payload', () {
      const response = ToolCallInBackground(
        callId: 'call',
        toolName: 'shell',
        content: 'working',
      );

      expect(response.callId, 'call');
      expect(response.toolName, 'shell');
      expect(response.modelText, 'working');
    });
  });
}
