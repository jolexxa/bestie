import 'dart:typed_data';

import 'package:inference/src/runtime/tokenized_string.dart';
import 'package:inference_backends/inference_backends.dart';
import 'package:isolate_worker/isolate_worker.dart';

/// Backend code for a decode batch that could not be admitted because no KV
/// slot was available.
///
/// The batch can be retried with less elastic work.
const int decodeKvSlotUnavailableBackendCode = 1;

abstract interface class Context {
  /// The real KV-cache envelope reported by the backend after construction.
  ContextEnvelope get envelope;

  int get contextSize;

  Sequences get sequences;

  Future<DisposeContextResult> dispose();
}

/// The backend's actual capacity limits, read from the engine after the context
/// is created — never the requested values. Every capacity decision (claims,
/// admission, batch sizing) is made against these numbers so the runtime can
/// never overshoot what the backend physically allocated.
final class ContextEnvelope {
  const ContextEnvelope({
    required this.contextSize,
    required this.perSequenceLimit,
    required this.maxSequences,
    required this.maxBatchTokens,
    required this.microBatchTokens,
    required this.nSwa,
    this.isRecurrent = false,
  });

  /// Total KV pool size, in tokens (`llama_n_ctx`).
  final int contextSize;

  /// Maximum positions a single sequence may hold (`llama_n_ctx_seq`).
  final int perSequenceLimit;

  /// Maximum concurrent sequences (`llama_n_seq_max`).
  final int maxSequences;

  /// Maximum tokens per decode batch (`llama_n_batch`).
  final int maxBatchTokens;

  /// Maximum tokens per micro-batch (`llama_n_ubatch`).
  final int microBatchTokens;

  /// The sliding-window attention span (`llama_model_n_swa`), or 0 for
  /// full-attention models. On an SWA model a reused prefix is only valid while
  /// the window's oldest needed position is still resident in the cache.
  final int nSwa;

  /// Whether the model uses recurrent memory (the
  /// rolling per-sequence state of SSM / Gated DeltaNet layers such ase those
  /// in a hybrid recurrent model. That state cannot be partially rewound, so a
  /// divergent tail can never be dropped in place; the reused prefix is instead
  /// restored from a full-state checkpoint (or rebuilt from zero) rather than
  /// trimmed.
  final bool isRecurrent;
}

abstract interface class Sequences {
  int get maxSequences;

  int get maxBatchTokens;

  RequestSequenceResult acquire(SequenceRequest request);

  ReleaseSequenceResult release(SequenceId id);

  ClearSequenceResult clear(SequenceId id);

  SetSamplingResult setSampling(
    SequenceId id,
    EngineSampling sampling,
  );

  RemoveRangeResult removeRange(
    SequenceId id, {
    required int start,
    required int end,
  });

  RebuildSamplerResult rebuildSampler(
    SequenceId id,
    TokenizedString acceptedTokens,
  );

  KvSnapshotResult kvSnapshot();

  ReadCheckpointResult readCheckpoint(SequenceId id);

  RestoreCheckpointResult restoreCheckpoint(SequenceId id, Uint8List bytes);

  StepBatchResult stepBatch(
    StepRequest request, {
    IsolateCancellationToken? cancellationToken,
  });
}

final class Sequence {
  const Sequence({required this.id});

  final SequenceId id;
}

final class SequenceRequest {
  const SequenceRequest({
    required this.sampling,
  });

  final EngineSampling sampling;
}

final class PrefillRequest {
  const PrefillRequest({
    required this.sequenceId,
    required this.tokens,
    this.retainLogits = false,
    this.samplerMode = PrefillSamplerMode.ignore,
  });

  final SequenceId sequenceId;
  final TokenizedString tokens;
  final bool retainLogits;
  final PrefillSamplerMode samplerMode;
}

enum PrefillSamplerMode { ignore, accept }

final class LogitsTicket {
  const LogitsTicket({
    required this.sequenceId,
    required this.position,
    required this.batchIndex,
    required this.generation,
  });

  final SequenceId sequenceId;
  final int position;
  final int batchIndex;
  final int generation;
}

final class SampleRequest {
  const SampleRequest({required this.logitsTicket});

  final LogitsTicket logitsTicket;
}

final class StepRequest {
  const StepRequest({
    this.samples = const [],
    this.prefills = const [],
  });

  final List<SampleRequest> samples;
  final List<PrefillRequest> prefills;
}

final class SequenceKvState {
  const SequenceKvState({
    required this.sequenceId,
    required this.positionMin,
    required this.positionMax,
  });

  final SequenceId sequenceId;
  final int positionMin;
  final int positionMax;

  /// Context positions consumed by this sequence.
  int get usedPositions {
    if (positionMax < 0) {
      return 0;
    }
    return positionMax + 1;
  }
}

final class KvSnapshot {
  const KvSnapshot({
    required this.contextSize,
    required this.sequences,
  });

  final int contextSize;
  final List<SequenceKvState> sequences;
}

sealed class RequestSequenceResult {
  const RequestSequenceResult();
}

final class RequestSequenceSucceeded extends RequestSequenceResult {
  const RequestSequenceSucceeded(this.sequence);

  final Sequence sequence;
}

final class RequestSequenceFailed extends RequestSequenceResult {
  const RequestSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class SetSamplingResult {
  const SetSamplingResult();
}

final class SetSamplingSucceeded extends SetSamplingResult {
  const SetSamplingSucceeded();
}

final class SetSamplingFailed extends SetSamplingResult {
  const SetSamplingFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class PrefillSequenceResult {
  const PrefillSequenceResult();

  SequenceId get sequenceId;
  int get positionMin;
  int get positionMax;
}

final class PrefillSequenceSucceeded extends PrefillSequenceResult {
  const PrefillSequenceSucceeded({
    required this.sequenceId,
    required this.positionMin,
    required this.positionMax,
  });

  @override
  final SequenceId sequenceId;

  @override
  final int positionMin;

  @override
  final int positionMax;
}

final class PrefillSequenceWithLogitsSucceeded extends PrefillSequenceResult {
  const PrefillSequenceWithLogitsSucceeded({
    required this.sequenceId,
    required this.positionMin,
    required this.positionMax,
    required this.logitsTicket,
  });

  @override
  final SequenceId sequenceId;

  @override
  final int positionMin;

  @override
  final int positionMax;

  final LogitsTicket logitsTicket;
}

sealed class StepBatchResult {
  const StepBatchResult();
}

final class StepBatchSucceeded extends StepBatchResult {
  const StepBatchSucceeded({
    required this.samples,
    required this.prefills,
  });

  final List<SampleSequenceResult> samples;
  final List<PrefillSequenceResult> prefills;
}

final class StepBatchFailed extends StepBatchResult {
  const StepBatchFailed({
    required this.message,
    required this.stackTrace,
    this.backendCode,
  });

  final String message;
  final String stackTrace;
  final int? backendCode;
}

sealed class SampleSequenceResult {
  const SampleSequenceResult();

  SequenceId get sequenceId;
}

final class SampleSequenceToken extends SampleSequenceResult {
  const SampleSequenceToken({
    required this.sequenceId,
    required this.token,
    required this.position,
    required this.nextLogitsTicket,
  });

  @override
  final SequenceId sequenceId;
  final TokenId token;
  final int position;
  final LogitsTicket nextLogitsTicket;
}

/// The sampled token ended generation; it is not decoded into the cache.
final class SampleSequenceStopped extends SampleSequenceResult {
  const SampleSequenceStopped({
    required this.sequenceId,
    required this.token,
  });

  @override
  final SequenceId sequenceId;
  final TokenId token;
}

sealed class KvSnapshotResult {
  const KvSnapshotResult();
}

final class KvSnapshotSucceeded extends KvSnapshotResult {
  const KvSnapshotSucceeded(this.snapshot);

  final KvSnapshot snapshot;
}

final class KvSnapshotFailed extends KvSnapshotResult {
  const KvSnapshotFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ReadCheckpointResult {
  const ReadCheckpointResult();
}

final class ReadCheckpointSucceeded extends ReadCheckpointResult {
  const ReadCheckpointSucceeded(this.bytes);

  final Uint8List bytes;
}

final class ReadCheckpointFailed extends ReadCheckpointResult {
  const ReadCheckpointFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RestoreCheckpointResult {
  const RestoreCheckpointResult();
}

final class RestoreCheckpointSucceeded extends RestoreCheckpointResult {
  const RestoreCheckpointSucceeded();
}

final class RestoreCheckpointFailed extends RestoreCheckpointResult {
  const RestoreCheckpointFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ClearSequenceResult {
  const ClearSequenceResult();
}

final class ClearSequenceSucceeded extends ClearSequenceResult {
  const ClearSequenceSucceeded();
}

final class ClearSequenceFailed extends ClearSequenceResult {
  const ClearSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RemoveRangeResult {
  const RemoveRangeResult();
}

final class RemoveRangeSucceeded extends RemoveRangeResult {
  const RemoveRangeSucceeded();
}

final class RemoveRangeFailed extends RemoveRangeResult {
  const RemoveRangeFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RebuildSamplerResult {
  const RebuildSamplerResult();
}

final class RebuildSamplerSucceeded extends RebuildSamplerResult {
  const RebuildSamplerSucceeded();
}

final class RebuildSamplerFailed extends RebuildSamplerResult {
  const RebuildSamplerFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ReleaseSequenceResult {
  const ReleaseSequenceResult();
}

final class ReleaseSequenceSucceeded extends ReleaseSequenceResult {
  const ReleaseSequenceSucceeded();
}

final class ReleaseSequenceFailed extends ReleaseSequenceResult {
  const ReleaseSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class DisposeContextResult {
  const DisposeContextResult();
}

final class DisposeContextSucceeded extends DisposeContextResult {
  const DisposeContextSucceeded();
}

final class DisposeContextFailed extends DisposeContextResult {
  const DisposeContextFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
