/// Envelopes exchanged between the host and a remote isolate worker.
library;

sealed class IsolateCommand {
  const IsolateCommand();
}

final class IsolateCommandRequest extends IsolateCommand {
  const IsolateCommandRequest({
    required this.id,
    required this.payload,
  });

  final int id;
  final Object? payload;
}

final class IsolateCommandShutdown extends IsolateCommand {
  const IsolateCommandShutdown();
}

final class IsolateCommandCancelRequest extends IsolateCommand {
  const IsolateCommandCancelRequest({required this.id});

  final int id;
}

sealed class IsolateResponse {
  const IsolateResponse(this.id);

  final int id;
}

final class IsolateResponseSuccess extends IsolateResponse {
  const IsolateResponseSuccess({
    required int id,
    required this.payload,
  }) : super(id);

  final Object? payload;
}

final class IsolateResponseFailure extends IsolateResponse {
  const IsolateResponseFailure({
    required int id,
    required this.message,
    required this.stackTrace,
  }) : super(id);

  final String message;
  final String stackTrace;
}
