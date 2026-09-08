import 'package:agent_repository/src/conversation/job_in_background.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('label stamping', () {
    const definition = ToolDefinition(
      name: 'bash',
      description: 'Runs.',
      parameters: {},
      onProgress: r'Running ${command}',
      onSuccess: r'Ran ${command}',
      onError: r'Failed to run ${command}',
      onBackgrounded: r'Continuing in background: ${command}',
      onJobSuccess: r'Finished: ${command}',
      onJobError: r'Failed: ${command}',
    );

    const job = JobBackgrounded(
      conversationId: 'c',
      agentId: 'a',
      callId: 'call-1',
      toolName: 'bash',
      arguments: {'command': 'sleep 30', 'unused': 'noise'},
    );

    test('stamps the backgrounded label, not the running one', () {
      // The call has already answered, so reusing its running label reads as
      // if the command had been started a second time.
      final backgrounded = JobInBackground.fromJobBackgrounded(
        job,
        definition: definition,
      );

      expect(
        backgrounded.labelTemplate,
        r'Continuing in background: ${command}',
      );
      expect(backgrounded.callId, 'call-1');
      expect(backgrounded.toolName, 'bash');
    });

    test('falls back to the running label for a tool without one', () {
      final backgrounded = JobInBackground.fromJobBackgrounded(
        job,
        definition: const ToolDefinition(
          name: 'bash',
          description: 'Runs.',
          parameters: {},
          onProgress: r'Running ${command}',
          onSuccess: '',
          onError: '',
        ),
      );

      expect(backgrounded.labelTemplate, r'Running ${command}');
    });

    test('keeps only the arguments the label substitutes', () {
      final backgrounded = JobInBackground.fromJobBackgrounded(
        job,
        definition: definition,
      );

      expect(backgrounded.labelArguments, {'command': 'sleep 30'});
    });

    test('leaves the label empty for a tool that declares none', () {
      final backgrounded = JobInBackground.fromJobBackgrounded(
        job,
        definition: const ToolDefinition(
          name: 'bash',
          description: 'Runs.',
          parameters: {},
          onProgress: '',
          onSuccess: '',
          onError: '',
        ),
      );

      expect(backgrounded.labelTemplate, isEmpty);
      expect(backgrounded.labelArguments, isEmpty);
    });

    test('leaves the label empty when the tool is no longer defined', () {
      final backgrounded = JobInBackground.fromJobBackgrounded(job);

      expect(backgrounded.labelTemplate, isEmpty);
      expect(backgrounded.labelArguments, isEmpty);
    });
  });
}
