import 'dart:async';
import 'dart:math' as math;

import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference/inference.dart';
import 'package:inference_llama/inference_llama.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:inference_server/inference_server.dart';
import 'package:intentions/intentions.dart';
import 'package:llm_model_templates/llm_model_templates.dart';

/// The context settings every model loads with: flash attention, a KV cache
/// shared by every sequence (q8_0, the options' default), and a ring of
/// checkpoints for models whose reused prefixes need restoring.
@model
abstract final class LlamaServerDefaults {
  static const batchTokens = 512;
  static const contextCheckpoints = 4;

  /// The smallest context worth loading a model with.
  static const minimumContext = 2048;

  /// Memory left free on each GPU, as a share of its total.
  static const double gpuHeadroomShare = 0.10;

  /// Memory left free on the host.
  static const int hostHeadroomBytes = 512 * 1024 * 1024;
}

/// Loads models with llama.cpp and serves them through the completion
/// runtime.
@dataSource
final class LlamaModelEngine implements ModelEngine {
  LlamaModelEngine({
    required LlamaModelLoader loader,
    required int threads,
    required ServerLog log,
    required Future<void> Function() closeNative,
  }) : _loader = loader,
       _threads = threads,
       _log = log,
       _closeNative = closeNative;

  final LlamaModelLoader _loader;
  final int _threads;
  final ServerLog _log;
  final Future<void> Function() _closeNative;
  final _loads = <Future<void>>{};

  /// Loads once listened to. A listener that leaves stops the load at the
  /// next stage, freeing whatever it already holds.
  @override
  Stream<ModelEngineEvent> load(ModelEngineRequest request) {
    late final StreamController<ModelEngineEvent> events;
    events = StreamController<ModelEngineEvent>(
      sync: true,
      onListen: () {
        late final Future<void> loading;
        loading = _load(request, events.add, wanted: () => events.hasListener)
            .catchError(
              (Object error) => events.add(ModelEngineFailed(reason: '$error')),
            )
            .whenComplete(() {
              _loads.remove(loading);
              return events.close();
            });
        _loads.add(loading);
      },
    );
    return events.stream;
  }

  /// Waits for loads still running to wind down, then frees the loader and
  /// the native libraries they use.
  @override
  Future<void> close() async {
    await Future.wait([..._loads]);
    switch (await _loader.close()) {
      case LlamaModelLoaderClosed():
        break;
      case LlamaModelLoaderCloseRefused(:final liveModels):
        _log.error('$liveModels models were still loaded at shutdown.');
    }
    await _closeNative();
  }

  Future<void> _load(
    ModelEngineRequest request,
    void Function(ModelEngineEvent event) emit, {
    required bool Function() wanted,
  }) async {
    final entry = request.entry;
    final profile = ModelProfiles.profileFor(entry.profileId);

    final List<LlamaDeviceInfo> devices;
    switch (await _loader.getDeviceInfo()) {
      case LlamaDeviceInfoSucceeded(devices: final found):
        devices = found;
      case LlamaDeviceInfoFailed(:final message):
        return emit(ModelEngineFailed(reason: message));
    }

    final trained = entry.trainedContextLength;
    final cap = math.min(request.contextCap ?? trained, trained);
    final options = LlamaContextOptions(
      contextSize: cap,
      nBatch: LlamaServerDefaults.batchTokens,
      nThreads: _threads,
      nThreadsBatch: _threads,
      useFlashAttn: true,
      maxSequences: request.maxAgents,
      useUnifiedKvCache: true,
      contextCheckpointCount: LlamaServerDefaults.contextCheckpoints,
    );
    final BestFitMaxContextResult fit;
    switch (await _loader.fitMaxContext(
      LlamaFitMaxContextRequest(
        path: entry.path,
        contextOptions: options,
        minContextSize: math.min(LlamaServerDefaults.minimumContext, cap),
        maxContextSize: cap,
        headroomBytesByDevice: _headroomFor(devices),
      ),
    )) {
      case LlamaFitMaxContextSucceeded(:final result) when result.fits:
        fit = result;
      case LlamaFitMaxContextSucceeded(:final result):
        return emit(
          ModelEngineFailed(
            reason: 'The model does not fit in memory. ${result.errorMessage}',
          ),
        );
      case LlamaFitMaxContextFailed(:final message):
        return emit(ModelEngineFailed(reason: message));
    }
    _log.info(
      'Fitted ${entry.localId} at ${fit.chosenContextSize} tokens: '
      '${fit.usedBytes} bytes used of ${fit.freeBytes} free, '
      '${fit.totalBytes} total; devices: ${devices.map(_describe).join(', ')}.',
    );
    emit(ModelEngineFitted(contextSize: fit.chosenContextSize));
    if (!wanted()) return;

    final LlamaModel model;
    switch (await _loader.load(
      LlamaModelLoadRequest(path: entry.path),
      onProgress: (progress) => emit(ModelEngineProgressed(progress: progress)),
    )) {
      case LlamaLoadModelSucceeded(model: final loaded):
        model = loaded;
      case LlamaLoadModelFailed(:final message):
        return emit(ModelEngineFailed(reason: message));
    }
    if (!wanted()) {
      await model.dispose();
      return;
    }

    final Context context;
    switch (await model.createContext(
      LlamaCreateContextRequest(
        options: options.copyWith(contextSize: fit.chosenContextSize),
      ),
    )) {
      case LlamaCreateContextSucceeded(context: final created):
        context = created;
      case LlamaCreateContextFailed(:final message):
        await model.dispose();
        return emit(ModelEngineFailed(reason: message));
    }

    final envelope = context.envelope;
    if (envelope.perSequenceLimit < envelope.contextSize) {
      await context.dispose();
      await model.dispose();
      return emit(
        ModelEngineFailed(
          reason:
              'The KV cache is not unified: each sequence holds '
              '${envelope.perSequenceLimit} of ${envelope.contextSize} '
              'tokens.',
        ),
      );
    }

    final allocator = LeaseAllocator(context: context);
    final defaults = entry.defaultSampling;
    final loaded = _LlamaLoadedModel(
      runtime: ScheduledCompletionRuntime(
        allocator: allocator,
        scheduler: BatchingSequenceScheduler(
          sequences: context.sequences,
          allocator: allocator,
          contextCheckpointCount: LlamaServerDefaults.contextCheckpoints,
        ),
        tokenizer: model.tokenizer,
        profile: profile,
        defaultSampling: EngineSampling(
          temperature: defaults.temperature,
          topK: defaults.topK,
          topP: defaults.topP,
          minP: defaults.minP,
        ),
      ),
      deviceBytes: fit.usedBytes,
      context: context,
      model: model,
    );
    if (wanted()) return emit(ModelEngineLoaded(model: loaded));
    await loaded.runtime.dispose();
    await loaded.unload();
  }

  static String _describe(LlamaDeviceInfo device) =>
      '${device.name} (${device.type.name})';

  /// One headroom per GPU, in device order, then the host's.
  static List<int> _headroomFor(List<LlamaDeviceInfo> devices) => [
    for (final device in devices)
      if (device.type == LlamaDeviceType.gpu ||
          device.type == LlamaDeviceType.integratedGpu)
        (device.totalMemory * LlamaServerDefaults.gpuHeadroomShare).round(),
    LlamaServerDefaults.hostHeadroomBytes,
  ];
}

@dataSource
final class _LlamaLoadedModel implements LoadedModel {
  _LlamaLoadedModel({
    required this.runtime,
    required this.deviceBytes,
    required Context context,
    required LlamaModel model,
  }) : _context = context,
       _model = model;

  @override
  final CompletionRuntime runtime;

  @override
  final int deviceBytes;

  final Context _context;
  final LlamaModel _model;

  @override
  Future<void> unload() async {
    await _context.dispose();
    await _model.dispose();
  }
}
