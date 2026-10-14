import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:built_in_server_client/src/owner_session.dart';
import 'package:built_in_server_client/src/server_discovery.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';

/// Finds or starts the server, then asks it for the owner session.
@PartOf(BuiltInServerClient)
final class ServerAttacher {
  ServerAttacher({
    required ServerDiscovery discovery,
    required http.Client Function() sessionClientFactory,
    required int pid,
  }) : _discovery = discovery,
       _sessionClientFactory = sessionClientFactory,
       _pid = pid;

  final ServerDiscovery _discovery;
  final http.Client Function() _sessionClientFactory;
  final int _pid;

  /// How many servers are tried in a row when each is gone by the time the
  /// session is asked for.
  static const _serverAttempts = 3;

  /// The owner session of the server this bestie found or started. A server
  /// that shut down between being found and being asked is replaced by
  /// looking again, up to [_serverAttempts] times.
  Future<AttachOutcome> attach() async {
    for (var attempt = 1; ; attempt++) {
      switch (await _discovery.find()) {
        case ServerSpeaksOtherProtocol(:final health):
          return AttachRefused(
            BuiltInServerVersionMismatch(
              protocolVersion: health.protocolVersion,
              serverVersion: health.serverVersion,
            ),
          );
        case ServerNotStarted(:final reason):
          return AttachRefused(BuiltInServerSpawnFailed(reason: reason));
        case ServerFound(:final port, :final health, :final exit):
          switch (await OwnerSession.open(
            client: _sessionClientFactory(),
            port: port,
            pid: _pid,
          )) {
            case OwnerSessionOpened(:final session):
              return AttachHeld(
                session: session,
                attached: BuiltInServerAttached(
                  ownerToken: session.ownerToken,
                  port: port,
                  pid: health.pid,
                ),
                exit: exit,
              );
            case OwnerSessionRefused(:final ownerPid):
              return AttachRefused(BuiltInServerBusy(ownerPid: ownerPid));
            case OwnerSessionServerGone() when attempt < _serverAttempts:
              continue;
            case OwnerSessionServerGone(:final reason) ||
                OwnerSessionFailed(:final reason):
              return AttachRefused(
                BuiltInServerDisconnected(cause: AttachFailed(reason)),
              );
          }
      }
    }
  }
}

/// How asking for the owner session went.
@model
sealed class AttachOutcome {
  const AttachOutcome();
}

/// This bestie holds [session] on the server [attached] describes.
@model
final class AttachHeld extends AttachOutcome {
  const AttachHeld({
    required this.session,
    required this.attached,
    this.exit,
  });

  final OwnerSession session;

  final BuiltInServerAttached attached;

  /// How the server process ends, when this bestie started it.
  final Future<ProcessExit>? exit;
}

/// No session is held, for the reason [connection] gives.
@model
final class AttachRefused extends AttachOutcome {
  const AttachRefused(this.connection);

  final BuiltInServerConnection connection;
}
