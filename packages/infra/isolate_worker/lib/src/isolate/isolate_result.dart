/// The result of sending a request to an isolate worker.
sealed class IsolateResult<Response> {
  /// Creates an isolate result.
  const IsolateResult();
}

/// A successful isolate response.
final class IsolateSucceeded<Response> extends IsolateResult<Response> {
  /// Creates a successful isolate response containing [value].
  const IsolateSucceeded(this.value);

  /// The decoded response value.
  final Response value;
}

/// A failed isolate response.
sealed class IsolateFailed<Response> extends IsolateResult<Response> {
  /// Creates a failed isolate response.
  const IsolateFailed({
    required this.message,
    required this.stackTrace,
  });

  /// The failure message.
  final String message;

  /// The failure stack trace.
  final String stackTrace;
}

/// A failure reported by the remote isolate.
final class IsolateRemoteFailed<Response> extends IsolateFailed<Response> {
  /// Creates a remote isolate failure.
  const IsolateRemoteFailed({
    required super.message,
    required super.stackTrace,
  });
}

/// A failure returned when a request is sent after the worker was closed.
final class IsolateWorkerClosed<Response> extends IsolateFailed<Response> {
  /// Creates a closed worker failure.
  const IsolateWorkerClosed()
    : super(message: 'IsolateWorker is closed.', stackTrace: '');
}
