import 'dart:async';

import 'package:agent_repository/src/agent/agent_session.dart';
import 'package:agent_repository/src/agent/subagent_report_delivery.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

final class _Session extends Mock implements AgentSession {}

DeliveredJobReport _report(String callId) => DeliveredJobReport.fromJobReport(
  JobReport(
    conversationId: 'conversation',
    agentId: 'agent',
    callId: callId,
    toolName: 'shell',
    arguments: const {},
    outcome: Job.done('done').outcome!,
    outstanding: 0,
  ),
);

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() => registerFallbackValue(<DeliveredJobReport>[]));

  test(
    'delivers a settled background report to an idle addressed session',
    () async {
      final session = _Session();
      when(
        () => session.beginDeliveryTurn(any()),
      ).thenAnswer((_) async => true);
      final logic = JobReportDeliveryLogic()..start();
      addTearDown(logic.dispose);

      logic
        ..input(AgentBound(session))
        ..input(JobReportSettled(_report('call')));
      await _pump();
      await _pump();

      final batches = verify(
        () => session.beginDeliveryTurn(captureAny()),
      ).captured;
      expect(
        (batches.single as List<DeliveredJobReport>).single.callId,
        'call',
      );
    },
  );

  test('buffers reports until a session is bound', () async {
    final session = _Session();
    when(() => session.beginDeliveryTurn(any())).thenAnswer((_) async => true);
    final logic = JobReportDeliveryLogic()..start();
    addTearDown(logic.dispose);

    logic.input(JobReportSettled(_report('call')));
    await _pump();
    expect(logic.value, isA<AwaitingIdleState>());

    logic.input(AgentBound(session));
    await _pump();
    await _pump();
    verify(() => session.beginDeliveryTurn(any())).called(1);
  });

  test('rebinds the addressed session while a delivery is in flight', () async {
    final first = _Session();
    final second = _Session();
    final firstResult = Completer<bool>();
    when(
      () => first.beginDeliveryTurn(any()),
    ).thenAnswer((_) => firstResult.future);
    when(() => second.beginDeliveryTurn(any())).thenAnswer((_) async => true);
    final logic = JobReportDeliveryLogic()..start();
    addTearDown(logic.dispose);

    logic
      ..input(AgentBound(first))
      ..input(JobReportSettled(_report('one')));
    await _pump();
    logic.input(AgentBound(second));
    firstResult.complete(false);
    await _pump();
    logic.input(const AgentIdled());
    await _pump();

    verify(() => second.beginDeliveryTurn(any())).called(1);
  });
}
