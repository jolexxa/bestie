import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Says in words why the server is not held, for the status bar.
@PartOf(BuiltInServerClient)
final class DisconnectWording {
  const DisconnectWording({required this.logFile});

  /// Where the server wrote what happened to it.
  final String logFile;

  static const notConnected = 'The local model server is not connected.';

  static const _reconnect = 'Reconnect to start it again.';

  ProviderFailure failureFor(DisconnectCause cause) => switch (cause) {
    NotYetAttached() => const ProviderServerFailed(notConnected),
    SessionReleased() => const ProviderCancelled(
      'Built-in server was stopped. $_reconnect',
    ),
    ServerStopping(reason: ServerStopReason.requested) =>
      const ProviderServerFailed(
        'Built-in server was asked to stop. $_reconnect',
      ),
    ServerStopping(reason: ServerStopReason.engineLost) => ProviderServerFailed(
      'Built-in server lost its engine; see $logFile. $_reconnect',
    ),
    ServerStopping(:final reason) => ProviderServerFailed(
      'Built-in server stopped (${reason.name}). $_reconnect',
    ),
    ServerExited(:final exit, :final pid) => ProviderServerFailed(
      'Built-in server ${bestieServerExitMessage(exit)} (pid $pid); '
      'see $logFile. $_reconnect',
    ),
    ServerDisappeared(:final pid) => ProviderServerFailed(
      'Built-in server went away without notice (pid $pid); see $logFile. '
      '$_reconnect',
    ),
    AttachFailed(:final reason) => ProviderServerFailed(reason),
  };
}
