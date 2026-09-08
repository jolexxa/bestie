import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/job_manager.dart';
import 'package:bestie_tools_use_case/src/routing/job_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockToolRequester extends Mock implements ToolRequester {}

const _call = ToolCallDefault(id: 'call-1', name: 'search', arguments: {});

void main() {
  setUpAll(
    () => registerFallbackValue(
      const JobReport(
        conversationId: 'conversation',
        agentId: 'agent',
        callId: 'call',
        toolName: 'search',
        arguments: <String, Object?>{},
        outcome: JobSucceeded('done'),
        outstanding: 0,
      ),
    ),
  );

  setUpAll(
    () => registerFallbackValue(
      const JobBackgrounded(
        conversationId: 'conversation',
        agentId: 'agent',
        callId: 'call',
        toolName: 'search',
        arguments: <String, Object?>{},
      ),
    ),
  );

  late _MockToolRequester requester;

  setUp(() => requester = _MockToolRequester());

  /// Every report delivered so far, in the order they arrived.
  List<JobReport> delivered() => verify(
    () => requester.deliverReport(captureAny()),
  ).captured.cast<JobReport>();

  /// Every job announced as backgrounded, in the order they were taken up.
  List<JobBackgrounded> announced() => verify(
    () => requester.noteBackgrounded(captureAny()),
  ).captured.cast<JobBackgrounded>();

  test('announces a job the moment it is taken up', () async {
    final reporter = JobReporter(requester: requester);
    addTearDown(reporter.dispose);

    reporter.watch(_entry(_call, _DeferredJob()));

    final job = announced().single;
    expect(job.callId, 'call-1');
    expect(job.toolName, 'search');
    expect(job.agentId, 'agent');
    // Announced before anything settles: the row exists while the work does.
    verifyNever(() => requester.deliverReport(any()));
  });

  test('announces each job once, in the order they were taken up', () async {
    final reporter = JobReporter(requester: requester);
    addTearDown(reporter.dispose);

    reporter
      ..watch(_entry(_call, _DeferredJob()))
      ..watch(
        _entry(
          const ToolCallDefault(id: 'call-2', name: 'read', arguments: {}),
          _DeferredJob(),
        ),
      );

    expect(announced().map((j) => j.callId), ['call-1', 'call-2']);
  });

  test('carries the call arguments so the row can be labeled', () async {
    final reporter = JobReporter(requester: requester);
    addTearDown(reporter.dispose);

    reporter.watch(
      _entry(
        const ToolCallDefault(
          id: 'call-1',
          name: 'bash',
          arguments: {'command': 'sleep 30'},
        ),
        _DeferredJob(),
      ),
    );

    expect(announced().single.arguments, {'command': 'sleep 30'});
  });

  test('tracks equal call ids independently for different agents', () async {
    final manager = JobManager();
    addTearDown(manager.dispose);
    final first = _DeferredJob();
    final second = _DeferredJob();

    manager
      ..add(_entry(_call, first, agentId: 'agent-a'))
      ..add(_entry(_call, second, agentId: 'agent-b'));

    expect(manager.entries, hasLength(2));
    first.complete(const JobSucceeded('first'));
    await Future<void>.delayed(Duration.zero);
    expect(manager.entries.single.agentId, 'agent-b');
  });

  test(
    'reports a settled background job with remaining work for its agent',
    () async {
      final reporter = JobReporter(requester: requester);
      addTearDown(reporter.dispose);
      final first = _DeferredJob();
      final second = _DeferredJob();
      reporter
        ..watch(_entry(_call, first))
        ..watch(
          _entry(
            const ToolCallDefault(id: 'call-2', name: 'read', arguments: {}),
            second,
          ),
        );

      first.complete(const JobSucceeded('done'));
      await Future<void>.delayed(Duration.zero);

      final report = delivered().single;
      expect(report.callId, 'call-1');
      expect(report.outstanding, 1);
      expect(report.outcome, isA<JobSucceeded>());
    },
  );

  test('reports a canceled job so its waiter is told', () async {
    final reporter = JobReporter(requester: requester);
    addTearDown(reporter.dispose);
    final job = _DeferredJob();

    reporter.watch(_entry(_call, job));
    job.complete(const JobCanceled('stopped'));
    await Future<void>.delayed(Duration.zero);

    final report = delivered().single;
    expect(report.callId, 'call-1');
    expect(report.outcome, isA<JobCanceled>());
  });

  test('drops every report once the reporter is disposed', () async {
    final reporter = JobReporter(requester: requester);
    final job = _DeferredJob();
    reporter
      ..watch(_entry(_call, job))
      ..dispose();

    job.complete(const JobSucceeded('done'));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => requester.deliverReport(any()));
  });
}

JobEntry _entry(ToolCall call, Job job, {String agentId = 'agent'}) => JobEntry(
  call: call,
  conversationId: 'conversation',
  agentId: agentId,
  job: job,
);

final class _DeferredJob implements Job {
  final _settled = Completer<JobOutcome>();

  @override
  JobOutcome? get outcome => _settled.isCompleted ? _outcome : null;
  JobOutcome? _outcome;

  @override
  Future<String> get inBackground => Completer<String>().future;

  @override
  Future<JobOutcome> get settled => _settled.future;

  void complete(JobOutcome outcome) {
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() {}
}
