import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// What the built-in server is doing, as far as this bestie can tell.
@model
sealed class BuiltInServerStatus {
  const BuiltInServerStatus();

  /// What stands with this bestie at [connection] to the server, whose
  /// model stands at [model], with [pool] the last the server said of the
  /// agents leased on it.
  static BuiltInServerStatus of(
    BuiltInServerConnection connection,
    ModelStatus model,
    PoolSnapshotEvent? pool,
  ) => switch (connection) {
    BuiltInServerDisconnected(:final cause) => ServerOffline(cause: cause),
    BuiltInServerAttaching() => const ServerStarting(),
    BuiltInServerBusy(:final ownerPid) => ServerTaken(ownerPid: ownerPid),
    BuiltInServerVersionMismatch(
      :final protocolVersion,
      :final serverVersion,
    ) =>
      ServerIncompatible(
        protocolVersion: protocolVersion,
        serverVersion: serverVersion,
      ),
    BuiltInServerSpawnFailed(:final reason) => ServerFailed(reason: reason),
    BuiltInServerAttached() => switch (model) {
      ModelUnloaded() => const ServerIdle(),
      ModelFitting(:final localId) => ServerFitting(localId: localId),
      ModelLoading(:final localId, :final progress) => ServerLoading(
        localId: localId,
        progress: progress,
      ),
      ModelReady(
        :final localId,
        :final contextSize,
        :final maxAgents,
        :final deviceBytes,
      ) =>
        ServerServing(
          localId: localId,
          contextSize: contextSize,
          maxAgents: maxAgents,
          deviceBytes: deviceBytes,
          leased: pool?.agents.length,
        ),
      ModelFailed(:final localId, :final reason) => ServerModelFailed(
        localId: localId,
        reason: reason,
      ),
    },
  };
}

/// This bestie holds no server, for [cause]: none was started yet, it was
/// stopped, or it was lost.
@model
final class ServerOffline extends BuiltInServerStatus {
  const ServerOffline({this.cause = const NotYetAttached()});

  final DisconnectCause cause;
}

/// The server is this bestie's: being taken, or taken and holding whatever
/// the session asked for. It can be stopped.
@model
sealed class ServerRunning extends BuiltInServerStatus {
  const ServerRunning();
}

/// Finding or starting the server.
@model
final class ServerStarting extends ServerRunning {
  const ServerStarting();
}

/// This bestie holds the server, with nothing loaded.
@model
final class ServerIdle extends ServerRunning {
  const ServerIdle();
}

/// Working out how much context fits for [localId].
@model
final class ServerFitting extends ServerRunning {
  const ServerFitting({required this.localId});

  final String localId;
}

/// Loading the weights of [localId], [progress] of the way from 0 to 1.
@model
final class ServerLoading extends ServerRunning {
  const ServerLoading({required this.localId, required this.progress});

  final String localId;

  final double progress;
}

/// Serving [localId] with [contextSize] tokens of context shared by up to
/// [maxAgents] agents, taking [deviceBytes] on the device.
@model
final class ServerServing extends ServerRunning {
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

  final int deviceBytes;

  /// How many agents hold a lease on the model, once the server has said.
  final int? leased;
}

/// The server holds nothing because loading [localId] failed for [reason].
@model
final class ServerModelFailed extends ServerRunning {
  const ServerModelFailed({required this.localId, required this.reason});

  final String localId;

  final String reason;
}

/// Another bestie, running as [ownerPid], holds the server.
@model
final class ServerTaken extends BuiltInServerStatus {
  const ServerTaken({required this.ownerPid});

  final int ownerPid;
}

/// The running server speaks [protocolVersion], which this bestie does not.
@model
final class ServerIncompatible extends BuiltInServerStatus {
  const ServerIncompatible({
    required this.protocolVersion,
    required this.serverVersion,
  });

  final int protocolVersion;

  final String serverVersion;
}

/// No server answered, and one could not be started for [reason].
@model
final class ServerFailed extends BuiltInServerStatus {
  const ServerFailed({required this.reason});

  final String reason;
}
