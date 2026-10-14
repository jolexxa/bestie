import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:intentions/intentions.dart';

/// Where this bestie stands with the local inference server.
@model
sealed class BuiltInServerConnection {
  const BuiltInServerConnection();
}

/// No session is held, for [cause].
@model
final class BuiltInServerDisconnected extends BuiltInServerConnection {
  const BuiltInServerDisconnected({this.cause = const NotYetAttached()});

  final DisconnectCause cause;
}

/// Finding or starting the server and asking it for the owner session.
@model
final class BuiltInServerAttaching extends BuiltInServerConnection {
  const BuiltInServerAttaching();
}

/// This bestie owns the server: it may lease agents and load models.
@model
final class BuiltInServerAttached extends BuiltInServerConnection {
  const BuiltInServerAttached({
    required this.ownerToken,
    required this.port,
    required this.pid,
  });

  /// Authorizes this bestie's lease, model, and agent completion requests.
  final String ownerToken;

  /// The loopback port the server listens on.
  final int port;

  /// The server's process.
  final int pid;
}

/// Another bestie owns the server.
@model
final class BuiltInServerBusy extends BuiltInServerConnection {
  const BuiltInServerBusy({required this.ownerPid});

  final int ownerPid;
}

/// The running server speaks a protocol this bestie does not.
@model
final class BuiltInServerVersionMismatch extends BuiltInServerConnection {
  const BuiltInServerVersionMismatch({
    required this.protocolVersion,
    required this.serverVersion,
  });

  /// The protocol the running server speaks.
  final int protocolVersion;

  final String serverVersion;
}

/// No server answered, and one could not be started.
@model
final class BuiltInServerSpawnFailed extends BuiltInServerConnection {
  const BuiltInServerSpawnFailed({required this.reason});

  final String reason;
}
