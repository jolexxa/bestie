import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context_engine.dart';
import 'package:inference_llama/src/context/llama_context_results.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';
import '../../fixtures/mocks.dart';

void main() {
  group('LlamaContextEngine.stepBatch', () {
    test('advances samples and prefills in a single decode', () {
      final harness = _StepHarness();
      final engine = harness.engine;
      final a = harness.acquire();
      final b = harness.acquire();

      final prefilled =
          engine.stepBatch(
                StepRequest(
                  prefills: [
                    PrefillRequest(
                      sequenceId: a,
                      tokens: Int64List.fromList([1, 2, 3]),
                      retainLogits: true,
                    ),
                    PrefillRequest(
                      sequenceId: b,
                      tokens: Int64List.fromList([4, 5]),
                      retainLogits: true,
                    ),
                  ],
                ),
              )
              as StepLlamaBatchSucceeded;

      expect(harness.decodeCount, 1);
      final aTicket = _prefillTicket(prefilled.prefills[0]);
      final bTicket = _prefillTicket(prefilled.prefills[1]);
      expect(aTicket.generation, bTicket.generation);

      final sampled =
          engine.stepBatch(
                StepRequest(
                  samples: [
                    SampleRequest(logitsTicket: aTicket),
                    SampleRequest(logitsTicket: bTicket),
                  ],
                ),
              )
              as StepLlamaBatchSucceeded;

      expect(harness.decodeCount, 2);
      final aToken = sampled.samples[0] as SampleSequenceToken;
      final bToken = sampled.samples[1] as SampleSequenceToken;
      expect(
        aToken.nextLogitsTicket.generation,
        bToken.nextLogitsTicket.generation,
      );
    });

    test(
      'sampling and prefilling in one step never staleness the sampled seq',
      () {
        final harness = _StepHarness();
        final engine = harness.engine;
        final a = harness.acquire();
        final b = harness.acquire();

        final aTicket = _prefillTicket(
          (engine.stepBatch(
                    StepRequest(
                      prefills: [
                        PrefillRequest(
                          sequenceId: a,
                          tokens: Int64List.fromList([1]),
                          retainLogits: true,
                        ),
                      ],
                    ),
                  )
                  as StepLlamaBatchSucceeded)
              .prefills
              .single,
        );

        final step =
            engine.stepBatch(
                  StepRequest(
                    samples: [SampleRequest(logitsTicket: aTicket)],
                    prefills: [
                      PrefillRequest(
                        sequenceId: b,
                        tokens: Int64List.fromList([7, 8]),
                        retainLogits: true,
                      ),
                    ],
                  ),
                )
                as StepLlamaBatchSucceeded;

        final decodesAfterStep = harness.decodeCount;
        final aNext =
            (step.samples.single as SampleSequenceToken).nextLogitsTicket;
        final bTicket = _prefillTicket(step.prefills.single);
        expect(aNext.generation, bTicket.generation);

        expect(
          engine.stepBatch(
            StepRequest(samples: [SampleRequest(logitsTicket: aNext)]),
          ),
          isA<StepLlamaBatchSucceeded>(),
        );
        expect(harness.decodeCount, decodesAfterStep + 1);
      },
    );

    test('slot exhaustion preserves sampled tickets for retry', () {
      final harness = _StepHarness();
      final engine = harness.engine;
      final id = harness.acquire();
      final ticket = _prefillTicket(
        (engine.stepBatch(
                  StepRequest(
                    prefills: [
                      PrefillRequest(
                        sequenceId: id,
                        tokens: Int64List.fromList([1]),
                        retainLogits: true,
                      ),
                    ],
                  ),
                )
                as StepLlamaBatchSucceeded)
            .prefills
            .single,
      );
      harness.decodeResults.add(
        const LlamaDecodeFailed(
          message: 'no slot',
          stackTrace: '',
          backendCode: decodeKvSlotUnavailableBackendCode,
        ),
      );

      final failed = engine.stepBatch(
        StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
      );

      expect(failed, isA<StepLlamaBatchFailed>());
      verifyNever(() => harness.client.acceptToken(any(), any()));
      expect(harness.bindings.samplerCloneCalls, 1);
      expect(harness.bindings.samplerFreeCalls, 1);

      final retried =
          engine.stepBatch(
                StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
              )
              as StepLlamaBatchSucceeded;

      expect(retried.samples.single, isA<SampleSequenceToken>());
      expect(acceptedTokens(harness.client), [50]);
      expect(harness.bindings.samplerCloneCalls, 2);
      expect(harness.bindings.samplerFreeCalls, 2);
    });

    test('non-recoverable decode failure invalidates sampled tickets', () {
      const nonRecoverableBackendCode = 7;
      final harness = _StepHarness();
      final engine = harness.engine;
      final id = harness.acquire();
      final ticket = _prefillTicket(
        (engine.stepBatch(
                  StepRequest(
                    prefills: [
                      PrefillRequest(
                        sequenceId: id,
                        tokens: Int64List.fromList([1]),
                        retainLogits: true,
                      ),
                    ],
                  ),
                )
                as StepLlamaBatchSucceeded)
            .prefills
            .single,
      );
      harness.decodeResults.add(
        const LlamaDecodeFailed(
          message: 'decode failed',
          stackTrace: '',
          backendCode: nonRecoverableBackendCode,
        ),
      );

      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      final decodesAfterFailure = harness.decodeCount;

      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      expect(harness.decodeCount, decodesAfterFailure);
      verifyNever(() => harness.client.acceptToken(any(), any()));
    });

    test('end-of-generation sample yields no continuation and no decode', () {
      final harness = _StepHarness(endOfGeneration: true);
      final engine = harness.engine;
      final a = harness.acquire();
      final aTicket = _prefillTicket(
        (engine.stepBatch(
                  StepRequest(
                    prefills: [
                      PrefillRequest(
                        sequenceId: a,
                        tokens: Int64List.fromList([1]),
                        retainLogits: true,
                      ),
                    ],
                  ),
                )
                as StepLlamaBatchSucceeded)
            .prefills
            .single,
      );
      final decodesBefore = harness.decodeCount;

      final step =
          engine.stepBatch(
                StepRequest(samples: [SampleRequest(logitsTicket: aTicket)]),
              )
              as StepLlamaBatchSucceeded;

      expect(step.samples.single, isA<SampleSequenceStopped>());
      expect(harness.decodeCount, decodesBefore);
    });

    test('rejects a step batch larger than nBatch before mutation', () {
      final harness = _StepHarness(nBatch: 2);
      final engine = harness.engine;
      final a = harness.acquire();
      final decodesBefore = harness.decodeCount;

      final result = engine.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: a,
              tokens: Int64List.fromList([1, 2, 3, 4]),
              retainLogits: true,
            ),
          ],
        ),
      );

      expect(result, isA<StepLlamaBatchFailed>());
      expect(harness.decodeCount, decodesBefore);
    });

    test('rejects a sequence that both samples and prefills in one step', () {
      final harness = _StepHarness();
      final engine = harness.engine;
      final a = harness.acquire();
      final aTicket = _prefillTicket(
        (engine.stepBatch(
                  StepRequest(
                    prefills: [
                      PrefillRequest(
                        sequenceId: a,
                        tokens: Int64List.fromList([1]),
                        retainLogits: true,
                      ),
                    ],
                  ),
                )
                as StepLlamaBatchSucceeded)
            .prefills
            .single,
      );

      final result = engine.stepBatch(
        StepRequest(
          samples: [SampleRequest(logitsTicket: aTicket)],
          prefills: [
            PrefillRequest(
              sequenceId: a,
              tokens: Int64List.fromList([2]),
              retainLogits: true,
            ),
          ],
        ),
      );

      expect(result, isA<StepLlamaBatchFailed>());
    });
  });
}

final class _StepHarness {
  _StepHarness({
    bool endOfGeneration = false,
    int maxSequences = 3,
    int nBatch = 8,
  }) {
    bindings = FakeLlamaCppBindings();
    client = stubbedLlamaClient(bindings: bindings);
    when(() => client.sequencePositionMax(any(), any())).thenAnswer(
      (invocation) =>
          _positionMax[invocation.positionalArguments[1] as int] ?? -1,
    );
    when(() => client.sampleAt(any(), any(), any())).thenReturn(50);
    when(
      () => client.isEndOfGeneration(any(), any()),
    ).thenReturn(endOfGeneration);
    when(() => client.decodeBatch(any(), any())).thenAnswer((invocation) {
      decodeCount += 1;
      final result = decodeResults.isEmpty
          ? const LlamaDecodeSucceeded()
          : decodeResults.removeAt(0);
      if (result is LlamaDecodeFailed) return result;
      final entries = invocation.positionalArguments[1] as List<BatchEntry>;
      for (final entry in entries) {
        _positionMax[entry.seqId] = entry.pos;
      }
      return result;
    });
    engine = LlamaContextEngine(
      client: client,
      model: fakeModelHandle,
      context: fakeContextHandle,
      envelope: fakeEnvelope(
        maxSequences: maxSequences,
        maxBatchTokens: nBatch,
      ),
    );
  }

  final _positionMax = <SequenceId, int>{};
  final decodeResults = <LlamaDecodeResult>[];
  late final MockLlamaClientApi client;
  late final FakeLlamaCppBindings bindings;
  late final LlamaContextEngine engine;
  int decodeCount = 0;

  SequenceId acquire() {
    return (engine.acquire(
              const SequenceRequest(sampling: EngineSampling(seed: 1)),
            )
            as AcquireLlamaSequenceSucceeded)
        .sequenceId;
  }
}

LogitsTicket _prefillTicket(PrefillSequenceResult result) {
  return (result as PrefillSequenceWithLogitsSucceeded).logitsTicket;
}
