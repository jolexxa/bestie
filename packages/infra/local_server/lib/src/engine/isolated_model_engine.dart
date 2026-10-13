import 'dart:async';

import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/engine/engine_messages.dart';
import 'package:local_server/src/model_engine.dart';

/// A [ModelEngine] running elsewhere, reached by sending it commands and
/// reading its replies. Every model it loads, and every completion on one,
/// is a proxy for the real one on the other side.
final class IsolatedModelEngine implements ModelEngine {
  IsolatedModelEngine({
    required void Function(EngineCommand command) send,
    required Stream<EngineReply> replies,
    required Future<void> Function() terminate,
    Duration closeTimeout = const Duration(seconds: 5),
  }) : _send = send,
       _terminate = terminate,
       _closeTimeout = closeTimeout {
    _replies = replies.listen(_receive);
  }

  final void Function(EngineCommand command) _send;
  final Future<void> Function() _terminate;
  final Duration _closeTimeout;
  late final StreamSubscription<EngineReply> _replies;
  final _calls = <int, _PendingCall<Object?>>{};
  final _loads = <int, StreamController<ModelEngineEvent>>{};
  final _runtimes = <int, _IsolatedRuntime>{};
  final _turns = <int, _IsolatedTurn>{};
  var _nextId = 0;
  String? _lostBecause;

  @override
  Stream<ModelEngineEvent> load(ModelEngineRequest request) {
    final lostBecause = _lostBecause;
    if (lostBecause != null) {
      return Stream.value(ModelEngineFailed(reason: lostBecause));
    }
    final loadId = _nextId++;
    final events = StreamController<ModelEngineEvent>(
      onListen: () => _send(LoadModelCommand(loadId: loadId, request: request)),
      onCancel: () {
        if (_loads.remove(loadId) != null) {
          _send(AbandonLoadCommand(loadId: loadId));
        }
      },
    );
    _loads[loadId] = events;
    return events.stream;
  }

  /// Asks the engine to close, waiting at most the close timeout, then
  /// stops it for good.
  @override
  Future<void> close() async {
    await _call<void>(
      (callId) => CloseEngineCall(callId: callId),
      failed: (_) {},
    ).timeout(_closeTimeout, onTimeout: () {});
    lose('The engine closed.');
    await _replies.cancel();
    await _terminate();
  }

  /// Fails everything waiting on the engine, which is gone for [reason].
  void lose(String reason) {
    _lostBecause ??= reason;
    for (final call in [..._calls.values]) {
      call.fail(reason);
    }
    _calls.clear();
    for (final events in _loads.values) {
      events
        ..add(ModelEngineFailed(reason: reason))
        ..close().ignore();
    }
    _loads.clear();
    for (final turn in [..._turns.values]) {
      turn.fail(reason);
    }
    _turns.clear();
  }

  Future<T> _call<T>(
    EngineCall Function(int callId) call, {
    required T Function(String message) failed,
  }) {
    final pending = _PendingCall<T>(failed);
    final lostBecause = _lostBecause;
    if (lostBecause != null) {
      pending.fail(lostBecause);
    } else {
      final callId = _nextId++;
      _calls[callId] = pending;
      _send(call(callId));
    }
    return pending.answer;
  }

  void _receive(EngineReply reply) => switch (reply) {
    CallAnswered(:final callId, :final answer) =>
      _calls.remove(callId)?.complete(answer),
    CallFailed(:final callId, :final message) =>
      _calls.remove(callId)?.fail(message),
    LoadStepped(:final loadId, :final step) => _loads[loadId]?.add(step),
    ModelProduced() => _produced(reply),
    LoadEnded(:final loadId) => _loads.remove(loadId)?.close(),
    PoolChanged(:final modelId, :final pool) => _runtimes[modelId]?.mirror(
      pool,
    ),
    TurnEvents() => _turns[reply.turnId]?.deliver(reply),
  };

  void _produced(ModelProduced produced) {
    final runtime = _IsolatedRuntime(this, produced);
    _runtimes[produced.modelId] = runtime;
    final model = _IsolatedLoadedModel(
      this,
      produced.modelId,
      runtime,
      produced,
    );
    final events = _loads.remove(produced.modelId);
    if (events == null) {
      unawaited(_discard(model));
      return;
    }
    events
      ..add(ModelEngineLoaded(model: model))
      ..close().ignore();
  }

  /// Unloads a model whose load was abandoned before it arrived.
  Future<void> _discard(LoadedModel model) async {
    await model.runtime.dispose();
    await model.unload();
  }

  Stream<EngineCompletionEvent> _openTurn(int turnId) {
    final turn = _IsolatedTurn(turnId, this);
    _turns[turnId] = turn;
    return turn.events;
  }
}

final class _PendingCall<T> {
  _PendingCall(this._failed);

  final T Function(String message) _failed;
  final _answer = Completer<T>();

  Future<T> get answer => _answer.future;

  void complete(Object? answer) => _answer.complete(answer as T);

  void fail(String message) => _answer.complete(_failed(message));
}

final class _IsolatedLoadedModel implements LoadedModel {
  _IsolatedLoadedModel(
    this._engine,
    this._modelId,
    this.runtime,
    this._produced,
  );

  final IsolatedModelEngine _engine;
  final int _modelId;
  final ModelProduced _produced;

  @override
  final EngineCompletionRuntime runtime;

  @override
  int get deviceBytes => _produced.deviceBytes;

  @override
  Future<void> unload() async {
    _engine._runtimes.remove(_modelId);
    await _engine._call<void>(
      (callId) => UnloadModelCall(callId: callId, modelId: _modelId),
      failed: (_) {},
    );
  }
}

final class _IsolatedRuntime implements EngineCompletionRuntime {
  _IsolatedRuntime(this._engine, ModelProduced produced)
    : _modelId = produced.modelId,
      contextSize = produced.contextSize,
      maxAgents = produced.maxAgents,
      _pool = produced.pool;

  final IsolatedModelEngine _engine;
  final int _modelId;
  final _poolChanges = StreamController<PoolSnapshot>.broadcast();
  PoolSnapshot _pool;

  @override
  final int contextSize;

  @override
  final int maxAgents;

  @override
  PoolSnapshot get pool => _pool;

  @override
  Stream<PoolSnapshot> get poolChanges => _poolChanges.stream;

  void mirror(PoolSnapshot pool) {
    _pool = pool;
    if (!_poolChanges.isClosed) _poolChanges.add(pool);
  }

  @override
  Future<AgentOpenOutcome> openPrimary(String agentId) => _engine._call(
    (callId) =>
        OpenPrimaryCall(callId: callId, modelId: _modelId, agentId: agentId),
    failed: _openFailed,
  );

  @override
  Future<AgentOpenOutcome> openSubagent(String agentId) => _engine._call(
    (callId) =>
        OpenSubagentCall(callId: callId, modelId: _modelId, agentId: agentId),
    failed: _openFailed,
  );

  static AgentOpenOutcome _openFailed(String message) =>
      AgentLeaseFailed(message: message);

  @override
  Future<AgentCloseOutcome> close(String agentId) => _engine._call(
    (callId) =>
        CloseAgentCall(callId: callId, modelId: _modelId, agentId: agentId),
    failed: (message) => AgentCloseFailed(message: message),
  );

  @override
  Future<void> closeAll() => _engine._call<void>(
    (callId) => CloseAllAgentsCall(callId: callId, modelId: _modelId),
    failed: (_) {},
  );

  @override
  Future<EngineCompletionStart> complete(
    EngineCompletionRequest request,
  ) async {
    final turnId = _engine._nextId++;
    final rejected = await _engine._call<EngineCompletionRejected?>(
      (callId) => CompleteCall(
        callId: callId,
        modelId: _modelId,
        turnId: turnId,
        request: request,
      ),
      failed: (message) => EngineCompletionRejected(
        reason: EngineCompletionRejection.engineFailed,
        message: message,
      ),
    );
    return rejected ?? EngineCompletionStarted(_engine._openTurn(turnId));
  }

  @override
  Future<void> dispose() async {
    await _engine._call<void>(
      (callId) => DisposeRuntimeCall(callId: callId, modelId: _modelId),
      failed: (_) {},
    );
    await _poolChanges.close();
  }
}

/// A completion's events as they arrive from the engine, pulled one batch
/// at a time while someone is listening and not paused. The engine sends
/// the first batch on its own.
final class _IsolatedTurn {
  _IsolatedTurn(this._turnId, this._engine) {
    _events = StreamController(
      onListen: _pull,
      onResume: _pull,
      onCancel: () {
        if (_engine._turns.remove(_turnId) != null) {
          _engine._send(CancelTurnCommand(turnId: _turnId));
        }
      },
    );
  }

  final int _turnId;
  final IsolatedModelEngine _engine;
  late final StreamController<EngineCompletionEvent> _events;
  var _pulled = true;

  Stream<EngineCompletionEvent> get events => _events.stream;

  void deliver(TurnEvents batch) {
    _pulled = false;
    batch.events.forEach(_events.add);
    if (batch.ended) {
      _engine._turns.remove(_turnId);
      _events.close().ignore();
    } else if (!_events.isPaused) {
      _pull();
    }
  }

  void fail(String message) {
    _events
      ..add(
        EngineCompletionFailed(
          failure: EngineCompletionFailure.engineFailed,
          message: message,
        ),
      )
      ..close().ignore();
  }

  /// Asks for the next batch unless one is already on its way.
  void _pull() {
    if (_pulled) return;
    _pulled = true;
    _engine._send(PullTurnCommand(turnId: _turnId));
  }
}
