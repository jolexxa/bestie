import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('Job', () {
    test('a completed success settles with its content', () async {
      final job = Job.done('done');

      expect(job.outcome, isA<JobSucceeded>());
      expect((await job.settled as JobSucceeded).content, 'done');
    });

    test('a completed failure retains its optional partial output', () async {
      final job = Job.failed('failed', content: 'partial');

      final outcome = await job.settled as JobFailed;
      expect(outcome.message, 'failed');
      expect(outcome.content, 'partial');
    });
  });

  group('CallIdMinter', () {
    test('pads the epoch-relative time and remains strictly increasing', () {
      final minter = CallIdMinter(now: () => DateTime.utc(2026, 1, 1, 0, 0, 2));

      expect(minter.mint(), '000002');
      expect(minter.mint(), '000003');
    });

    test('advances past a seeded transcript id', () {
      final minter = CallIdMinter(
        now: () => DateTime.utc(2026),
        previous: '00000z',
      );

      expect(minter.mint(), '000010');
    });

    test('seeds past the largest recovered transcript id', () {
      final minter = CallIdMinter(
        now: () => DateTime.utc(2026),
      )..seedAll(['00000z', '000010', '000001']);

      expect(minter.mint(), '000011');
    });
  });

  group('ToolCallResponse', () {
    test('keeps model-facing text distinct for every terminal outcome', () {
      const success = ToolCallSucceeded(
        callId: 'call',
        toolName: 'search',
        content: 'found',
      );
      const background = ToolCallInBackground(
        callId: 'call',
        toolName: 'search',
        content: 'working',
      );
      const failure = ToolCallFailed(
        callId: 'call',
        toolName: 'search',
        message: 'failed',
        content: 'partial',
      );
      const canceled = ToolCallCanceled(
        callId: 'call',
        toolName: 'search',
        message: 'stopped',
      );

      expect(success.modelText, 'found');
      expect(background, isA<ToolCallSucceeded>());
      expect(background.modelText, 'working');
      expect(failure.modelText, 'failed\n\npartial');
      expect(canceled.modelText, 'stopped');
    });

    test('a failure without partial output renders only its message', () {
      const failure = ToolCallFailed(
        callId: 'call',
        toolName: 'search',
        message: 'failed',
      );

      expect(failure.modelText, 'failed');
    });
  });
}
