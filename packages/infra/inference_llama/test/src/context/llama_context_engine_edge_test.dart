import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context_engine.dart';
import 'package:inference_llama/src/context/llama_context_results.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/mocks.dart';

void main() {
  group('LlamaContextEngine edge cases', () {
    test('fails sequence operations for unacquired sequences', () {
      final engine = _engine();

      expect(engine.release(1), isA<ReleaseLlamaSequenceFailed>());
      expect(engine.clear(1), isA<ClearLlamaSequenceFailed>());
      expect(
        engine.setSampling(1, const EngineSampling(seed: 1)),
        isA<SetLlamaSamplingFailed>(),
      );
      expect(
        engine.removeRange(1, start: 0, end: 1),
        isA<RemoveLlamaSequenceRangeFailed>(),
      );
      expect(
        engine.stepBatch(
          StepRequest(
            prefills: [
              PrefillRequest(sequenceId: 1, tokens: Int64List.fromList([1])),
            ],
          ),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      expect(
        engine.stepBatch(
          const StepRequest(
            samples: [
              SampleRequest(
                logitsTicket: LogitsTicket(
                  sequenceId: 1,
                  position: 0,
                  batchIndex: 0,
                  generation: 0,
                ),
              ),
            ],
          ),
        ),
        isA<StepLlamaBatchFailed>(),
      );
    });

    test('release frees the sequence KV cells', () {
      final client = stubbedLlamaClient();
      when(() => client.sequencePositionMax(any(), any())).thenReturn(4);
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;

      expect(engine.release(id), isA<ReleaseLlamaSequenceSucceeded>());
      verify(
        () => client.removeSequenceRange(fakeContextHandle, id, -1, -1),
      ).called(1);
    });

    test('clear and release remove all sequence cells', () {
      final client = stubbedLlamaClient();
      when(() => client.sequencePositionMin(any(), any())).thenReturn(-1);
      when(() => client.sequencePositionMax(any(), any())).thenReturn(-1);
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;

      expect(engine.clear(id), isA<ClearLlamaSequenceSucceeded>());
      expect(engine.release(id), isA<ReleaseLlamaSequenceSucceeded>());
      verify(
        () => client.removeSequenceRange(fakeContextHandle, id, -1, -1),
      ).called(2);
    });

    test('rejects a sequence sampled more than once in one step', () {
      final engine = _engine();
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final prefilled =
          engine.stepBatch(
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
              as StepLlamaBatchSucceeded;
      final ticket = _ticket(prefilled.prefills.single);
      // A second sample for the same sequence: a distinct ticket key (so it
      // passes the reuse guard) but the same sequence id (so it trips the
      // duplicate-sequence guard).
      final duplicate = LogitsTicket(
        sequenceId: id,
        position: ticket.position,
        batchIndex: ticket.batchIndex + 1,
        generation: ticket.generation,
      );

      final result = engine.stepBatch(
        StepRequest(
          samples: [
            SampleRequest(logitsTicket: ticket),
            SampleRequest(logitsTicket: duplicate),
          ],
        ),
      );

      expect(result, isA<StepLlamaBatchFailed>());
    });

    test('maps edit, sampling, duplicate prefill, and decode failures', () {
      final client = stubbedLlamaClient();
      when(
        () => client.removeSequenceRange(any(), any(), any(), any()),
      ).thenReturn(false);
      when(() => client.decodeBatch(any(), any())).thenReturn(
        const LlamaDecodeFailed(
          message: 'decode failed',
          stackTrace: 'decode stack',
          backendCode: 7,
        ),
      );
      final engine = _engine(client: client);
      final acquired =
          engine.acquire(
                const SequenceRequest(sampling: EngineSampling(seed: 1)),
              )
              as AcquireLlamaSequenceSucceeded;
      final id = acquired.sequenceId;

      expect(
        engine.setSampling(id, const EngineSampling(seed: 2)),
        isA<SetLlamaSamplingSucceeded>(),
      );
      expect(engine.clear(id), isA<ClearLlamaSequenceFailed>());
      expect(
        engine.removeRange(id, start: 0, end: 1),
        isA<RemoveLlamaSequenceRangeFailed>(),
      );
      expect(
        engine.stepBatch(
          StepRequest(
            prefills: [
              PrefillRequest(sequenceId: id, tokens: Int64List.fromList([1])),
              PrefillRequest(sequenceId: id, tokens: Int64List.fromList([2])),
            ],
          ),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      expect(
        engine.stepBatch(
          StepRequest(
            prefills: [
              PrefillRequest(sequenceId: id, tokens: Int64List(0)),
            ],
          ),
        ),
        isA<StepLlamaBatchFailed>(),
      );

      final failed =
          engine.stepBatch(
                StepRequest(
                  prefills: [
                    PrefillRequest(
                      sequenceId: id,
                      tokens: Int64List.fromList([1]),
                    ),
                  ],
                ),
              )
              as StepLlamaBatchFailed;

      expect(failed.message, startsWith('decode failed'));
      expect(failed.message, contains('kv occupied'));
      expect(failed.backendCode, 7);

      final logitsEngine = _engine(client: client);
      final logitsId =
          (logitsEngine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final logitsFailed =
          logitsEngine.stepBatch(
                StepRequest(
                  prefills: [
                    PrefillRequest(
                      sequenceId: logitsId,
                      tokens: Int64List.fromList([1]),
                      retainLogits: true,
                    ),
                  ],
                ),
              )
              as StepLlamaBatchFailed;
      expect(logitsFailed.message, startsWith('decode failed'));
      expect(logitsFailed.backendCode, 7);

      final releaseEngine = _engine();
      final releaseId =
          (releaseEngine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      expect(
        releaseEngine.release(releaseId),
        isA<ReleaseLlamaSequenceSucceeded>(),
      );

      final disposing = stubbedLlamaClient();
      _engine(client: disposing)
        ..acquire(const SequenceRequest(sampling: EngineSampling(seed: 1)))
        ..dispose()
        ..dispose();
      verify(() => disposing.disposeContext(fakeContextHandle)).called(1);
    });

    test('detects reused and stale logits tickets', () {
      final engine = _engine();
      final acquired =
          engine.acquire(
                const SequenceRequest(sampling: EngineSampling(seed: 1)),
              )
              as AcquireLlamaSequenceSucceeded;
      final id = acquired.sequenceId;
      final prefilled =
          engine.stepBatch(
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
              as StepLlamaBatchSucceeded;
      final ticket =
          (prefilled.prefills.single as PrefillSequenceWithLogitsSucceeded)
              .logitsTicket;

      expect(
        engine.stepBatch(
          StepRequest(
            samples: [
              SampleRequest(logitsTicket: ticket),
              SampleRequest(logitsTicket: ticket),
            ],
          ),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchSucceeded>(),
      );
      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );

      final stale =
          engine.stepBatch(
                StepRequest(
                  prefills: [
                    PrefillRequest(
                      sequenceId: id,
                      tokens: Int64List.fromList([2]),
                      retainLogits: true,
                    ),
                  ],
                ),
              )
              as StepLlamaBatchSucceeded;
      final staleTicket =
          (stale.prefills.single as PrefillSequenceWithLogitsSucceeded)
              .logitsTicket;
      final notCurrentTicket = LogitsTicket(
        sequenceId: staleTicket.sequenceId,
        position: staleTicket.position + 1,
        batchIndex: staleTicket.batchIndex,
        generation: staleTicket.generation,
      );
      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: notCurrentTicket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );
      engine.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(sequenceId: id, tokens: Int64List.fromList([3])),
          ],
        ),
      );

      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: staleTicket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );
    });

    test('cancels prefill before mutation', () {
      final cancellation = IsolateCancellationTokenSource()..cancel();
      final client = stubbedLlamaClient();
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;

      final result = engine.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(sequenceId: id, tokens: Int64List.fromList([1])),
          ],
        ),
        cancellationToken: cancellation.token,
      );

      expect(result, isA<StepLlamaBatchFailed>());
      verifyNever(() => client.decodeBatch(any(), any()));
    });

    test('rejects prefill batches larger than nBatch before mutation', () {
      final cancellation = IsolateCancellationTokenSource();
      final client = stubbedLlamaClient();
      when(() => client.sequencePositionMax(any(), any())).thenReturn(-1);
      final engine = _engine(client: client, nBatch: 2);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;

      final result = engine.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: id,
              tokens: Int64List.fromList([1, 2, 3, 4]),
              retainLogits: true,
              samplerMode: PrefillSamplerMode.accept,
            ),
          ],
        ),
        cancellationToken: cancellation.token,
      );

      expect(result, isA<StepLlamaBatchFailed>());
      verifyNever(() => client.decodeBatch(any(), any()));
      verifyNever(() => client.acceptToken(any(), any()));
    });

    test(
      'finishes one prefill batch when cancellation is requested in decode',
      () {
        final cancellation = IsolateCancellationTokenSource();
        final positionMax = <SequenceId, int>{};
        final client = stubbedLlamaClient();
        when(() => client.sequencePositionMax(any(), any())).thenAnswer(
          (invocation) =>
              positionMax[invocation.positionalArguments[1] as int] ?? -1,
        );
        when(() => client.decodeBatch(any(), any())).thenAnswer((invocation) {
          final entries = invocation.positionalArguments[1] as List<BatchEntry>;
          for (final entry in entries) {
            positionMax[entry.seqId] = entry.pos;
          }
          cancellation.cancel();
          return const LlamaDecodeSucceeded();
        });
        final engine = _engine(client: client);
        final id =
            (engine.acquire(
                      const SequenceRequest(sampling: EngineSampling(seed: 1)),
                    )
                    as AcquireLlamaSequenceSucceeded)
                .sequenceId;

        final result =
            engine.stepBatch(
                  StepRequest(
                    prefills: [
                      PrefillRequest(
                        sequenceId: id,
                        tokens: Int64List.fromList([1, 2]),
                        retainLogits: true,
                        samplerMode: PrefillSamplerMode.accept,
                      ),
                    ],
                  ),
                  cancellationToken: cancellation.token,
                )
                as StepLlamaBatchSucceeded;

        expect(
          result.prefills.single,
          isA<PrefillSequenceWithLogitsSucceeded>(),
        );
        expect(acceptedTokens(client), [1, 2]);
      },
    );

    test('interleaves non-logits prefill entries across sequences', () {
      final client = stubbedLlamaClient();
      when(() => client.sequencePositionMax(any(), any())).thenReturn(-1);
      final engine = _engine(client: client);
      final first =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final second =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 2)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;

      final result = engine.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: first,
              tokens: Int64List.fromList([1, 2, 3]),
              retainLogits: true,
            ),
            PrefillRequest(
              sequenceId: second,
              tokens: Int64List.fromList([4, 5, 6]),
              retainLogits: true,
            ),
          ],
        ),
      );

      expect(result, isA<StepLlamaBatchSucceeded>());
      final batches = verify(
        () => client.decodeBatch(any(), captureAny()),
      ).captured.cast<List<BatchEntry>>();
      expect(
        batches.first.map((entry) => [entry.seqId, entry.token, entry.pos]),
        [
          [first, 1, 0],
          [second, 4, 0],
          [first, 2, 1],
          [second, 5, 1],
          [first, 3, 2],
          [second, 6, 2],
        ],
      );
    });

    test('cancels sample before mutation', () {
      final cancellation = IsolateCancellationTokenSource()..cancel();
      final client = stubbedLlamaClient();
      final engine = _engine(client: client);

      final result = engine.stepBatch(
        const StepRequest(
          samples: [
            SampleRequest(
              logitsTicket: LogitsTicket(
                sequenceId: 1,
                position: 1,
                batchIndex: 0,
                generation: 0,
              ),
            ),
          ],
        ),
        cancellationToken: cancellation.token,
      );

      expect(result, isA<StepLlamaBatchFailed>());
      verifyNever(() => client.sampleAt(any(), any(), any()));
    });

    test('maps sample decode failures', () {
      final decodes = [
        const LlamaDecodeSucceeded(),
        const LlamaDecodeFailed(
          message: 'sample decode failed',
          stackTrace: 'sample stack',
          backendCode: 9,
        ),
      ];
      final client = stubbedLlamaClient();
      when(
        () => client.decodeBatch(any(), any()),
      ).thenAnswer((_) => decodes.removeAt(0));
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final prefilled =
          engine.stepBatch(
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
              as StepLlamaBatchSucceeded;

      final result =
          engine.stepBatch(
                StepRequest(
                  samples: [
                    SampleRequest(
                      logitsTicket: _ticket(prefilled.prefills[0]),
                    ),
                  ],
                ),
              )
              as StepLlamaBatchFailed;

      expect(result.message, startsWith('sample decode failed'));
      expect(result.message, contains('kv occupied'));
      expect(result.backendCode, 9);
      verifyNever(() => client.acceptToken(any(), any()));
    });

    test('rejects consumed logits tickets after eog sample', () {
      final client = stubbedLlamaClient();
      when(() => client.isEndOfGeneration(any(), any())).thenReturn(true);
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final prefilled =
          engine.stepBatch(
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
              as StepLlamaBatchSucceeded;
      final ticket = _ticket(prefilled.prefills.single);

      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchSucceeded>(),
      );
      expect(acceptedTokens(client), [1]);
      expect(
        engine.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepLlamaBatchFailed>(),
      );
    });

    test('finishes sample critical section when cancellation is requested', () {
      final cancellation = IsolateCancellationTokenSource();
      final client = stubbedLlamaClient();
      when(() => client.sampleAt(any(), any(), any())).thenAnswer((_) {
        cancellation.cancel();
        return 9;
      });
      final engine = _engine(client: client);
      final id =
          (engine.acquire(
                    const SequenceRequest(sampling: EngineSampling(seed: 1)),
                  )
                  as AcquireLlamaSequenceSucceeded)
              .sequenceId;
      final prefilled =
          engine.stepBatch(
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
              as StepLlamaBatchSucceeded;
      final ticket =
          (prefilled.prefills.single as PrefillSequenceWithLogitsSucceeded)
              .logitsTicket;

      final result =
          engine.stepBatch(
                StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
                cancellationToken: cancellation.token,
              )
              as StepLlamaBatchSucceeded;

      final sample = result.samples.single as SampleSequenceToken;
      expect(sample.token, 9);
      expect(acceptedTokens(client), [9]);
    });
  });
}

LlamaContextEngine _engine({
  MockLlamaClientApi? client,
  int maxSequences = 2,
  int nBatch = 8,
}) {
  return LlamaContextEngine(
    client: client ?? stubbedLlamaClient(),
    model: fakeModelHandle,
    context: fakeContextHandle,
    envelope: fakeEnvelope(
      maxSequences: maxSequences,
      maxBatchTokens: nBatch,
    ),
  );
}

LogitsTicket _ticket(PrefillSequenceResult result) {
  return (result as PrefillSequenceWithLogitsSucceeded).logitsTicket;
}
