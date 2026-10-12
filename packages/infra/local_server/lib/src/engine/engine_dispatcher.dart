import 'dart:async';

import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/engine/engine_messages.dart';
import 'package:local_server/src/model_engine.dart';

/// Serves an engine's loads, models, and completions to commands from
/// another isolate, answering through the given send.
final class EngineDispatcher {
  EngineDispatcher({
    required ModelEngine engine,
    required void Function(EngineReply reply) send,
  }) : _engine = engine,
       _send = send;

  final ModelEngine _engine;
  final void Function(EngineReply reply) _send;
  final _loads = <int, StreamSubscription<ModelEngineEvent>>{};
  final _models = <int, _ForwardedModel>{};
  final _turns = <int, _TurnRelay>{};

  void handle(EngineCommand command) => switch (command) {
    LoadModelCommand() => _load(command),
    AbandonLoadCommand(:final loadId) => _loads.remove(loadId)?.cancel(),
    PullTurnCommand(:final turnId) => _turns[turnId]?.pull(),
    CancelTurnCommand(:final turnId) => _turns.remove(turnId)?.cancel(),
    EngineCall() => _answer(command),
  };

  void _load(LoadModelCommand command) {
    final loadId = command.loadId;
    _loads[loadId] = _engine
        .load(command.request)
        .listen(
          (event) => switch (event) {
            final ModelEngineStep step => _send(
              LoadStepped(loadId: loadId, step: step),
            ),
            ModelEngineLoaded(:final model) => _forward(loadId, model),
          },
          onError: (Object error) => _send(
            LoadStepped(
              loadId: loadId,
              step: ModelEngineFailed(reason: '$error'),
            ),
          ),
          onDone: () {
            _loads.remove(loadId);
            _send(LoadEnded(loadId: loadId));
          },
        );
  }

  void _forward(int modelId, LoadedModel model) {
    final runtime = model.runtime;
    _models[modelId] = _ForwardedModel(
      model,
      runtime.poolChanges.listen(
        (pool) => _send(PoolChanged(modelId: modelId, pool: pool)),
      ),
    );
    _send(
      ModelProduced(
        modelId: modelId,
        contextSize: runtime.contextSize,
        maxAgents: runtime.maxAgents,
        deviceBytes: model.deviceBytes,
        pool: runtime.pool,
      ),
    );
  }

  Future<void> _answer(EngineCall call) async {
    try {
      _send(CallAnswered(callId: call.callId, answer: await _perform(call)));
    } on Object catch (error) {
      _send(CallFailed(callId: call.callId, message: '$error'));
    }
  }

  Future<Object?> _perform(EngineCall call) => switch (call) {
    OpenPrimaryCall(:final agentId) => _runtime(call).openPrimary(agentId),
    OpenSubagentCall(:final agentId) => _runtime(call).openSubagent(agentId),
    CloseAgentCall(:final agentId) => _runtime(call).close(agentId),
    CloseAllAgentsCall() => _runtime(call).closeAll(),
    CompleteCall() => _complete(call),
    DisposeRuntimeCall() => _disposeRuntime(call),
    UnloadModelCall(:final modelId) => _unload(modelId),
    CloseEngineCall() => _close(),
  };

  EngineCompletionRuntime _runtime(ModelCall call) =>
      _loadedModel(call.modelId).runtime;

  LoadedModel _loadedModel(int modelId) =>
      (_models[modelId] ?? (throw StateError('Model $modelId is not loaded.')))
          .model;

  Future<EngineCompletionRejected?> _complete(CompleteCall call) async {
    switch (await _runtime(call).complete(call.request)) {
      case final EngineCompletionRejected rejected:
        return rejected;
      case EngineCompletionStarted(:final events):
        final turnId = call.turnId;
        _turns[turnId] = _TurnRelay(
          turnId: turnId,
          events: events,
          send: _send,
          onEnded: () => _turns.remove(turnId),
        );
        return null;
    }
  }

  Future<void> _disposeRuntime(DisposeRuntimeCall call) async {
    await _runtime(call).dispose();
    await _models[call.modelId]?.poolForwarding.cancel();
  }

  Future<void> _unload(int modelId) async {
    final model = _loadedModel(modelId);
    _models.remove(modelId);
    await model.unload();
  }

  Future<void> _close() async {
    await Future.wait([for (final load in _loads.values) load.cancel()]);
    _loads.clear();
    await _engine.close();
  }
}

final class _ForwardedModel {
  _ForwardedModel(this.model, this.poolForwarding);

  final LoadedModel model;

  final StreamSubscription<PoolSnapshot> poolForwarding;
}

/// Holds a completion's events until the server pulls them, merging
/// adjacent deltas and keeping only the newest of adjacent prefill progress
/// so a slow server receives fewer, larger batches. The
/// completion itself never waits on the server.
final class _TurnRelay {
  _TurnRelay({
    required this.turnId,
    required Stream<EngineCompletionEvent> events,
    required void Function(EngineReply reply) send,
    required void Function() onEnded,
  }) : _send = send,
       _onEnded = onEnded {
    _subscription = events.listen(
      _hold,
      onError: (Object error) => _hold(
        EngineCompletionFailed(
          failure: EngineCompletionFailure.engineFailed,
          message: '$error',
        ),
      ),
      onDone: () {
        _ended = true;
        _flush();
      },
    );
  }

  final int turnId;
  final void Function(EngineReply reply) _send;
  final void Function() _onEnded;
  late final StreamSubscription<EngineCompletionEvent> _subscription;
  final _held = <EngineCompletionEvent>[];
  var _pulls = 0;
  var _ended = false;

  void pull() {
    _pulls++;
    _flush();
  }

  Future<void> cancel() => _subscription.cancel();

  void _hold(EngineCompletionEvent event) {
    final last = _held.lastOrNull;
    final merged = switch (event) {
      EngineCompletionTextDelta(:final text, :final tokens)
          when last is EngineCompletionTextDelta =>
        EngineCompletionTextDelta(
          '${last.text}$text',
          tokens: last.tokens + tokens,
        ),
      EngineCompletionReasoningDelta(:final text, :final tokens)
          when last is EngineCompletionReasoningDelta =>
        EngineCompletionReasoningDelta(
          '${last.text}$text',
          tokens: last.tokens + tokens,
        ),
      EngineCompletionPrefillProgressed()
          when last is EngineCompletionPrefillProgressed =>
        event,
      _ => null,
    };
    if (merged == null) {
      _held.add(event);
    } else {
      _held.last = merged;
    }
    _flush();
  }

  void _flush() {
    if (_pulls == 0 || (_held.isEmpty && !_ended)) return;
    _pulls--;
    _send(TurnEvents(turnId: turnId, events: [..._held], ended: _ended));
    _held.clear();
    if (_ended) _onEnded();
  }
}
