import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:process_host/process_host.dart';

/// Why this bestie holds no session on the server.
@model
sealed class DisconnectCause {
  const DisconnectCause();
}

/// No session was asked for yet.
@model
final class NotYetAttached extends DisconnectCause {
  const NotYetAttached();
}

/// This bestie let the session go: it stopped the server, restarted it,
/// or closed.
@model
final class SessionReleased extends DisconnectCause {
  const SessionReleased();
}

/// The server said it was stopping, and why, before ending the session.
@model
final class ServerStopping extends DisconnectCause {
  const ServerStopping(this.reason);

  final ServerStopReason reason;
}

/// The server process this bestie started ended without a word; [exit]
/// is how the operating system saw it go.
@model
final class ServerExited extends DisconnectCause {
  const ServerExited({required this.exit, required this.pid});

  final ProcessExit exit;

  final int pid;
}

/// The session ended without a word, and nothing says what became of the
/// server: it was not this bestie's to watch, or its exit never came.
@model
final class ServerDisappeared extends DisconnectCause {
  const ServerDisappeared({required this.pid});

  final int pid;
}

/// Asking the server for the session failed.
@model
final class AttachFailed extends DisconnectCause {
  const AttachFailed(this.reason);

  final String reason;
}
