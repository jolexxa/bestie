import 'dart:async';
import 'dart:isolate';

import 'package:isolate_worker/src/isolate/isolate_protocol.dart';
import 'package:isolate_worker/src/isolate/isolate_request_context.dart';
import 'package:isolate_worker/src/isolate/isolate_result.dart';

/// Handles a command received by the remote isolate.
typedef IsolateCommandHandler<Request, Response> =
    FutureOr<Response> Function(
      Request request,
      IsolateRequestContext context,
    );

/// A handle to a spawned isolate: detects termination and can force-kill.
abstract interface class SpawnedIsolate {
  /// Completes when the isolate terminates — gracefully or via [kill].
  Future<void> get onExit;

  /// Force-terminates the isolate immediately.
  void kill();

  /// Releases the exit listener. Call once [onExit] has completed.
  void cleanup();
}

/// Spawns isolates for [IsolateWorker].
// Injectable seam for tests.
abstract interface class IsolateSpawner {
  /// Spawns an isolate with [entryPoint] and [message].
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  });
}

/// Default isolate spawner backed by [Isolate.spawn].
final class DartIsolateSpawner implements IsolateSpawner {
  /// Creates a Dart isolate spawner.
  const DartIsolateSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) async {
    final isolate = await Isolate.spawn(
      entryPoint,
      message,
      debugName: debugName,
    );
    return _DartSpawnedIsolate(isolate);
  }
}

/// [SpawnedIsolate] backed by a real [Isolate].
final class _DartSpawnedIsolate implements SpawnedIsolate {
  _DartSpawnedIsolate(this._isolate) {
    _exitPort = RawReceivePort((_) {
      if (!_exit.isCompleted) _exit.complete();
    });
    _isolate.addOnExitListener(_exitPort.sendPort);
  }

  final Isolate _isolate;
  final Completer<void> _exit = Completer<void>();
  late final RawReceivePort _exitPort;

  @override
  Future<void> get onExit => _exit.future;

  @override
  void kill() => _isolate.kill(priority: Isolate.immediate);

  @override
  void cleanup() => _exitPort.close();
}

/// The result of spawning an isolate worker.
sealed class IsolateSpawnResult<Request, Response> {
  /// Creates an isolate spawn result.
  const IsolateSpawnResult();
}

/// A successful isolate spawn.
final class IsolateSpawnSucceeded<Request, Response>
    extends IsolateSpawnResult<Request, Response> {
  /// Creates a successful isolate spawn result containing [worker].
  const IsolateSpawnSucceeded(this.worker);

  /// The spawned isolate worker.
  final IsolateWorker<Request, Response> worker;
}

/// A failed isolate spawn.
final class IsolateSpawnFailed<Request, Response>
    extends IsolateSpawnResult<Request, Response> {
  /// Creates a failed isolate spawn result.
  const IsolateSpawnFailed({
    required this.message,
    required this.stackTrace,
  });

  /// The failure message.
  final String message;

  /// The failure stack trace.
  final String stackTrace;
}

/// Sends typed requests to a remote isolate and receives typed responses.
class IsolateWorker<Request, Response> {
  IsolateWorker._({
    required ReceivePort responses,
    required SendPort commands,
    required SpawnedIsolate isolate,
  }) : _responses = responses,
       _commands = commands,
       _isolate = isolate {
    _responses.listen(_handleResponse);
  }

  final ReceivePort _responses;
  final SendPort _commands;
  final SpawnedIsolate _isolate;
  final Map<int, Completer<IsolateResult<Response>>> _activeRequests = {};
  final _events = StreamController<Object?>.broadcast();

  var _idCounter = 0;
  var _closed = false;
  Future<void>? _closeFuture;

  /// Unsolicited events pushed by the remote isolate's command handlers.
  ///
  /// These ride the response port as uncorrelated frames, so the payload is
  /// whatever the handler emitted. Subscribe before issuing commands — the
  /// stream is broadcast and does not buffer.
  Stream<Object?> get events => _events.stream;

  /// Spawns an isolate worker.
  ///
  /// Requests and responses are sent object-mode — deep-copied by the VM.
  static Future<IsolateSpawnResult<Request, Response>>
  spawn<Request, Response>({
    required IsolateCommandHandler<Request, Response> commandHandler,
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
    String? debugName,
  }) async {
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();

    void handleInitialMessage(Object? initialMessage) {
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        initialMessage! as SendPort,
      ));
    }

    initPort.handler = handleInitialMessage;

    final SpawnedIsolate isolate;
    try {
      isolate = await isolateSpawner.spawn(
        _startRemoteIsolate<Request, Response>,
        (initPort.sendPort, commandHandler),
        debugName: debugName,
      );
    } on Object catch (error, stackTrace) {
      initPort.close();
      return IsolateSpawnFailed(
        message: error.toString(),
        stackTrace: stackTrace.toString(),
      );
    }

    final (responses, commands) = await connection.future;
    return IsolateSpawnSucceeded(
      IsolateWorker._(
        responses: responses,
        commands: commands,
        isolate: isolate,
      ),
    );
  }

  /// Sends [request] to the remote isolate.
  Future<IsolateResult<Response>> send(Request request) {
    return sendCancellable(request).result;
  }

  /// Sends [request] to the remote isolate and returns a cancellable run.
  IsolateRequestRun<Response> sendCancellable(Request request) {
    if (_closed) {
      return IsolateRequestRun._closed();
    }

    final id = _idCounter++;
    final completer = Completer<IsolateResult<Response>>.sync();

    _activeRequests[id] = completer;
    _commands.send(
      IsolateCommandRequest(
        id: id,
        payload: request,
      ),
    );

    return IsolateRequestRun._(
      result: completer.future,
      cancel: () {
        if (_activeRequests.containsKey(id)) {
          _commands.send(IsolateCommandCancelRequest(id: id));
        }
      },
    );
  }

  /// Cooperatively shuts down, then force-kills the isolate if it has not
  /// exited within [timeout]. Idempotent.
  Future<void> close({Duration timeout = const Duration(seconds: 5)}) {
    return _closeFuture ??= _close(timeout);
  }

  Future<void> _close(Duration timeout) async {
    _closed = true;
    _commands.send(const IsolateCommandShutdown());
    try {
      await _isolate.onExit.timeout(timeout);
    } on TimeoutException {
      _isolate.kill();
      await _isolate.onExit;
    }
    _isolate.cleanup();
    _failPendingRequests();
    _responses.close();
    if (!_events.isClosed) unawaited(_events.close());
  }

  void _failPendingRequests() {
    final pending = _activeRequests.values.toList();
    _activeRequests.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete(IsolateWorkerClosed<Response>());
      }
    }
  }

  void _handleResponse(Object? message) {
    if (message is _IsolateEvent) {
      if (!_events.isClosed) _events.add(message.payload);
      return;
    }

    final response = message! as IsolateResponse;
    final completer = _activeRequests.remove(response.id);

    if (completer == null) {
      return;
    }

    switch (response) {
      case IsolateResponseSuccess(:final payload):
        completer.complete(IsolateSucceeded(payload as Response));
      case IsolateResponseFailure(:final message, :final stackTrace):
        completer.complete(
          IsolateRemoteFailed(
            message: message,
            stackTrace: stackTrace,
          ),
        );
    }
  }
}

/// An active isolate request that can be cooperatively cancelled.
final class IsolateRequestRun<Response> {
  IsolateRequestRun._({
    required Future<IsolateResult<Response>> result,
    required void Function() cancel,
  }) : _result = result,
       _cancel = cancel;

  IsolateRequestRun._closed()
    : _result = Future.value(IsolateWorkerClosed<Response>()),
      _cancel = (() {});

  final Future<IsolateResult<Response>> _result;
  final void Function() _cancel;

  /// Completes when the remote handler settles.
  Future<IsolateResult<Response>> get result => _result;

  /// Requests cooperative cancellation without completing [result].
  void cancel() => _cancel();
}

final class _IsolateEvent {
  const _IsolateEvent(this.payload);

  final Object? payload;
}

final class _PortEventSink implements IsolateEventSink {
  const _PortEventSink(this._responses);

  final SendPort _responses;

  @override
  void emit(Object? event) => _responses.send(_IsolateEvent(event));
}

void _startRemoteIsolate<Request, Response>(
  (
    SendPort,
    IsolateCommandHandler<Request, Response>,
  )
  startMessage,
) {
  final (responses, handleCommand) = startMessage;
  final commands = ReceivePort();
  final cancellationTokens = <int, IsolateCancellationTokenSource>{};
  final eventSink = _PortEventSink(responses);

  responses.send(commands.sendPort);
  commands.listen((message) async {
    final command = message! as IsolateCommand;

    switch (command) {
      case IsolateCommandShutdown():
        for (final source in cancellationTokens.values) {
          source.cancel();
        }
        commands.close();
      case IsolateCommandCancelRequest(:final id):
        cancellationTokens[id]?.cancel();
      case IsolateCommandRequest(:final id, :final payload):
        final cancellation = IsolateCancellationTokenSource();
        cancellationTokens[id] = cancellation;
        try {
          final value = await handleCommand(
            payload as Request,
            IsolateRequestContext(
              cancellationToken: cancellation.token,
              events: eventSink,
            ),
          );
          responses.send(
            IsolateResponseSuccess(
              id: id,
              payload: value,
            ),
          );
          cancellationTokens.remove(id);
        } on Object catch (error, stackTrace) {
          responses.send(
            IsolateResponseFailure(
              id: id,
              message: error.toString(),
              stackTrace: stackTrace.toString(),
            ),
          );
          cancellationTokens.remove(id);
        }
    }
  });
}
