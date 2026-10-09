import 'dart:typed_data';

import 'package:inference/inference.dart';

/// Per-operation outcomes of the llama context engine. They carry inference
/// public types directly; the engine runs in-process, so nothing is
/// serialized.
sealed class AcquireLlamaSequenceResponse {
  const AcquireLlamaSequenceResponse();
}

final class AcquireLlamaSequenceSucceeded extends AcquireLlamaSequenceResponse {
  const AcquireLlamaSequenceSucceeded(this.sequenceId);

  final int sequenceId;
}

final class AcquireLlamaSequenceFailed extends AcquireLlamaSequenceResponse {
  const AcquireLlamaSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ReleaseLlamaSequenceResponse {
  const ReleaseLlamaSequenceResponse();
}

final class ReleaseLlamaSequenceSucceeded extends ReleaseLlamaSequenceResponse {
  const ReleaseLlamaSequenceSucceeded();
}

final class ReleaseLlamaSequenceFailed extends ReleaseLlamaSequenceResponse {
  const ReleaseLlamaSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ClearLlamaSequenceResponse {
  const ClearLlamaSequenceResponse();
}

final class ClearLlamaSequenceSucceeded extends ClearLlamaSequenceResponse {
  const ClearLlamaSequenceSucceeded();
}

final class ClearLlamaSequenceFailed extends ClearLlamaSequenceResponse {
  const ClearLlamaSequenceFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class SetLlamaSamplingResponse {
  const SetLlamaSamplingResponse();
}

final class SetLlamaSamplingSucceeded extends SetLlamaSamplingResponse {
  const SetLlamaSamplingSucceeded();
}

final class SetLlamaSamplingFailed extends SetLlamaSamplingResponse {
  const SetLlamaSamplingFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RemoveLlamaSequenceRangeResponse {
  const RemoveLlamaSequenceRangeResponse();
}

final class RemoveLlamaSequenceRangeSucceeded
    extends RemoveLlamaSequenceRangeResponse {
  const RemoveLlamaSequenceRangeSucceeded();
}

final class RemoveLlamaSequenceRangeFailed
    extends RemoveLlamaSequenceRangeResponse {
  const RemoveLlamaSequenceRangeFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RebuildLlamaSamplerResponse {
  const RebuildLlamaSamplerResponse();
}

final class RebuildLlamaSamplerSucceeded extends RebuildLlamaSamplerResponse {
  const RebuildLlamaSamplerSucceeded();
}

final class RebuildLlamaSamplerFailed extends RebuildLlamaSamplerResponse {
  const RebuildLlamaSamplerFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ReadLlamaKvSnapshotResponse {
  const ReadLlamaKvSnapshotResponse();
}

final class ReadLlamaKvSnapshotSucceeded extends ReadLlamaKvSnapshotResponse {
  const ReadLlamaKvSnapshotSucceeded(this.snapshot);

  final KvSnapshot snapshot;
}

final class ReadLlamaKvSnapshotFailed extends ReadLlamaKvSnapshotResponse {
  const ReadLlamaKvSnapshotFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class ReadLlamaSequenceCheckpointResponse {
  const ReadLlamaSequenceCheckpointResponse();
}

final class ReadLlamaSequenceCheckpointSucceeded
    extends ReadLlamaSequenceCheckpointResponse {
  const ReadLlamaSequenceCheckpointSucceeded(this.bytes);

  final Uint8List bytes;
}

final class ReadLlamaSequenceCheckpointFailed
    extends ReadLlamaSequenceCheckpointResponse {
  const ReadLlamaSequenceCheckpointFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class RestoreLlamaSequenceCheckpointResponse {
  const RestoreLlamaSequenceCheckpointResponse();
}

final class RestoreLlamaSequenceCheckpointSucceeded
    extends RestoreLlamaSequenceCheckpointResponse {
  const RestoreLlamaSequenceCheckpointSucceeded();
}

final class RestoreLlamaSequenceCheckpointFailed
    extends RestoreLlamaSequenceCheckpointResponse {
  const RestoreLlamaSequenceCheckpointFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class StepLlamaBatchResponse {
  const StepLlamaBatchResponse();
}

final class StepLlamaBatchSucceeded extends StepLlamaBatchResponse {
  const StepLlamaBatchSucceeded({
    required this.samples,
    required this.prefills,
  });

  final List<SampleSequenceResult> samples;
  final List<PrefillSequenceResult> prefills;
}

final class StepLlamaBatchFailed extends StepLlamaBatchResponse {
  const StepLlamaBatchFailed({
    required this.message,
    required this.stackTrace,
    this.backendCode,
  });

  final String message;
  final String stackTrace;
  final int? backendCode;
}
