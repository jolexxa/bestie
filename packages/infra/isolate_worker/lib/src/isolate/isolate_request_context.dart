import 'dart:async';

abstract interface class IsolateCancellationToken {
  bool get isCancellationRequested;

  Future<void> get cancelled;
}

/// Pushes unsolicited events from the remote isolate back to the host.
///
/// The sink is worker-scoped, not request-scoped: a handler may retain it and
/// emit at any time — including from a background loop, long after the request
/// that handed it over has returned.
abstract interface class IsolateEventSink {
  void emit(Object? event);
}

final class _NoopEventSink implements IsolateEventSink {
  const _NoopEventSink();

  @override
  void emit(Object? event) {}
}

final class IsolateRequestContext {
  const IsolateRequestContext({
    required this.cancellationToken,
    this.events = const _NoopEventSink(),
  });

  static const none = IsolateRequestContext(
    cancellationToken: NeverCancelledIsolateCancellationToken(),
  );

  final IsolateCancellationToken cancellationToken;

  /// Pushes events from the remote isolate onto the host's event stream.
  final IsolateEventSink events;
}

final class NeverCancelledIsolateCancellationToken
    implements IsolateCancellationToken {
  const NeverCancelledIsolateCancellationToken();

  @override
  bool get isCancellationRequested => false;

  @override
  Future<void> get cancelled => Completer<void>().future;
}

final class IsolateCancellationTokenSource {
  final _completer = Completer<void>.sync();
  late final IsolateCancellationToken token = _IsolateCancellationToken(
    _completer,
  );

  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }
}

final class _IsolateCancellationToken implements IsolateCancellationToken {
  const _IsolateCancellationToken(this._completer);

  final Completer<void> _completer;

  @override
  bool get isCancellationRequested => _completer.isCompleted;

  @override
  Future<void> get cancelled => _completer.future;
}
