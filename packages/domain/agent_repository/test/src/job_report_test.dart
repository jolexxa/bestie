import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  /// A failed job whose outcome is [outcome].
  DeliveredJobReport failing(JobFailed outcome) =>
      DeliveredJobReport.fromJobReport(
        JobReport(
          conversationId: 'c',
          agentId: 'a',
          callId: 'call',
          toolName: 'shell',
          arguments: const {},
          outcome: outcome,
          outstanding: 2,
        ),
      );

  test('renders a failed job with its body, not just its message', () {
    // A failure's body is where the tool says how to read what it printed
    // before it fell over, which is most of what its report is worth.
    final report = failing(
      const JobFailed('exit 1', content: 'bash_read(id: "call")'),
    );

    expect(report.body, 'exit 1\n\nbash_read(id: "call")');
    expect(
      composeJobReportText([report]),
      contains(
        '<pending>2 jobs still pending, will notify on completion.</pending>',
      ),
    );
  });

  test('renders a failure that left nothing behind as its message alone', () {
    expect(failing(const JobFailed('could not start')).body, 'could not start');
  });

  group('label stamping', () {
    const definition = ToolDefinition(
      name: 'subagent',
      description: 'Spawns.',
      parameters: {},
      onProgress: r'Starting subagent: ${title}',
      onSuccess: r'Started subagent: ${title}',
      onError: r'Could not start subagent: ${title}',
      onJobSuccess: r'Subagent finished: ${title}',
      onJobError: r'Subagent failed: ${title}',
    );

    JobReport report(JobOutcome outcome) => JobReport(
      conversationId: 'c',
      agentId: 'a',
      callId: 'call',
      toolName: 'subagent',
      arguments: const {
        'title': 'Web Search',
        'prompt': 'a very long prompt',
      },
      outcome: outcome,
      outstanding: 0,
    );

    test('stamps the finished-job label and only the arguments it uses', () {
      final delivered = DeliveredJobReport.fromJobReport(
        report(const JobSucceeded('done')),
        definition: definition,
      );

      expect(delivered.labelTemplate, r'Subagent finished: ${title}');
      expect(delivered.labelArguments, {'title': 'Web Search'});
    });

    test('stamps the failed-job label, not the failed-to-start one', () {
      final delivered = DeliveredJobReport.fromJobReport(
        report(const JobFailed('crashed')),
        definition: definition,
      );

      expect(delivered.labelTemplate, r'Subagent failed: ${title}');
    });

    test('leaves the label empty for a tool that declares none', () {
      final delivered = DeliveredJobReport.fromJobReport(
        report(const JobSucceeded('done')),
        definition: const ToolDefinition(
          name: 'subagent',
          description: 'Spawns.',
          parameters: {},
          onProgress: '',
          onSuccess: '',
          onError: '',
        ),
      );

      expect(delivered.labelTemplate, isEmpty);
      expect(delivered.labelArguments, isEmpty);
    });

    test('leaves the label empty when the tool is no longer defined', () {
      final delivered = DeliveredJobReport.fromJobReport(
        report(const JobSucceeded('done')),
      );

      expect(delivered.labelTemplate, isEmpty);
      expect(delivered.labelArguments, isEmpty);
    });
  });
}
