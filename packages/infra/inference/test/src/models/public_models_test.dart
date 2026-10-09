import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:test/test.dart';

void main() {
  group('inference model types', () {
    test('expose the context envelope limits', () {
      const envelope = ContextEnvelope(
        contextSize: 4096,
        perSequenceLimit: 2048,
        maxSequences: 8,
        maxBatchTokens: 512,
        microBatchTokens: 256,
        nSwa: 0,
      );

      expect(envelope.contextSize, 4096);
      expect(envelope.perSequenceLimit, 2048);
      expect(envelope.maxSequences, 8);
      expect(envelope.maxBatchTokens, 512);
      expect(envelope.microBatchTokens, 256);
    });

    test('expose request and state values', () {
      const sampling = EngineSampling(
        seed: 1,
        topK: 2,
        topP: 0.3,
        minP: 0.4,
        temperature: 0.5,
        typicalP: 0.6,
        penaltyRepeat: 0.7,
        penaltyLastN: 8,
        penaltyFreq: 0.9,
        penaltyPresent: 1,
      );
      const sequence = Sequence(id: 3);
      const sequenceRequest = SequenceRequest(sampling: sampling);
      final tokens = Int64List.fromList([10, 11]);
      final prefillRequest = PrefillRequest(
        sequenceId: sequence.id,
        tokens: tokens,
        retainLogits: true,
        samplerMode: PrefillSamplerMode.accept,
      );
      const ticket = LogitsTicket(
        sequenceId: 3,
        position: 4,
        batchIndex: 5,
        generation: 6,
      );
      const sampleRequest = SampleRequest(logitsTicket: ticket);
      const emptyKv = SequenceKvState(
        sequenceId: 3,
        positionMin: -1,
        positionMax: -1,
      );
      const occupiedKv = SequenceKvState(
        sequenceId: 3,
        positionMin: 2,
        positionMax: 4,
      );
      const hybridTailKv = SequenceKvState(
        sequenceId: 3,
        positionMin: 300,
        positionMax: 300,
      );
      const snapshot = KvSnapshot(
        contextSize: 128,
        sequences: [occupiedKv],
      );

      expect(sequence.id, 3);
      expect(sequenceRequest.sampling.seed, 1);
      expect(sampling.topK, 2);
      expect(sampling.topP, 0.3);
      expect(sampling.minP, 0.4);
      expect(sampling.temperature, 0.5);
      expect(sampling.typicalP, 0.6);
      expect(sampling.penaltyRepeat, 0.7);
      expect(sampling.penaltyLastN, 8);
      expect(sampling.penaltyFreq, 0.9);
      expect(sampling.penaltyPresent, 1.0);
      expect(prefillRequest.sequenceId, 3);
      expect(prefillRequest.tokens, same(tokens));
      expect(prefillRequest.retainLogits, isTrue);
      expect(prefillRequest.samplerMode, PrefillSamplerMode.accept);
      expect(sampleRequest.logitsTicket, same(ticket));
      final stepRequest = StepRequest(
        samples: [sampleRequest],
        prefills: [prefillRequest],
      );
      expect(stepRequest.samples, [sampleRequest]);
      expect(stepRequest.prefills, [prefillRequest]);
      expect(ticket.position, 4);
      expect(ticket.batchIndex, 5);
      expect(ticket.generation, 6);
      expect(emptyKv.usedPositions, 0);
      expect(occupiedKv.usedPositions, 5);
      expect(hybridTailKv.usedPositions, 301);
      expect(snapshot.contextSize, 128);
      expect(snapshot.sequences.single, occupiedKv);
    });

    test('expose operation result values', () {
      const sequence = Sequence(id: 1);
      const ticket = LogitsTicket(
        sequenceId: 1,
        position: 2,
        batchIndex: 3,
        generation: 4,
      );
      const prefilled = PrefillSequenceSucceeded(
        sequenceId: 1,
        positionMin: 0,
        positionMax: 2,
      );
      const prefilledWithLogits = PrefillSequenceWithLogitsSucceeded(
        sequenceId: 1,
        positionMin: 0,
        positionMax: 2,
        logitsTicket: ticket,
      );
      const sampleToken = SampleSequenceToken(
        sequenceId: 1,
        token: 9,
        position: 3,
        nextLogitsTicket: ticket,
      );
      const sampleStopped = SampleSequenceStopped(
        sequenceId: 1,
        token: 10,
      );
      const snapshot = KvSnapshot(contextSize: 4, sequences: []);

      expect(const RequestSequenceSucceeded(sequence).sequence, sequence);
      expect(
        const RequestSequenceFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(const SetSamplingSucceeded(), isA<SetSamplingSucceeded>());
      expect(
        const SetSamplingFailed(message: 'm', stackTrace: 's').stackTrace,
        's',
      );
      expect(
        const StepBatchSucceeded(
          samples: [sampleToken],
          prefills: [prefilled],
        ).prefills.single,
        prefilled,
      );
      expect(
        const StepBatchSucceeded(
          samples: [sampleToken],
          prefills: [prefilled],
        ).samples.single,
        sampleToken,
      );
      expect(
        const StepBatchFailed(
          message: 'm',
          stackTrace: 's',
          backendCode: 7,
        ).backendCode,
        7,
      );
      expect(prefilled.positionMax, 2);
      expect(prefilledWithLogits.logitsTicket, ticket);
      expect(sampleToken.nextLogitsTicket, ticket);
      expect(sampleStopped.token, 10);
      expect(const KvSnapshotSucceeded(snapshot).snapshot, snapshot);
      expect(
        const KvSnapshotFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(const ClearSequenceSucceeded(), isA<ClearSequenceSucceeded>());
      expect(
        const ClearSequenceFailed(message: 'm', stackTrace: 's').stackTrace,
        's',
      );
      expect(const RemoveRangeSucceeded(), isA<RemoveRangeSucceeded>());
      expect(
        const RemoveRangeFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(const RebuildSamplerSucceeded(), isA<RebuildSamplerSucceeded>());
      expect(
        const RebuildSamplerFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(const ReleaseSequenceSucceeded(), isA<ReleaseSequenceSucceeded>());
      expect(
        const ReleaseSequenceFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(const DisposeContextSucceeded(), isA<DisposeContextSucceeded>());
      expect(
        const DisposeContextFailed(message: 'm', stackTrace: 's').stackTrace,
        's',
      );
    });

    test('expose model and tokenizer result values', () {
      final tokens = Int64List.fromList([1]);
      final bytes = Uint8List.fromList([2]);

      expect(const ModelDisposed(), isA<ModelDisposed>());
      expect(
        const DisposeModelFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(
        const TokenizeRequest(text: 'hi', addSpecial: false).parseSpecial,
        isTrue,
      );
      expect(TokenizeSucceeded(tokens).tokens, same(tokens));
      expect(
        const TokenizeFailed(message: 'm', stackTrace: 's').stackTrace,
        's',
      );
      expect(const DetokenizeRequest(token: 1).token, 1);
      expect(DetokenizeSucceeded(bytes).bytes, same(bytes));
      expect(
        const DetokenizeFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
    });

    test('expose checkpoint result values', () {
      final bytes = Uint8List.fromList([3, 4]);

      expect(ReadCheckpointSucceeded(bytes).bytes, same(bytes));
      expect(
        const ReadCheckpointFailed(message: 'm', stackTrace: 's').message,
        'm',
      );
      expect(
        const RestoreCheckpointSucceeded(),
        isA<RestoreCheckpointSucceeded>(),
      );
      expect(
        const RestoreCheckpointFailed(message: 'm', stackTrace: 's').stackTrace,
        's',
      );
    });
  });
}
