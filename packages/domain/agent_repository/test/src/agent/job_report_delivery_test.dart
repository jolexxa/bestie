import 'dart:async';

import 'package:agent_repository/src/agent/agent_session.dart';
import 'package:agent_repository/src/agent/subagent_report_delivery.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

final class _MockAgentSession extends Mock implements AgentSession {}

Future<void> _pump([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

DeliveredJobReport _report(String id, {int outstanding = 0}) =>
    DeliveredJobReport.fromJobReport(
      JobReport(
        conversationId: 'conversation',
        agentId: 'primary',
        callId: id,
        toolName: 'shell',
        arguments: const {},
        outcome: Job.done(id).outcome!,
        outstanding: outstanding,
      ),
    );

void main() {
  setUpAll(() => registerFallbackValue(<DeliveredJobReport>[]));

  late _MockAgentSession agent;
  late JobReportDeliveryLogic logic;
  var accepted = true;

  setUp(() {
    accepted = true;
    agent = _MockAgentSession();
    when(
      () => agent.beginDeliveryTurn(any()),
    ).thenAnswer((_) async => accepted);
    logic = JobReportDeliveryLogic()..start();
  });

  tearDown(() => logic.dispose());

  test('starts idle', () {
    expect(logic.value, isA<IdleDeliveryState>());
  });

  test('delivers a settled report to a bound agent immediately', () async {
    logic
      ..input(AgentBound(agent))
      ..input(JobReportSettled(_report('a')));
    await _pump();

    final captured = verify(
      () => agent.beginDeliveryTurn(captureAny()),
    ).captured;
    expect((captured.single as List<DeliveredJobReport>).single.callId, 'a');
    expect(logic.value, isA<IdleDeliveryState>());
  });

  test('buffers a rejected batch until the next idle edge', () async {
    accepted = false;
    logic
      ..input(AgentBound(agent))
      ..input(JobReportSettled(_report('a')));
    await _pump();
    expect(logic.value, isA<AwaitingIdleState>());

    accepted = true;
    logic.input(const AgentIdled());
    await _pump();

    verify(() => agent.beginDeliveryTurn(any())).called(2);
    expect(logic.value, isA<IdleDeliveryState>());
  });

  test('coalesces reports buffered while the agent is unavailable', () async {
    logic
      ..input(JobReportSettled(_report('a', outstanding: 1)))
      ..input(JobReportSettled(_report('b')));
    await _pump();

    logic.input(AgentBound(agent));
    await _pump();

    final captured = verify(
      () => agent.beginDeliveryTurn(captureAny()),
    ).captured;
    expect(
      (captured.single as List<DeliveredJobReport>).map(
        (report) => report.callId,
      ),
      ['a', 'b'],
    );
  });

  test(
    'retries a buffered report when the addressed session is rebound',
    () async {
      final replacement = _MockAgentSession();
      when(
        () => replacement.beginDeliveryTurn(any()),
      ).thenAnswer((_) async => true);
      accepted = false;
      logic
        ..input(AgentBound(agent))
        ..input(JobReportSettled(_report('a')));
      await _pump();
      expect(logic.value, isA<AwaitingIdleState>());

      logic.input(AgentBound(replacement));
      await _pump();

      verify(() => replacement.beginDeliveryTurn(any())).called(1);
      expect(logic.value, isA<IdleDeliveryState>());
    },
  );

  test(
    'holds a report that settles during delivery for the next window',
    () async {
      final gate = Completer<bool>();
      when(() => agent.beginDeliveryTurn(any())).thenAnswer((_) => gate.future);
      logic
        ..input(AgentBound(agent))
        ..input(JobReportSettled(_report('a', outstanding: 1)))
        ..input(JobReportSettled(_report('b')));

      expect(logic.value, isA<DeliveringState>());
      gate.complete(true);
      await _pump();
      expect(logic.value, isA<AwaitingIdleState>());

      logic.input(const AgentIdled());
      await _pump();
      final captured = verify(
        () => agent.beginDeliveryTurn(captureAny()),
      ).captured;
      expect((captured.first as List<DeliveredJobReport>).single.callId, 'a');
      expect((captured.last as List<DeliveredJobReport>).single.callId, 'b');
    },
  );
}
