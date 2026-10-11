import 'dart:typed_data';

import 'package:engine_completions/engine_completions.dart';
import 'package:engine_completions/src/agent_sequence_session.dart';
import 'package:engine_completions/src/completion_turn.dart';
import 'package:engine_completions/src/stop_matcher.dart';
import 'package:engine_protocol/engine_protocol.dart';
import 'package:engine_scheduler/engine_scheduler.dart';
import 'package:engine_templates/engine_templates.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

final class _MockParser extends Mock implements StreamParserSession {}

final class _MockDetokenizer extends Mock implements Detokenizer {}

const _lease = SubagentLease(sequence: Sequence(id: 3), claimSize: 64);

final _materialized = SequenceMaterializeSucceeded(
  sequenceId: 3,
  positionMin: 0,
  positionMax: 3,
  materialization: SequenceMaterialization(
    tokens: Int64List(4),
    materializedTokenCount: 4,
    positionMax: 3,
    strategy: MaterializationStrategy.prefixReuse,
    reusedTokenCount: 2,
  ),
);

SequenceSampleSucceeded _token(int token) => SequenceSampleSucceeded(
  SampleSequenceToken(
    sequenceId: 3,
    token: token,
    position: 4,
    nextLogitsTicket: const LogitsTicket(
      sequenceId: 3,
      position: 4,
      batchIndex: 0,
      generation: 0,
    ),
  ),
);

const _stopped = SequenceSampleSucceeded(
  SampleSequenceStopped(sequenceId: 3, token: -1),
);

void main() {
  late _MockParser parser;
  late _MockDetokenizer detokenizer;
  late CallIdMinter callIdMinter;
  late EngineCompletionTurn turn;
  late List<EngineCompletionEvent> events;

  setUpAll(() {
    registerFallbackValue(const StreamChunk(text: '', tokenCountDelta: 0));
    registerFallbackValue(const DetokenizeRequest(token: 0));
  });

  EngineCompletionTurn buildTurn({
    int? maxTokens,
    List<String> stops = const [],
  }) {
    final built = EngineCompletionTurn(
      session: AgentSequenceSession(
        id: 'sub:a',
        lease: _lease,
        sampling: const EngineSampling(),
      ),
      prompt: Int64List.fromList([1, 2, 3, 4]),
      parser: parser,
      detokenizer: detokenizer,
      callIdMinter: callIdMinter,
      stops: StopMatcher(stops),
      maxTokens: maxTokens,
    );
    built.events.listen(events.add);
    return built;
  }

  void parses(List<ModelOutput> outputs) {
    when(() => parser.add(any())).thenReturn(outputs);
  }

  setUp(() {
    parser = _MockParser();
    detokenizer = _MockDetokenizer();
    callIdMinter = CallIdMinter(now: () => DateTime.utc(2026, 2));
    events = [];
    when(() => parser.add(any())).thenReturn(const []);
    when(() => parser.finish()).thenReturn(const []);
    when(
      () => detokenizer.detokenize(any()),
    ).thenReturn(DetokenizeSucceeded(Uint8List.fromList([0x61])));
    turn = buildTurn();
  });

  test('requests materialize and sample on its lease', () {
    expect(turn.materializeRequest.lease, same(_lease));
    expect(turn.materializeRequest.tokens, [1, 2, 3, 4]);
    expect(turn.sampleRequest.lease, same(_lease));
  });

  test('decodes once the prompt is materialized', () async {
    turn.acceptMaterialize(
      SequenceMaterializeAdvanced(
        sequenceId: 3,
        positionMin: 0,
        positionMax: 1,
        materialization: SequenceMaterialization(
          tokens: Int64List(4),
          materializedTokenCount: 2,
          positionMax: 1,
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        ),
      ),
    );
    expect(turn.phase, EngineCompletionTurnPhase.materializing);

    turn.acceptMaterialize(_materialized);
    expect(turn.phase, EngineCompletionTurnPhase.decoding);

    turn
      ..acceptSample(_token(0x61))
      ..acceptSample(_stopped);
    await pumpEventQueue();

    expect(
      (events.single as EngineCompletionFinished).usage,
      isA<EngineCompletionUsage>()
          .having((usage) => usage.promptTokens, 'prompt', 4)
          .having((usage) => usage.completionTokens, 'completion', 1)
          .having((usage) => usage.cachedTokens, 'cached', 2),
    );
  });

  test('routes reasoning, text, and tool calls to events', () async {
    parses(const [
      ModelReasoningDelta('think'),
      ModelReasoningDelta(''),
      ModelTextDelta('say'),
      ModelTextDelta(''),
      ModelTokensGenerated(1),
      ModelToolCallOutput(
        ToolCallDefault(id: 'x', name: 'read', arguments: {'path': 'a'}),
      ),
      ModelToolCallUnparsed(rawText: '{broken', name: 'write'),
      ModelToolCallUnparsed(rawText: '???'),
    ]);
    turn
      ..acceptMaterialize(_materialized)
      ..acceptSample(_token(0x61));
    parses(const []);
    turn.acceptSample(_stopped);
    await pumpEventQueue();

    expect(events, [
      isA<EngineCompletionReasoningDelta>().having(
        (delta) => delta.text,
        't',
        'think',
      ),
      isA<EngineCompletionTextDelta>().having(
        (delta) => delta.text,
        'text',
        'say',
      ),
      isA<EngineCompletionToolCalled>()
          .having((call) => call.id, 'id', startsWith('call_'))
          .having((call) => call.name, 'name', 'read')
          .having((call) => call.argumentsJson, 'args', '{"path":"a"}'),
      isA<EngineCompletionToolCalled>()
          .having((call) => call.name, 'name', 'write')
          .having((call) => call.argumentsJson, 'args', '{broken'),
      isA<EngineCompletionToolCalled>()
          .having((call) => call.name, 'name', 'unparsed_tool_call')
          .having((call) => call.argumentsJson, 'args', '???'),
      isA<EngineCompletionFinished>().having(
        (finished) => finished.reason,
        'reason',
        EngineCompletionStopReason.toolCalls,
      ),
    ]);
  });

  test('flushes the parser when the completion finishes', () async {
    when(() => parser.finish()).thenReturn(const [ModelTextDelta('tail')]);
    turn
      ..acceptMaterialize(_materialized)
      ..acceptSample(_stopped);
    await pumpEventQueue();

    expect(events.first, isA<EngineCompletionTextDelta>());
    expect(events.last, isA<EngineCompletionFinished>());
  });

  test('stops with a length reason at max tokens', () async {
    turn = buildTurn(maxTokens: 2)
      ..acceptMaterialize(_materialized)
      ..acceptSample(_token(0x61));
    expect(turn.phase, EngineCompletionTurnPhase.decoding);

    turn.acceptSample(_token(0x61));
    await pumpEventQueue();

    expect(turn.phase, EngineCompletionTurnPhase.settled);
    expect(
      (events.last as EngineCompletionFinished).reason,
      EngineCompletionStopReason.length,
    );
  });

  group('stop sequences', () {
    late List<String> parsed;

    setUp(() {
      parsed = [];
      when(() => parser.add(any())).thenAnswer((invocation) {
        parsed.add(
          (invocation.positionalArguments.single as StreamChunk).text,
        );
        return const [];
      });
      when(() => detokenizer.detokenize(any())).thenAnswer(
        (invocation) => DetokenizeSucceeded(
          Uint8List.fromList([
            (invocation.positionalArguments.single as DetokenizeRequest).token,
          ]),
        ),
      );
    });

    void say(EngineCompletionTurn turn, String text) {
      for (final unit in text.codeUnits) {
        if (turn.phase == EngineCompletionTurnPhase.settled) return;
        turn.acceptSample(_token(unit));
      }
    }

    test('end the completion before the stop, which is left out', () async {
      turn = buildTurn(stops: ['END'])..acceptMaterialize(_materialized);

      say(turn, 'abENDcd');
      await pumpEventQueue();

      expect(parsed.join(), 'ab');
      expect(turn.phase, EngineCompletionTurnPhase.settled);
      expect(
        events.last,
        isA<EngineCompletionFinished>()
            .having(
              (finished) => finished.reason,
              'reason',
              EngineCompletionStopReason.stop,
            )
            .having(
              (finished) => finished.usage.completionTokens,
              'completion tokens',
              5,
            ),
      );
    });

    test('release held text that turned out not to be a stop', () async {
      turn = buildTurn(stops: ['END'])..acceptMaterialize(_materialized);

      say(turn, 'aEN');
      expect(parsed.join(), 'a');
      turn.acceptSample(_stopped);
      await pumpEventQueue();

      expect(parsed.join(), 'aEN');
    });

    test('release held text when max tokens ends the completion', () {
      turn = buildTurn(stops: ['END'], maxTokens: 2)
        ..acceptMaterialize(_materialized);

      say(turn, 'aE');

      expect(parsed.join(), 'aE');
      expect(turn.phase, EngineCompletionTurnPhase.settled);
    });
  });

  group('a deferred materialize', () {
    for (final reason in [
      SequenceSchedulerDeferralReason.effectiveLimitReached,
      SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
    ]) {
      test('fails for context when ${reason.name}', () async {
        turn.acceptMaterialize(SequenceMaterializeDeferred(reason: reason));
        await pumpEventQueue();

        expect(
          events.single,
          isA<EngineCompletionFailed>().having(
            (failed) => failed.failure,
            'failure',
            EngineCompletionFailure.contextExceeded,
          ),
        );
      });
    }

    for (final reason in [
      SequenceSchedulerDeferralReason.logitsUnavailable,
      SequenceSchedulerDeferralReason.batchCapacityExhausted,
      SequenceSchedulerDeferralReason.backendBackpressure,
    ]) {
      test('retries when ${reason.name}', () {
        turn.acceptMaterialize(SequenceMaterializeDeferred(reason: reason));

        expect(turn.phase, EngineCompletionTurnPhase.materializing);
      });
    }
  });

  test('a failed materialize fails the engine', () async {
    turn.acceptMaterialize(
      const SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
      ),
    );
    await pumpEventQueue();

    expect(
      events.single,
      isA<EngineCompletionFailed>()
          .having(
            (failed) => failed.failure,
            'failure',
            EngineCompletionFailure.engineFailed,
          )
          .having((failed) => failed.message, 'message', 'backendFailure'),
    );
  });

  group('a deferred sample', () {
    setUp(() => turn.acceptMaterialize(_materialized));

    for (final reason in [
      SequenceSchedulerDeferralReason.effectiveLimitReached,
      SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
    ]) {
      test('stops for length when ${reason.name}', () async {
        turn.acceptSample(SequenceSampleDeferred(reason: reason));
        await pumpEventQueue();

        expect(
          (events.single as EngineCompletionFinished).reason,
          EngineCompletionStopReason.length,
        );
      });
    }

    test('materializes again when logits are unavailable', () {
      turn.acceptSample(
        const SequenceSampleDeferred(
          reason: SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );

      expect(turn.phase, EngineCompletionTurnPhase.materializing);
    });

    test('materializes the generated tokens too, keeping its cached count', () {
      turn
        ..acceptSample(_token(7))
        ..acceptSample(
          const SequenceSampleDeferred(
            reason: SequenceSchedulerDeferralReason.logitsUnavailable,
          ),
        );

      expect(turn.materializeRequest.tokens, [1, 2, 3, 4, 7]);

      turn
        ..acceptMaterialize(
          SequenceMaterializeSucceeded(
            sequenceId: 3,
            positionMin: 0,
            positionMax: 4,
            materialization: SequenceMaterialization(
              tokens: Int64List.fromList([1, 2, 3, 4, 7]),
              materializedTokenCount: 5,
              positionMax: 4,
              strategy: MaterializationStrategy.divergentReuse,
              reusedTokenCount: 4,
            ),
          ),
        )
        ..acceptSample(_stopped);

      expect(turn.phase, EngineCompletionTurnPhase.settled);
    });

    for (final reason in [
      SequenceSchedulerDeferralReason.batchCapacityExhausted,
      SequenceSchedulerDeferralReason.backendBackpressure,
    ]) {
      test('retries when ${reason.name}', () {
        turn.acceptSample(SequenceSampleDeferred(reason: reason));

        expect(turn.phase, EngineCompletionTurnPhase.decoding);
      });
    }
  });

  test('a failed sample fails the engine', () async {
    turn
      ..acceptMaterialize(_materialized)
      ..acceptSample(
        const SequenceSampleFailed(
          reason: SequenceSchedulerFailureReason.missingLogitsTicket,
        ),
      );
    await pumpEventQueue();

    expect(
      (events.single as EngineCompletionFailed).failure,
      EngineCompletionFailure.engineFailed,
    );
  });

  test('a token that cannot be detokenized fails the engine', () async {
    when(
      () => detokenizer.detokenize(any()),
    ).thenReturn(const DetokenizeFailed(message: 'bad token', stackTrace: ''));
    turn
      ..acceptMaterialize(_materialized)
      ..acceptSample(_token(9));
    await pumpEventQueue();

    expect(
      events.single,
      isA<EngineCompletionFailed>().having(
        (failed) => failed.message,
        'message',
        'bad token',
      ),
    );
  });

  test('settles once, ignoring anything after', () async {
    turn
      ..fail(EngineCompletionFailure.cancelled, 'closed')
      ..fail(EngineCompletionFailure.engineFailed, 'late');
    await pumpEventQueue();

    expect(events, hasLength(1));
  });

  test('cancelling the subscription settles the turn', () async {
    final cancelled = EngineCompletionTurn(
      session: AgentSequenceSession(
        id: 'sub:a',
        lease: _lease,
        sampling: const EngineSampling(),
      ),
      prompt: Int64List(0),
      parser: parser,
      detokenizer: detokenizer,
      callIdMinter: callIdMinter,
      stops: StopMatcher(const []),
      maxTokens: null,
    );
    await cancelled.events.listen((_) {}).cancel();

    expect(cancelled.phase, EngineCompletionTurnPhase.settled);
  });
}
