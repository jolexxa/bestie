import 'package:inference/inference.dart';
import 'package:inference_llama/src/native/models/models.dart';

export 'native/models/models.dart';

final class LlamaModelLoadRequest {
  const LlamaModelLoadRequest({
    required this.path,
    this.options = const LlamaModelOptions(),
  });

  final String path;
  final LlamaModelOptions options;
}

sealed class LlamaDeviceInfoResult {
  const LlamaDeviceInfoResult();
}

final class LlamaDeviceInfoSucceeded extends LlamaDeviceInfoResult {
  const LlamaDeviceInfoSucceeded(this.devices);

  final List<LlamaDeviceInfo> devices;
}

final class LlamaDeviceInfoFailed extends LlamaDeviceInfoResult {
  const LlamaDeviceInfoFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

final class LlamaFitMaxContextRequest {
  const LlamaFitMaxContextRequest({
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

sealed class LlamaFitMaxContextResult {
  const LlamaFitMaxContextResult();
}

final class LlamaFitMaxContextSucceeded extends LlamaFitMaxContextResult {
  const LlamaFitMaxContextSucceeded(this.result);

  final BestFitMaxContextResult result;
}

final class LlamaFitMaxContextFailed extends LlamaFitMaxContextResult {
  const LlamaFitMaxContextFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

final class LlamaCreateContextRequest {
  const LlamaCreateContextRequest({
    required this.options,
  });

  final LlamaContextOptions options;
}

sealed class LlamaCreateContextResult {
  const LlamaCreateContextResult();
}

final class LlamaCreateContextSucceeded extends LlamaCreateContextResult {
  const LlamaCreateContextSucceeded(this.context);

  final Context context;
}

final class LlamaCreateContextFailed extends LlamaCreateContextResult {
  const LlamaCreateContextFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
