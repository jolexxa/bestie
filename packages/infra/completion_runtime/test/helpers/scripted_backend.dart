import 'dart:convert';
import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:isolate_worker/isolate_worker.dart';

/// A context over [ScriptedSequences], standing in for the native llama
/// context.
final class ScriptedContext implements Context {
  ScriptedContext({required this.contextSize, required this.sequences});

  @override
  final int contextSize;

  @override
  final ScriptedSequences sequences;

  @override
  ContextEnvelope get envelope => ContextEnvelope(
    contextSize: contextSize,
    perSequenceLimit: contextSize,
    maxSequences: sequences.maxSequences,
    maxBatchTokens: sequences.maxBatchTokens,
    microBatchTokens: sequences.maxBatchTokens,
    nSwa: 0,
  );

  @override
  Future<DisposeContextResult> dispose() async =>
      const DisposeContextSucceeded();
}

/// Simulates the native KV cache: tracks every sequence's positions, answers
/// samples from per-sequence scripted replies one character at a time, and
/// logs every operation in order.
final class ScriptedSequences implements Sequences {
  ScriptedSequences({
    required Map<SequenceId, List<String>> replies,
    this.maxSequences = 4,
    this.maxBatchTokens = 64,
  }) : _replies = {
         for (final entry in replies.entries) entry.key: List.of(entry.value),
       };

  @override
  final int maxSequences;

  @override
  final int maxBatchTokens;

  final Map<SequenceId, List<String>> _replies;
  final _speaking = <SequenceId, List<int>>{};
  final _positionMaxBySequence = <SequenceId, int>{};
  final log = <BackendOperation>[];
  var _nextSequenceId = 1;

  List<StepOperation> get steps => [...log.whereType<StepOperation>()];

  /// Tokens prefilled into [sequenceId] across every step after the
  /// [afterStep]th.
  int prefilledInto(SequenceId sequenceId, {int afterStep = 0}) => [
    for (final step in steps.skip(afterStep))
      for (final prefill in step.prefills)
        if (prefill.sequenceId == sequenceId) prefill.tokenCount,
  ].fold(0, (total, count) => total + count);

  int residentTokens(SequenceId sequenceId) =>
      (_positionMaxBySequence[sequenceId] ?? -1) + 1;

  @override
  RequestSequenceResult acquire(SequenceRequest request) {
    final id = _nextSequenceId++;
    log.add(AcquireOperation(id));
    _positionMaxBySequence[id] = -1;
    return RequestSequenceSucceeded(Sequence(id: id));
  }

  @override
  ReleaseSequenceResult release(SequenceId id) {
    log.add(ReleaseOperation(id));
    _positionMaxBySequence.remove(id);
    _speaking.remove(id);
    return const ReleaseSequenceSucceeded();
  }

  @override
  ClearSequenceResult clear(SequenceId id) {
    log.add(ClearOperation(id));
    _positionMaxBySequence[id] = -1;
    return const ClearSequenceSucceeded();
  }

  @override
  SetSamplingResult setSampling(SequenceId id, EngineSampling sampling) {
    log.add(SetSamplingOperation(id));
    return const SetSamplingSucceeded();
  }

  @override
  RemoveRangeResult removeRange(
    SequenceId id, {
    required int start,
    required int end,
  }) {
    log.add(RemoveRangeOperation(id, start: start, end: end));
    final current = _positionMaxBySequence[id] ?? -1;
    if (current >= start) _positionMaxBySequence[id] = start - 1;
    return const RemoveRangeSucceeded();
  }

  @override
  RebuildSamplerResult rebuildSampler(
    SequenceId id,
    TokenizedString acceptedTokens,
  ) {
    log.add(RebuildSamplerOperation(id));
    return const RebuildSamplerSucceeded();
  }

  @override
  KvSnapshotResult kvSnapshot() => KvSnapshotSucceeded(
    KvSnapshot(
      contextSize: 0,
      sequences: [
        for (final entry in _positionMaxBySequence.entries)
          if (entry.value >= 0)
            SequenceKvState(
              sequenceId: entry.key,
              positionMin: 0,
              positionMax: entry.value,
            ),
      ],
    ),
  );

  @override
  ReadCheckpointResult readCheckpoint(SequenceId id) =>
      ReadCheckpointSucceeded(Uint8List(0));

  @override
  RestoreCheckpointResult restoreCheckpoint(SequenceId id, Uint8List bytes) =>
      const RestoreCheckpointSucceeded();

  @override
  StepBatchResult stepBatch(
    StepRequest request, {
    IsolateCancellationToken? cancellationToken,
  }) {
    log.add(
      StepOperation(
        prefills: [
          for (final prefill in request.prefills)
            PrefillOperation(
              sequenceId: prefill.sequenceId,
              tokenCount: prefill.tokens.length,
            ),
        ],
        sampledSequences: [
          for (final sample in request.samples) sample.logitsTicket.sequenceId,
        ],
      ),
    );
    return StepBatchSucceeded(
      prefills: [for (final prefill in request.prefills) _prefill(prefill)],
      samples: [for (final sample in request.samples) _sample(sample)],
    );
  }

  PrefillSequenceResult _prefill(PrefillRequest request) {
    final id = request.sequenceId;
    _speaking.remove(id);
    final positionMin = (_positionMaxBySequence[id] ?? -1) + 1;
    final positionMax = positionMin + request.tokens.length - 1;
    _positionMaxBySequence[id] = positionMax;
    if (!request.retainLogits) {
      return PrefillSequenceSucceeded(
        sequenceId: id,
        positionMin: positionMin,
        positionMax: positionMax,
      );
    }
    return PrefillSequenceWithLogitsSucceeded(
      sequenceId: id,
      positionMin: positionMin,
      positionMax: positionMax,
      logitsTicket: _ticket(id, positionMax),
    );
  }

  SampleSequenceResult _sample(SampleRequest request) {
    final id = request.logitsTicket.sequenceId;
    final remaining = _speaking.putIfAbsent(
      id,
      () => utf8.encode(_replies[id]!.removeAt(0)).toList(),
    );
    if (remaining.isEmpty) {
      _speaking.remove(id);
      return SampleSequenceStopped(sequenceId: id, token: endOfGeneration);
    }
    final position = _positionMaxBySequence[id]! + 1;
    _positionMaxBySequence[id] = position;
    return SampleSequenceToken(
      sequenceId: id,
      token: remaining.removeAt(0),
      position: position,
      nextLogitsTicket: _ticket(id, position),
    );
  }

  LogitsTicket _ticket(SequenceId id, int position) => LogitsTicket(
    sequenceId: id,
    position: position,
    batchIndex: 0,
    generation: position,
  );
}

const endOfGeneration = -1;

/// Tokenizes text one UTF-8 byte per token, standing in for the native
/// vocabulary.
final class ByteTokenizer implements Detokenizer {
  const ByteTokenizer();

  @override
  TokenizeResult tokenize(TokenizeRequest request) =>
      TokenizeSucceeded(Int64List.fromList(utf8.encode(request.text)));

  @override
  DetokenizeResult detokenize(DetokenizeRequest request) =>
      DetokenizeSucceeded(Uint8List.fromList([request.token]));
}

sealed class BackendOperation {
  const BackendOperation();
}

final class AcquireOperation extends BackendOperation {
  const AcquireOperation(this.sequenceId);

  final SequenceId sequenceId;

  @override
  String toString() => 'acquire($sequenceId)';
}

final class ReleaseOperation extends BackendOperation {
  const ReleaseOperation(this.sequenceId);

  final SequenceId sequenceId;

  @override
  String toString() => 'release($sequenceId)';
}

final class ClearOperation extends BackendOperation {
  const ClearOperation(this.sequenceId);

  final SequenceId sequenceId;

  @override
  String toString() => 'clear($sequenceId)';
}

final class SetSamplingOperation extends BackendOperation {
  const SetSamplingOperation(this.sequenceId);

  final SequenceId sequenceId;

  @override
  String toString() => 'setSampling($sequenceId)';
}

final class RemoveRangeOperation extends BackendOperation {
  const RemoveRangeOperation(
    this.sequenceId, {
    required this.start,
    required this.end,
  });

  final SequenceId sequenceId;
  final int start;
  final int end;

  @override
  String toString() => 'removeRange($sequenceId, $start, $end)';
}

final class RebuildSamplerOperation extends BackendOperation {
  const RebuildSamplerOperation(this.sequenceId);

  final SequenceId sequenceId;

  @override
  String toString() => 'rebuildSampler($sequenceId)';
}

final class StepOperation extends BackendOperation {
  const StepOperation({required this.prefills, required this.sampledSequences});

  final List<PrefillOperation> prefills;
  final List<SequenceId> sampledSequences;

  Set<SequenceId> get sequences => {
    for (final prefill in prefills) prefill.sequenceId,
    ...sampledSequences,
  };

  @override
  String toString() => 'step(prefill: $prefills, sample: $sampledSequences)';
}

final class PrefillOperation {
  const PrefillOperation({required this.sequenceId, required this.tokenCount});

  final SequenceId sequenceId;
  final int tokenCount;

  @override
  String toString() => '$sequenceId:$tokenCount';
}
