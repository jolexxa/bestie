import 'package:inference_llama/src/native/models/models.dart';

/// Requests handled by the model worker. Sent object-mode across the isolate.
sealed class LlamaModelRequest {
  const LlamaModelRequest();
}

final class LoadLlamaModel extends LlamaModelRequest {
  const LoadLlamaModel({
    required this.requestId,
    required this.path,
    this.options = const LlamaModelOptions(),
  });

  /// Tags the progress events this load emits.
  final int requestId;
  final String path;
  final LlamaModelOptions options;
}

final class DisposeLlamaModel extends LlamaModelRequest {
  const DisposeLlamaModel(this.modelId);

  final int modelId;
}

/// Frees every model the worker still holds, whoever loaded it.
final class DisposeAllLlamaModels extends LlamaModelRequest {
  const DisposeAllLlamaModels();
}

/// Reads the backend's per-device memory info.
final class GetLlamaDeviceInfo extends LlamaModelRequest {
  const GetLlamaDeviceInfo();
}

/// Predicts the largest context size that fits for a model on this device,
/// without loading it.
final class FitMaxLlamaModel extends LlamaModelRequest {
  const FitMaxLlamaModel({
    required this.path,
    required this.contextOptions,
    required this.minContextSize,
    required this.maxContextSize,
    required this.headroomBytesByDevice,
    this.options = const LlamaModelOptions(),
  });

  final String path;
  final LlamaModelOptions options;
  final LlamaContextOptions contextOptions;
  final int minContextSize;
  final int maxContextSize;
  final List<int> headroomBytesByDevice;
}

/// Responses returned by the model worker, one wrapper per request kind.
sealed class LlamaModelResponse {
  const LlamaModelResponse();
}

final class LoadLlamaModelResponded extends LlamaModelResponse {
  const LoadLlamaModelResponded(this.response);

  final LoadLlamaModelResponse response;
}

final class DisposeLlamaModelResponded extends LlamaModelResponse {
  const DisposeLlamaModelResponded(this.response);

  final DisposeLlamaModelResponse response;
}

final class DisposeAllLlamaModelsResponded extends LlamaModelResponse {
  const DisposeAllLlamaModelsResponded(this.response);

  final DisposeAllLlamaModelsResponse response;
}

final class GetLlamaDeviceInfoResponded extends LlamaModelResponse {
  const GetLlamaDeviceInfoResponded(this.response);

  final GetLlamaDeviceInfoResponse response;
}

final class FitMaxLlamaModelResponded extends LlamaModelResponse {
  const FitMaxLlamaModelResponded(this.response);

  final FitMaxLlamaModelResponse response;
}

sealed class LoadLlamaModelResponse {
  const LoadLlamaModelResponse();
}

final class LoadLlamaModelSucceeded extends LoadLlamaModelResponse {
  const LoadLlamaModelSucceeded({
    required this.modelId,
    required this.modelAddress,
  });

  final int modelId;
  final int modelAddress;
}

final class LoadLlamaModelFailed extends LoadLlamaModelResponse {
  const LoadLlamaModelFailed({required this.message, required this.stackTrace});

  final String message;
  final String stackTrace;
}

sealed class DisposeLlamaModelResponse {
  const DisposeLlamaModelResponse();
}

final class DisposeLlamaModelSucceeded extends DisposeLlamaModelResponse {
  const DisposeLlamaModelSucceeded();
}

final class DisposeLlamaModelFailed extends DisposeLlamaModelResponse {
  const DisposeLlamaModelFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class DisposeAllLlamaModelsResponse {
  const DisposeAllLlamaModelsResponse();
}

final class DisposeAllLlamaModelsSucceeded
    extends DisposeAllLlamaModelsResponse {
  const DisposeAllLlamaModelsSucceeded({required this.disposedCount});

  final int disposedCount;
}

final class DisposeAllLlamaModelsFailed extends DisposeAllLlamaModelsResponse {
  const DisposeAllLlamaModelsFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class GetLlamaDeviceInfoResponse {
  const GetLlamaDeviceInfoResponse();
}

final class GetLlamaDeviceInfoSucceeded extends GetLlamaDeviceInfoResponse {
  const GetLlamaDeviceInfoSucceeded(this.devices);

  final List<LlamaDeviceInfo> devices;
}

final class GetLlamaDeviceInfoFailed extends GetLlamaDeviceInfoResponse {
  const GetLlamaDeviceInfoFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class FitMaxLlamaModelResponse {
  const FitMaxLlamaModelResponse();
}

final class FitMaxLlamaModelSucceeded extends FitMaxLlamaModelResponse {
  const FitMaxLlamaModelSucceeded(this.result);

  final BestFitMaxContextResult result;
}

final class FitMaxLlamaModelFailed extends FitMaxLlamaModelResponse {
  const FitMaxLlamaModelFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

/// The failed response matching [request]'s kind.
LlamaModelResponse failedLlamaModelResponse(
  LlamaModelRequest request,
  String message,
  String stackTrace,
) {
  return switch (request) {
    LoadLlamaModel() => LoadLlamaModelResponded(
      LoadLlamaModelFailed(message: message, stackTrace: stackTrace),
    ),
    DisposeLlamaModel() => DisposeLlamaModelResponded(
      DisposeLlamaModelFailed(message: message, stackTrace: stackTrace),
    ),
    DisposeAllLlamaModels() => DisposeAllLlamaModelsResponded(
      DisposeAllLlamaModelsFailed(message: message, stackTrace: stackTrace),
    ),
    GetLlamaDeviceInfo() => GetLlamaDeviceInfoResponded(
      GetLlamaDeviceInfoFailed(message: message, stackTrace: stackTrace),
    ),
    FitMaxLlamaModel() => FitMaxLlamaModelResponded(
      FitMaxLlamaModelFailed(message: message, stackTrace: stackTrace),
    ),
  };
}
