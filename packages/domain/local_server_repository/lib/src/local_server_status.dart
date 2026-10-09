import 'package:intentions/intentions.dart';

/// What the local server is doing for this window.
@model
sealed class LocalServerStatus {
  const LocalServerStatus();
}

/// This window does not hold the server and nothing went wrong.
@model
final class ServerIdle extends LocalServerStatus {
  const ServerIdle();
}

/// Finding or starting the server and taking it for this window.
@model
final class ServerStarting extends LocalServerStatus {
  const ServerStarting();
}

/// Another bestie window holds the server.
@model
final class ServerOwnedElsewhere extends LocalServerStatus {
  const ServerOwnedElsewhere({required this.ownerPid});

  final int ownerPid;
}

/// The running server speaks another protocol than this bestie.
@model
final class ServerIncompatible extends LocalServerStatus {
  const ServerIncompatible({
    required this.serverVersion,
    required this.protocolVersion,
  });

  final String serverVersion;

  final int protocolVersion;
}

/// The server could not be started or taken, or let this window go.
@model
final class ServerFailed extends LocalServerStatus {
  const ServerFailed(this.reason);

  final String reason;
}

/// Getting [localId] ready: [progress] is null while measuring how much
/// context fits.
@model
final class ServerLoading extends LocalServerStatus {
  const ServerLoading({required this.localId, this.progress});

  final String localId;

  final double? progress;
}

/// The server could not load [localId].
@model
final class ServerLoadFailed extends LocalServerStatus {
  const ServerLoadFailed({required this.localId, required this.reason});

  final String localId;

  final String reason;
}

/// Serving [localId] with [contextSize] tokens of context shared by up to
/// [maxAgents] agents, taking [deviceBytes] on the device.
@model
final class ServerServing extends LocalServerStatus {
  const ServerServing({
    required this.localId,
    required this.contextSize,
    required this.maxAgents,
    required this.deviceBytes,
    this.pool,
  });

  final String localId;

  final int contextSize;

  final int maxAgents;

  final int deviceBytes;

  /// The agents leased on the model, once the server reports them.
  final LocalAgentPool? pool;
}

/// How many agents hold a lease on the loaded model, of how many may.
@model
final class LocalAgentPool {
  const LocalAgentPool({required this.leased, required this.maxAgents});

  final int leased;

  final int maxAgents;
}
