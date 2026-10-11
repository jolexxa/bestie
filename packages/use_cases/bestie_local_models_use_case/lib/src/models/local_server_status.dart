import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;

/// What the local server is doing for the app.
@model
sealed class LocalServerStatus {
  const LocalServerStatus();
}

/// The app does not run on a local model.
@model
final class ServerIdle extends LocalServerStatus {
  const ServerIdle();
}

/// Finding or starting the server and looking the model up.
@model
final class ServerStarting extends LocalServerStatus {
  const ServerStarting();
}

/// Getting [localId] ready: [progress] is null while measuring how much
/// context fits.
@model
final class ServerLoading extends LocalServerStatus {
  const ServerLoading({required this.localId, this.progress});

  final String localId;

  final double? progress;
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
    this.leased,
  });

  final String localId;

  final int contextSize;

  final int maxAgents;

  final int? deviceBytes;

  /// How many agents hold a lease on the model, once the app reports them.
  final int? leased;
}

/// The app could not run on its local model, or was stopped on purpose.
@model
final class ServerFailed extends LocalServerStatus {
  const ServerFailed(this.failure);

  final ProviderFailure failure;
}
