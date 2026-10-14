import 'package:intentions/intentions.dart';

/// Where this bestie stands with the local inference server.
@model
sealed class LocalServerConnection {
  const LocalServerConnection();
}

/// No session is held: none was asked for yet, it was closed, or the server
/// ended it.
@model
final class LocalServerDisconnected extends LocalServerConnection {
  const LocalServerDisconnected({this.reason});

  /// Why a session that was asked for is not held, if one was.
  final String? reason;
}

/// Finding or starting the server and asking it for the owner session.
@model
final class LocalServerAttaching extends LocalServerConnection {
  const LocalServerAttaching();
}

/// This bestie owns the server: it may lease agents and load models.
@model
final class LocalServerAttached extends LocalServerConnection {
  const LocalServerAttached({required this.ownerToken, required this.port});

  /// Authorizes this bestie's lease, model, and agent completion requests.
  final String ownerToken;

  /// The loopback port the server listens on.
  final int port;
}

/// Another bestie owns the server.
@model
final class LocalServerBusy extends LocalServerConnection {
  const LocalServerBusy({required this.ownerPid});

  final int ownerPid;
}

/// The running server speaks a protocol this bestie does not.
@model
final class LocalServerVersionMismatch extends LocalServerConnection {
  const LocalServerVersionMismatch({
    required this.protocolVersion,
    required this.serverVersion,
  });

  /// The protocol the running server speaks.
  final int protocolVersion;

  final String serverVersion;
}

/// No server answered, and one could not be started.
@model
final class LocalServerSpawnFailed extends LocalServerConnection {
  const LocalServerSpawnFailed({required this.reason});

  final String reason;
}
