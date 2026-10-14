import 'dart:convert';
import 'dart:ffi';
import 'dart:math' as math;

import 'package:engine_llama/src/native/llama_native_params.dart';
import 'package:engine_llama/src/native/models/models.dart';
import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Native fit prediction client.
// ignore: one_member_abstracts, a seam so callers can mock the native predictor.
abstract interface class BestFitApi {
  /// Predicts the largest fitting context size between [minContextSize] and
  /// [maxContextSize].
  BestFitMaxContextResult fitMaxContext({
    required String modelPath,
    required LlamaModelOptions modelOptions,
    required LlamaContextOptions contextOptions,
    required int minContextSize,
    required int maxContextSize,
    required List<int> headroomBytesByDevice,
  });
}

/// Client for the fork's native best_fit prediction APIs.
final class BestFitClient implements BestFitApi {
  /// Creates a best_fit client from llama.cpp bindings.
  const BestFitClient({
    required LlamaCppBindings llamaBindings,
    required LlamaCppBindings commonBindings,
  }) : _llamaBindings = llamaBindings,
       _commonBindings = commonBindings;

  final LlamaCppBindings _llamaBindings;
  final LlamaCppBindings _commonBindings;

  @override
  BestFitMaxContextResult fitMaxContext({
    required String modelPath,
    required LlamaModelOptions modelOptions,
    required LlamaContextOptions contextOptions,
    required int minContextSize,
    required int maxContextSize,
    required List<int> headroomBytesByDevice,
  }) {
    final pathPtr = modelPath.toNativeUtf8(allocator: calloc).cast<Char>();
    final modelParamsPtr = calloc<llama_model_params>();
    final contextParamsPtr = calloc<llama_context_params>();
    final headroomPtr = calloc<Size>(BEST_FIT_MAX_DEVICES + 1);
    try {
      for (var device = 0; device <= BEST_FIT_MAX_DEVICES; device += 1) {
        headroomPtr[device] = _headroomAt(headroomBytesByDevice, device);
      }
      modelParamsPtr.ref = _llamaBindings.modelParamsFor(modelOptions);
      contextParamsPtr.ref = _llamaBindings.contextParamsFor(contextOptions);

      final result = _commonBindings.best_fit_max_ctx(
        pathPtr,
        modelParamsPtr,
        contextParamsPtr,
        headroomPtr,
        minContextSize,
        maxContextSize,
      );
      return BestFitMaxContextResult(
        status: _statusFor(result.status),
        chosenContextSize: result.n_ctx_chosen,
        devices: _devicesOf(result.prediction_at_chosen),
        nIterations: result.n_iterations,
        errorMessage: _arrayToString(result.error_msg, 256),
      );
    } finally {
      calloc
        ..free(headroomPtr)
        ..free(contextParamsPtr)
        ..free(modelParamsPtr)
        ..free(pathPtr);
    }
  }
}

BestFitStatus _statusFor(best_fit_status status) => switch (status) {
  best_fit_status.BEST_FIT_STATUS_SUCCESS => BestFitStatus.success,
  best_fit_status.BEST_FIT_STATUS_FAILURE => BestFitStatus.failure,
  best_fit_status.BEST_FIT_STATUS_ERROR => BestFitStatus.error,
};

List<BestFitDeviceUsage> _devicesOf(best_fit_prediction prediction) => [
  for (
    var index = 0;
    index <= math.min(prediction.n_devices, BEST_FIT_MAX_DEVICES);
    index += 1
  )
    BestFitDeviceUsage(
      name: _arrayToString(prediction.devices[index].name, 128),
      usedBytes: prediction.devices[index].total_used_bytes,
      freeBytes: prediction.devices[index].free_bytes,
      totalBytes: prediction.devices[index].total_bytes,
    ),
];

int _headroomAt(List<int> headroomBytesByDevice, int index) {
  if (headroomBytesByDevice.isEmpty) return 0;
  if (index < headroomBytesByDevice.length) {
    return headroomBytesByDevice[index];
  }
  return headroomBytesByDevice.last;
}

String _arrayToString(Array<Char> chars, int length) {
  final bytes = <int>[];
  for (var index = 0; index < length; index += 1) {
    final byte = chars[index] & 0xff;
    if (byte == 0) break;
    bytes.add(byte);
  }
  return bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);
}
