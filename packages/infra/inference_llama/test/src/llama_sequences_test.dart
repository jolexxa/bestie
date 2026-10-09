import 'dart:ffi';
import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/model/model.dart';
import 'package:inference_llama/src/models.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../fixtures/fake_bindings.dart';
import '../fixtures/mocks.dart';

void main() {
  group('Llama backend', () {
    late FakeLlamaCppBindings bindings;
    late LlamaModel model;
    late Context context;
    late List<List<_DecodedEntry>> decoded;

    setUp(() async {
      bindings = FakeLlamaCppBindings();
      decoded = [];
      bindings.decodeImpl = (_, batch) {
        decoded.add(_entries(batch));
        return 0;
      };
      model = await _loadModel(bindings);
      final created = await model.createContext(_contextRequest());
      context = (created as LlamaCreateContextSucceeded).context;
    });

    test('reports the envelope limits through the backend', () {
      final backend = context.sequences;

      expect(backend.maxSequences, bindings.contextParams.n_seq_max);
      expect(backend.maxBatchTokens, bindings.contextParams.n_batch);
    });

    test('sizes the repetition penalty by the model vocabulary', () async {
      bindings.vocabularySize = 151936;
      final created = await model.createContext(_contextRequest());

      (created as LlamaCreateContextSucceeded).context.sequences.acquire(
        const SequenceRequest(sampling: EngineSampling(penaltyRepeat: 1.1)),
      );

      expect(bindings.lastPenaltiesVocabularySize, 151936);
    });

    test('acquires and reuses sequence slots', () async {
      final backend = context.sequences;
      final first = _acquire(backend);
      expect(first.id, 0);

      final second = _acquire(backend);
      expect(second.id, 1);
      final third = _acquire(backend);
      expect(third.id, 2);

      expect(
        backend.acquire(_sequenceRequest()),
        isA<RequestSequenceFailed>(),
      );
      expect(
        backend.release(second.id),
        isA<ReleaseSequenceSucceeded>(),
      );
      final reused = backend.acquire(_sequenceRequest());
      expect((reused as RequestSequenceSucceeded).sequence.id, second.id);
    });

    test(
      'prefills multiple sequences and samples next tokens from tickets',
      () async {
        final backend = context.sequences;
        final first = _acquire(backend);
        final second = _acquire(backend);
        bindings
          ..posMax = 4
          ..samplerSampleResults.addAll([30, 31]);

        final prefill = backend.stepBatch(
          StepRequest(
            prefills: [
              PrefillRequest(
                sequenceId: first.id,
                tokens: Int64List.fromList([10, 11, 12]),
                retainLogits: true,
                samplerMode: PrefillSamplerMode.accept,
              ),
              PrefillRequest(
                sequenceId: second.id,
                tokens: Int64List.fromList([20, 21]),
                retainLogits: true,
                samplerMode: PrefillSamplerMode.accept,
              ),
            ],
          ),
        );
        final prefillSuccess = prefill as StepBatchSucceeded;

        final result = backend.stepBatch(
          StepRequest(
            samples: [
              SampleRequest(logitsTicket: _ticket(prefillSuccess.prefills[0])),
              SampleRequest(logitsTicket: _ticket(prefillSuccess.prefills[1])),
            ],
          ),
        );

        expect(result, isA<StepBatchSucceeded>());
        final success = result as StepBatchSucceeded;
        expect(success.samples, hasLength(2));
        expect(success.samples[0], isA<SampleSequenceToken>());
        expect((success.samples[0] as SampleSequenceToken).token, 30);
        expect((success.samples[0] as SampleSequenceToken).position, 8);
        expect((success.samples[1] as SampleSequenceToken).token, 31);
        expect((success.samples[1] as SampleSequenceToken).position, 7);
        expect(bindings.samplerAcceptCalls, 7);
        expect(bindings.samplerSampleIndexes, [4, 3]);
        expect(decoded, hasLength(2));
        expect(decoded[0], [
          _DecodedEntry(token: 10, pos: 5, seqId: first.id, logits: false),
          _DecodedEntry(token: 20, pos: 5, seqId: second.id, logits: false),
          _DecodedEntry(token: 11, pos: 6, seqId: first.id, logits: false),
          _DecodedEntry(token: 21, pos: 6, seqId: second.id, logits: true),
          _DecodedEntry(token: 12, pos: 7, seqId: first.id, logits: true),
        ]);
        expect(decoded[1], [
          _DecodedEntry(token: 30, pos: 8, seqId: first.id, logits: true),
          _DecodedEntry(token: 31, pos: 7, seqId: second.id, logits: true),
        ]);
      },
    );

    test('prefill and sample advance only requested sequences', () async {
      final backend = context.sequences;
      final firstSequence = _acquire(backend);
      final secondSequence = _acquire(backend);
      bindings.samplerSampleResults.addAll([41, 42, 43]);

      final firstPrefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: firstSequence.id,
              tokens: Int64List.fromList([10]),
              retainLogits: true,
              samplerMode: PrefillSamplerMode.accept,
            ),
            PrefillRequest(
              sequenceId: secondSequence.id,
              tokens: Int64List.fromList([20]),
              retainLogits: true,
              samplerMode: PrefillSamplerMode.accept,
            ),
          ],
        ),
      );
      final firstPrefillSuccess = firstPrefill as StepBatchSucceeded;
      final first = backend.stepBatch(
        StepRequest(
          samples: [
            SampleRequest(
              logitsTicket: _ticket(firstPrefillSuccess.prefills[0]),
            ),
            SampleRequest(
              logitsTicket: _ticket(firstPrefillSuccess.prefills[1]),
            ),
          ],
        ),
      );
      final firstSuccess = first as StepBatchSucceeded;
      final aToken = firstSuccess.samples[0] as SampleSequenceToken;
      final bToken = firstSuccess.samples[1] as SampleSequenceToken;
      expect(aToken.token, 41);
      expect(bToken.token, 42);

      decoded.clear();
      bindings.posMax = 9;

      final prefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: secondSequence.id,
              tokens: Int64List.fromList([bToken.token]),
              retainLogits: true,
              samplerMode: PrefillSamplerMode.accept,
            ),
          ],
        ),
      );
      final prefillSuccess = prefill as StepBatchSucceeded;

      final result = backend.stepBatch(
        StepRequest(
          samples: [
            SampleRequest(
              logitsTicket: _ticket(prefillSuccess.prefills.single),
            ),
          ],
        ),
      );

      expect(result, isA<StepBatchSucceeded>());
      final success = result as StepBatchSucceeded;
      expect(success.samples, hasLength(1));
      final token = success.samples.single as SampleSequenceToken;
      expect(token.sequenceId, secondSequence.id);
      expect(token.token, 43);
      expect(token.position, 11);
      expect(decoded, [
        [
          _DecodedEntry(
            token: 42,
            pos: 10,
            seqId: secondSequence.id,
            logits: true,
          ),
        ],
        [
          _DecodedEntry(
            token: 43,
            pos: 11,
            seqId: secondSequence.id,
            logits: true,
          ),
        ],
      ]);
    });

    test(
      'sample returns eog token without requiring a follow-up append',
      () async {
        final backend = context.sequences;
        final sequence = _acquire(backend);
        bindings
          ..samplerSampleResult = 2
          ..vocabIsEogImpl = (_, token) => token == 2;

        final prefill = backend.stepBatch(
          StepRequest(
            prefills: [
              PrefillRequest(
                sequenceId: sequence.id,
                tokens: Int64List.fromList([10]),
                retainLogits: true,
                samplerMode: PrefillSamplerMode.accept,
              ),
            ],
          ),
        );
        final prefillSuccess = prefill as StepBatchSucceeded;

        final result = backend.stepBatch(
          StepRequest(
            samples: [
              SampleRequest(
                logitsTicket: _ticket(prefillSuccess.prefills.single),
              ),
            ],
          ),
        );

        final success = result as StepBatchSucceeded;
        expect(success.samples.single, isA<SampleSequenceStopped>());
        expect(decoded.single, [
          _DecodedEntry(token: 10, pos: 1, seqId: sequence.id, logits: true),
        ]);
      },
    );

    test('step returns a batch failure when decode fails', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);
      bindings.decodeImpl = (_, _) => 1;

      final result = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([10]),
            ),
          ],
        ),
      );

      expect(result, isA<StepBatchFailed>());
      expect((result as StepBatchFailed).message, contains('llama_decode'));
      expect(result.backendCode, decodeKvSlotUnavailableBackendCode);
    });

    test('kv operations delegate to llama memory APIs', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);
      bindings
        ..posMin = 2
        ..posMax = 6;

      final snapshot = backend.kvSnapshot();
      final state = (snapshot as KvSnapshotSucceeded).snapshot.sequences.single;
      expect(state.positionMin, 2);
      expect(state.positionMax, 6);
      expect(state.usedPositions, 7);

      expect(
        backend.removeRange(sequence.id, start: 3, end: 5),
        isA<RemoveRangeSucceeded>(),
      );
      expect(bindings.lastMemoryRemoval, isNotNull);
      expect(backend.clear(sequence.id), isA<ClearSequenceSucceeded>());
    });

    test('reads a partial sliding-window checkpoint for a sequence', () {
      final backend = context.sequences;
      final sequence = _acquire(backend);
      bindings.sequenceState = Uint8List.fromList([7, 8, 9]);

      final read = backend.readCheckpoint(sequence.id);

      expect(
        (read as ReadCheckpointSucceeded).bytes,
        orderedEquals([7, 8, 9]),
      );
      expect(
        bindings.lastSequenceStateFlags,
        LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY,
      );
    });

    test('checkpoints the full state of a recurrent model', () async {
      bindings.isRecurrent = true;
      final created = await model.createContext(_contextRequest());
      final backend =
          (created as LlamaCreateContextSucceeded).context.sequences;
      final sequence = _acquire(backend);
      bindings.sequenceState = Uint8List.fromList([1]);

      backend
        ..readCheckpoint(sequence.id)
        ..restoreCheckpoint(sequence.id, Uint8List.fromList([1]));

      expect(bindings.lastSequenceStateFlags, LLAMA_STATE_SEQ_FLAGS_NONE);
    });

    test('reads an empty checkpoint when the sequence holds no state', () {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final read = backend.readCheckpoint(sequence.id);

      expect((read as ReadCheckpointSucceeded).bytes, isEmpty);
    });

    test('restores a checkpoint into a sequence', () {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final restored = backend.restoreCheckpoint(
        sequence.id,
        Uint8List.fromList([1, 2]),
      );

      expect(restored, isA<RestoreCheckpointSucceeded>());
      expect(bindings.restoredSequenceState, orderedEquals([1, 2]));
    });

    test('fails to restore a checkpoint the backend rejects', () {
      final backend = context.sequences;
      final sequence = _acquire(backend);
      bindings.acceptsSequenceState = false;

      expect(
        backend.restoreCheckpoint(sequence.id, Uint8List.fromList([1])),
        isA<RestoreCheckpointFailed>(),
      );
    });

    test('fails to restore an empty checkpoint without touching the '
        'backend', () {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      expect(
        backend.restoreCheckpoint(sequence.id, Uint8List(0)),
        isA<RestoreCheckpointFailed>(),
      );
      expect(bindings.restoredSequenceState, isNull);
    });

    test('checkpoints fail for unacquired sequences', () {
      final backend = context.sequences;

      expect(backend.readCheckpoint(0), isA<ReadCheckpointFailed>());
      expect(
        backend.restoreCheckpoint(0, Uint8List.fromList([1])),
        isA<RestoreCheckpointFailed>(),
      );
    });

    test(
      'rebuild sampler resets history and accepts supplied tokens',
      () async {
        final backend = context.sequences;
        final sequence = _acquire(backend);

        final result = backend.rebuildSampler(
          sequence.id,
          Int64List.fromList([10, 11, 12]),
        );

        expect(result, isA<RebuildSamplerSucceeded>());
        expect(bindings.samplerResetCalls, 1);
        expect(bindings.acceptedTokens, [10, 11, 12]);
      },
    );

    test('rebuild sampler accepts an empty token list as reset only', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final result = backend.rebuildSampler(sequence.id, Int64List(0));

      expect(result, isA<RebuildSamplerSucceeded>());
      expect(bindings.samplerResetCalls, 1);
      expect(bindings.samplerAcceptCalls, 0);
    });

    test('editing operations fail for unacquired sequences', () async {
      final backend = context.sequences;

      expect(
        backend.removeRange(0, start: 0, end: 1),
        isA<RemoveRangeFailed>(),
      );
      expect(
        backend.rebuildSampler(0, Int64List.fromList([10])),
        isA<RebuildSamplerFailed>(),
      );
      expect(bindings.lastMemoryRemoval, isNull);
      expect(bindings.samplerResetCalls, 0);
    });

    test('editing operations invalidate active logits tickets', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final editedPrefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([10]),
              retainLogits: true,
            ),
          ],
        ),
      );
      final editedTicket = _ticket(
        (editedPrefill as StepBatchSucceeded).prefills.single,
      );

      backend.removeRange(sequence.id, start: 1, end: 2);

      expect(
        backend.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: editedTicket)]),
        ),
        isA<StepBatchFailed>(),
      );

      final rebuiltPrefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([11]),
              retainLogits: true,
            ),
          ],
        ),
      );
      final rebuiltTicket = _ticket(
        (rebuiltPrefill as StepBatchSucceeded).prefills.single,
      );

      backend.rebuildSampler(
        sequence.id,
        Int64List.fromList([10, 11]),
      );

      expect(
        backend.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: rebuiltTicket)]),
        ),
        isA<StepBatchFailed>(),
      );
    });

    test('backend operations fail after context disposal', () async {
      final backend = context.sequences;
      await context.dispose();

      expect(
        backend.acquire(_sequenceRequest()),
        isA<RequestSequenceFailed>(),
      );
      expect(backend.release(0), isA<ReleaseSequenceFailed>());
      expect(backend.clear(0), isA<ClearSequenceFailed>());
      expect(
        backend.setSampling(0, const EngineSampling(seed: 1)),
        isA<SetSamplingFailed>(),
      );
      expect(
        backend.removeRange(0, start: 0, end: 1),
        isA<RemoveRangeFailed>(),
      );
      expect(
        backend.rebuildSampler(0, Int64List(0)),
        isA<RebuildSamplerFailed>(),
      );
      expect(backend.kvSnapshot(), isA<KvSnapshotFailed>());
      expect(backend.readCheckpoint(0), isA<ReadCheckpointFailed>());
      expect(
        backend.restoreCheckpoint(0, Uint8List.fromList([1])),
        isA<RestoreCheckpointFailed>(),
      );
      expect(
        backend.stepBatch(const StepRequest()),
        isA<StepBatchFailed>(),
      );
    });

    test('prefill can decode without logits or sampler history', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final result = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([10, 11]),
            ),
          ],
        ),
      );

      final success = result as StepBatchSucceeded;
      expect(success.prefills.single, isA<PrefillSequenceSucceeded>());
      final prefill = success.prefills.single;
      expect(prefill.positionMin, 1);
      expect(prefill.positionMax, 2);
      expect(bindings.samplerSampleCalls, 0);
      expect(bindings.samplerAcceptCalls, 0);
      expect(decoded.single, [
        _DecodedEntry(token: 10, pos: 1, seqId: sequence.id, logits: false),
        _DecodedEntry(token: 11, pos: 2, seqId: sequence.id, logits: false),
      ]);
    });

    test('sample fails when a ticket is reused', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final prefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([10]),
              retainLogits: true,
            ),
          ],
        ),
      );
      final ticket = _ticket((prefill as StepBatchSucceeded).prefills.single);

      expect(
        backend.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepBatchSucceeded>(),
      );
      expect(
        backend.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: ticket)]),
        ),
        isA<StepBatchFailed>(),
      );
    });

    test('sample fails when a ticket is stale after another decode', () async {
      final backend = context.sequences;
      final sequence = _acquire(backend);

      final first = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([10]),
              retainLogits: true,
            ),
          ],
        ),
      );
      final stale = _ticket((first as StepBatchSucceeded).prefills.single);

      backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sequence.id,
              tokens: Int64List.fromList([11]),
            ),
          ],
        ),
      );

      expect(
        backend.stepBatch(
          StepRequest(samples: [SampleRequest(logitsTicket: stale)]),
        ),
        isA<StepBatchFailed>(),
      );
    });

    test('prefill fails when the physical batch exceeds nBatch', () async {
      final backend = context.sequences;
      final first = _acquire(backend);
      final second = _acquire(backend);
      final third = _acquire(backend);

      final result = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: first.id,
              tokens: Int64List.fromList([10, 11, 12]),
              retainLogits: true,
            ),
            PrefillRequest(
              sequenceId: second.id,
              tokens: Int64List.fromList([20, 21, 22]),
              retainLogits: true,
            ),
            PrefillRequest(
              sequenceId: third.id,
              tokens: Int64List.fromList([30, 31, 32]),
              retainLogits: true,
            ),
          ],
        ),
      );

      expect(result, isA<StepBatchFailed>());
      expect(bindings.decodeCalls, 0);
    });

    test('an oversized step releases the samplers it cloned', () async {
      final backend = context.sequences;
      final sampled = _acquire(backend);
      final prefilled = _acquire(backend);
      final prefill = backend.stepBatch(
        StepRequest(
          prefills: [
            PrefillRequest(
              sequenceId: sampled.id,
              tokens: Int64List.fromList([10]),
              retainLogits: true,
            ),
          ],
        ),
      );
      final ticket = _ticket((prefill as StepBatchSucceeded).prefills.single);
      final freedBefore = bindings.samplerFreeCalls;

      final result = backend.stepBatch(
        StepRequest(
          samples: [SampleRequest(logitsTicket: ticket)],
          prefills: [
            PrefillRequest(
              sequenceId: prefilled.id,
              tokens: Int64List.fromList(List.generate(8, (index) => index)),
            ),
          ],
        ),
      );

      expect(result, isA<StepBatchFailed>());
      expect(bindings.samplerFreeCalls, freedBefore + 1);
    });

    test('model disposes cleanly after a failed context creation', () async {
      final bindings = FakeLlamaCppBindings(
        newContextImpl: (_, _) => nullptr,
      );
      final model = await _loadModel(bindings);

      expect(
        await model.createContext(_contextRequest()),
        isA<LlamaCreateContextFailed>(),
      );
      expect(await model.dispose(), isA<ModelDisposed>());
    });
  });
}

Future<LlamaModel> _loadModel(FakeLlamaCppBindings bindings) async {
  final loader = stubbedLlamaModelLoader(
    client: LlamaClient(bindings: bindings),
    modelAddress: bindings.modelPtr.address,
  );
  final load = await loader.load(
    const LlamaModelLoadRequest(path: 'model.gguf'),
  );
  return (load as LlamaLoadModelSucceeded).model;
}

LlamaCreateContextRequest _contextRequest() {
  return const LlamaCreateContextRequest(
    options: LlamaContextOptions(
      contextSize: 128,
      nBatch: 8,
      nThreads: 1,
      nThreadsBatch: 1,
      maxSequences: 3,
    ),
  );
}

SequenceRequest _sequenceRequest() {
  return const SequenceRequest(
    sampling: EngineSampling(seed: 0),
  );
}

Sequence _acquire(Sequences backend) {
  final result = backend.acquire(_sequenceRequest());
  return (result as RequestSequenceSucceeded).sequence;
}

LogitsTicket _ticket(PrefillSequenceResult result) {
  return (result as PrefillSequenceWithLogitsSucceeded).logitsTicket;
}

List<_DecodedEntry> _entries(llama_batch batch) {
  return [
    for (var i = 0; i < batch.n_tokens; i++)
      _DecodedEntry(
        token: batch.token[i],
        pos: batch.pos[i],
        seqId: batch.seq_id[i][0],
        logits: batch.logits[i] != 0,
      ),
  ];
}

@immutable
final class _DecodedEntry {
  const _DecodedEntry({
    required this.token,
    required this.pos,
    required this.seqId,
    required this.logits,
  });

  final int token;
  final int pos;
  final int seqId;
  final bool logits;

  @override
  bool operator ==(Object other) {
    return other is _DecodedEntry &&
        other.token == token &&
        other.pos == pos &&
        other.seqId == seqId &&
        other.logits == logits;
  }

  @override
  int get hashCode => Object.hash(token, pos, seqId, logits);

  @override
  String toString() {
    return 'DecodedEntry(token: $token, pos: $pos, seqId: $seqId, '
        'logits: $logits)';
  }
}
