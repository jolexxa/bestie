import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context_engine.dart';
import 'package:inference_llama/src/context/llama_context_results.dart';
import 'package:isolate_worker/isolate_worker.dart';

final class LlamaSequences implements Sequences {
  LlamaSequences({
    required LlamaContextEngine engine,
  }) : _engine = engine;

  final LlamaContextEngine _engine;

  @override
  int get maxSequences => _engine.maxSequences;

  @override
  int get maxBatchTokens => _engine.maxBatchTokens;

  @override
  RequestSequenceResult acquire(SequenceRequest request) {
    final response = _engine.acquire(request);
    return switch (response) {
      AcquireLlamaSequenceSucceeded(:final sequenceId) =>
        RequestSequenceSucceeded(
          Sequence(id: sequenceId),
        ),
      AcquireLlamaSequenceFailed(:final message, :final stackTrace) =>
        RequestSequenceFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  ReleaseSequenceResult release(SequenceId id) {
    final response = _engine.release(id);
    return switch (response) {
      ReleaseLlamaSequenceSucceeded() => const ReleaseSequenceSucceeded(),
      ReleaseLlamaSequenceFailed(:final message, :final stackTrace) =>
        ReleaseSequenceFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  ClearSequenceResult clear(SequenceId id) {
    final response = _engine.clear(id);
    return switch (response) {
      ClearLlamaSequenceSucceeded() => const ClearSequenceSucceeded(),
      ClearLlamaSequenceFailed(:final message, :final stackTrace) =>
        ClearSequenceFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  SetSamplingResult setSampling(
    SequenceId id,
    EngineSampling sampling,
  ) {
    final response = _engine.setSampling(id, sampling);
    return switch (response) {
      SetLlamaSamplingSucceeded() => const SetSamplingSucceeded(),
      SetLlamaSamplingFailed(:final message, :final stackTrace) =>
        SetSamplingFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  RemoveRangeResult removeRange(
    SequenceId id, {
    required int start,
    required int end,
  }) {
    final response = _engine.removeRange(id, start: start, end: end);
    return switch (response) {
      RemoveLlamaSequenceRangeSucceeded() => const RemoveRangeSucceeded(),
      RemoveLlamaSequenceRangeFailed(:final message, :final stackTrace) =>
        RemoveRangeFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  RebuildSamplerResult rebuildSampler(
    SequenceId id,
    TokenizedString acceptedTokens,
  ) {
    final response = _engine.rebuildSampler(id, acceptedTokens);
    return switch (response) {
      RebuildLlamaSamplerSucceeded() => const RebuildSamplerSucceeded(),
      RebuildLlamaSamplerFailed(:final message, :final stackTrace) =>
        RebuildSamplerFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  KvSnapshotResult kvSnapshot() {
    final response = _engine.kvSnapshot();
    return switch (response) {
      ReadLlamaKvSnapshotSucceeded(:final snapshot) => KvSnapshotSucceeded(
        snapshot,
      ),
      ReadLlamaKvSnapshotFailed(:final message, :final stackTrace) =>
        KvSnapshotFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  ReadCheckpointResult readCheckpoint(SequenceId id) {
    final response = _engine.readCheckpoint(id);
    return switch (response) {
      ReadLlamaSequenceCheckpointSucceeded(:final bytes) =>
        ReadCheckpointSucceeded(bytes),
      ReadLlamaSequenceCheckpointFailed(:final message, :final stackTrace) =>
        ReadCheckpointFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  RestoreCheckpointResult restoreCheckpoint(SequenceId id, Uint8List bytes) {
    final response = _engine.restoreCheckpoint(id, bytes);
    return switch (response) {
      RestoreLlamaSequenceCheckpointSucceeded() =>
        const RestoreCheckpointSucceeded(),
      RestoreLlamaSequenceCheckpointFailed(:final message, :final stackTrace) =>
        RestoreCheckpointFailed(
          message: message,
          stackTrace: stackTrace,
        ),
    };
  }

  @override
  StepBatchResult stepBatch(
    StepRequest request, {
    IsolateCancellationToken? cancellationToken,
  }) {
    final response = _engine.stepBatch(
      request,
      cancellationToken:
          cancellationToken ?? const NeverCancelledIsolateCancellationToken(),
    );
    return switch (response) {
      StepLlamaBatchSucceeded(:final samples, :final prefills) =>
        StepBatchSucceeded(
          samples: samples,
          prefills: prefills,
        ),
      StepLlamaBatchFailed(
        :final message,
        :final stackTrace,
        :final backendCode,
      ) =>
        StepBatchFailed(
          message: message,
          stackTrace: stackTrace,
          backendCode: backendCode,
        ),
    };
  }
}
