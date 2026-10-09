import 'dart:convert';
import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:inference_llama/src/native/llama_native_params.dart';
import 'package:inference_llama/src/native/models/models.dart';
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
      final aggregate = _aggregatePrediction(result.prediction_at_chosen);
      return BestFitMaxContextResult(
        status: _statusFor(result.status),
        chosenContextSize: result.n_ctx_chosen,
        usedBytes: aggregate.usedBytes,
        freeBytes: aggregate.freeBytes,
        totalBytes: aggregate.totalBytes,
        nIterations: result.n_iterations,
        errorMessage: _arrayToString(result.error_msg),
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

_DeviceTotals _aggregatePrediction(best_fit_prediction prediction) {
  var usedBytes = 0;
  var freeBytes = 0;
  var totalBytes = 0;
  final count = math.min(prediction.n_devices, BEST_FIT_MAX_DEVICES);
  for (var index = 0; index <= count; index += 1) {
    final device = prediction.devices[index];
    usedBytes += device.total_used_bytes;
    freeBytes += device.free_bytes;
    totalBytes += device.total_bytes;
  }
  return _DeviceTotals(
    usedBytes: usedBytes,
    freeBytes: freeBytes,
    totalBytes: totalBytes,
  );
}

final class _DeviceTotals {
  const _DeviceTotals({
    required this.usedBytes,
    required this.freeBytes,
    required this.totalBytes,
  });

  final int usedBytes;
  final int freeBytes;
  final int totalBytes;
}

int _headroomAt(List<int> headroomBytesByDevice, int index) {
  if (headroomBytesByDevice.isEmpty) return 0;
  if (index < headroomBytesByDevice.length) {
    return headroomBytesByDevice[index];
  }
  return headroomBytesByDevice.last;
}

String _arrayToString(Array<Char> chars) {
  final bytes = <int>[];
  for (var index = 0; index < 256; index += 1) {
    final byte = chars[index] & 0xff;
    if (byte == 0) break;
    bytes.add(byte);
  }
  return bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);
}
