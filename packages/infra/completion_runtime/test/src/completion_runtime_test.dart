import 'dart:typed_data';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockAllocator extends Mock implements Allocator {}

final class _MockScheduler extends Mock implements SequenceScheduler {}

final class _MockTokenizer extends Mock implements Detokenizer {}

const _sampling = EngineSampling();
const _lease = PrimaryLease(sequence: Sequence(id: 1), fullLimit: 256);

void main() {
  late _MockAllocator allocator;
  late _MockScheduler scheduler;
  late _MockTokenizer tokenizer;
  late ScheduledCompletionRuntime runtime;

  setUpAll(() {
    registerFallbackValue(const TokenizeRequest(text: ''));
    registerFallbackValue(_lease);
    registerFallbackValue(_sampling);
  });

  setUp(() {
    allocator = _MockAllocator();
    scheduler = _MockScheduler();
    tokenizer = _MockTokenizer();
    when(() => allocator.contextSize).thenReturn(256);
    when(() => allocator.maxSequences).thenReturn(2);
    when(
      () => allocator.reservePrimary(sampling: any(named: 'sampling')),
    ).thenReturn(const ReservePrimarySucceeded(_lease));
    when(() => scheduler.effectiveLimitFor(any())).thenReturn(256);
    when(() => scheduler.cachedTokenCountFor(any())).thenReturn(null);
    when(
      () => tokenizer.tokenize(any()),
    ).thenReturn(TokenizeSucceeded(Int64List(8)));
    runtime = ScheduledCompletionRuntime(
      allocator: allocator,
      scheduler: scheduler,
      tokenizer: tokenizer,
      profile: ModelProfiles.qwen3,
      defaultSampling: _sampling,
    );
  });

  Future<CompletionStart> complete() => runtime.complete(
    const CompletionRequest(
      agentId: 'primary:1',
      messages: [PromptUserMessage('hi')],
      reasoningMode: 'off',
      sampling: _sampling,
    ),
  );

  test('reports its context size and agent count', () async {
    expect(runtime.contextSize, 256);
    expect(runtime.maxAgents, 2);
  });

  test('a backend failure to lease answers failed', () async {
    when(
      () => allocator.reservePrimary(sampling: any(named: 'sampling')),
    ).thenReturn(
      const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.schedulerFailure,
      ),
    );

    expect(
      await runtime.openPrimary('primary:1'),
      isA<AgentLeaseFailed>().having(
        (failed) => failed.message,
        'message',
        'schedulerFailure',
      ),
    );
  });

  test('an invalid claim answers insufficient claim', () async {
    when(
      () => allocator.reserveSubagent(
        contextSize: any(named: 'contextSize'),
        sampling: any(named: 'sampling'),
      ),
    ).thenReturn(
      const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.invalidClaimSize,
      ),
    );

    expect(
      await runtime.openSubagent('sub:a'),
      isA<AgentLeaseInsufficientClaim>(),
    );
  });

  test('a prompt that cannot be tokenized is rejected', () async {
    when(
      () => tokenizer.tokenize(any()),
    ).thenReturn(const TokenizeFailed(message: 'no vocab', stackTrace: ''));
    await runtime.openPrimary('primary:1');

    expect(
      await complete(),
      isA<CompletionRejected>()
          .having(
            (rejected) => rejected.reason,
            'reason',
            CompletionRejection.promptUnreadable,
          )
          .having((rejected) => rejected.message, 'message', 'no vocab'),
    );
  });

  test('a step that drops the completion fails it', () async {
    when(
      () => scheduler.stepBatch(
        samples: any(named: 'samples'),
        materializes: any(named: 'materializes'),
      ),
    ).thenReturn(const SequenceStepResults(samples: {}, materializes: {}));
    await runtime.openPrimary('primary:1');

    final events = await (await complete() as CompletionStarted).events
        .toList();

    expect(
      events.single,
      isA<CompletionFailed>()
          .having(
            (failed) => failed.failure,
            'failure',
            CompletionFailure.engineFailed,
          )
          .having((failed) => failed.message, 'message', 'missingBatchResult'),
    );
  });

  test('a step that drops a decoding completion fails it', () async {
    when(
      () => scheduler.stepBatch(
        samples: any(named: 'samples'),
        materializes: any(named: 'materializes'),
      ),
    ).thenAnswer((invocation) {
      final materializes =
          invocation.namedArguments[#materializes]
              as List<SequenceMaterializeRequest>;
      return SequenceStepResults(
        samples: const {},
        materializes: {
          for (final request in materializes)
            request.lease: SequenceMaterializeSucceeded(
              sequenceId: 1,
              positionMin: 0,
              positionMax: 7,
              materialization: SequenceMaterialization(
                tokens: request.tokens,
                materializedTokenCount: request.tokens.length,
                positionMax: 7,
                strategy: MaterializationStrategy.fullPrefill,
                reusedTokenCount: 0,
              ),
            ),
        },
      );
    });
    await runtime.openPrimary('primary:1');

    final events = await (await complete() as CompletionStarted).events
        .toList();

    expect(
      (events.single as CompletionFailed).failure,
      CompletionFailure.engineFailed,
    );
  });

  test('a sampler the backend cannot rebuild rejects the completion', () async {
    when(() => scheduler.setSampling(any(), any())).thenReturn(
      const SequenceSetSamplingFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
      ),
    );
    await runtime.openPrimary('primary:1');

    final started = await runtime.complete(
      const CompletionRequest(
        agentId: 'primary:1',
        messages: [PromptUserMessage('hi')],
        reasoningMode: 'off',
        sampling: EngineSampling(temperature: 0.1),
      ),
    );

    expect(
      started,
      isA<CompletionRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        CompletionRejection.engineFailed,
      ),
    );
    when(
      () => scheduler.setSampling(any(), any()),
    ).thenReturn(const SequenceSetSamplingSucceeded());
    when(
      () => scheduler.stepBatch(
        samples: any(named: 'samples'),
        materializes: any(named: 'materializes'),
      ),
    ).thenReturn(const SequenceStepResults(samples: {}, materializes: {}));
    await (await runtime.complete(
              const CompletionRequest(
                agentId: 'primary:1',
                messages: [PromptUserMessage('hi')],
                reasoningMode: 'off',
                sampling: EngineSampling(temperature: 0.1),
              ),
            )
            as CompletionStarted)
        .events
        .drain<void>();
    verify(() => scheduler.setSampling(any(), any())).called(2);
  });

  test('a step that throws fails every live completion', () async {
    when(
      () => scheduler.stepBatch(
        samples: any(named: 'samples'),
        materializes: any(named: 'materializes'),
      ),
    ).thenThrow(StateError('the context fell over'));
    await runtime.openPrimary('primary:1');

    final events = await (await complete() as CompletionStarted).events
        .toList();

    expect(
      events.single,
      isA<CompletionFailed>()
          .having(
            (failed) => failed.failure,
            'failure',
            CompletionFailure.engineFailed,
          )
          .having(
            (failed) => failed.message,
            'message',
            contains('the context fell over'),
          ),
    );
    expect(await complete(), isA<CompletionStarted>());
  });
}
