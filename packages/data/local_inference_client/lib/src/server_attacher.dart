import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/owner_session.dart';
import 'package:local_inference_client/src/server_discovery.dart';

/// Finds or starts the server, then asks it for the owner session.
@PartOf(LocalInferenceClient)
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
            LocalServerVersionMismatch(
              protocolVersion: health.protocolVersion,
              serverVersion: health.serverVersion,
            ),
          );
        case ServerNotStarted(:final reason):
          return AttachRefused(LocalServerSpawnFailed(reason: reason));
        case ServerFound(:final port):
          switch (await OwnerSession.open(
            client: _sessionClientFactory(),
            port: port,
            pid: _pid,
          )) {
            case OwnerSessionOpened(:final session):
              return AttachHeld(
                session: session,
                attached: LocalServerAttached(
                  ownerToken: session.ownerToken,
                  port: port,
                ),
              );
            case OwnerSessionRefused(:final ownerPid):
              return AttachRefused(LocalServerBusy(ownerPid: ownerPid));
            case OwnerSessionServerGone() when attempt < _serverAttempts:
              continue;
            case OwnerSessionServerGone(:final reason) ||
                OwnerSessionFailed(:final reason):
              return AttachRefused(LocalServerDisconnected(reason: reason));
          }
      }
    }
  }
}

/// How asking for the owner session went.
@PartOf(LocalInferenceClient)
sealed class AttachOutcome {
  const AttachOutcome();
}

/// This bestie holds [session] on the server [attached] describes.
@PartOf(LocalInferenceClient)
final class AttachHeld extends AttachOutcome {
  const AttachHeld({required this.session, required this.attached});

  final OwnerSession session;

  final LocalServerAttached attached;
}

/// No session is held, for the reason [connection] gives.
@PartOf(LocalInferenceClient)
final class AttachRefused extends AttachOutcome {
  const AttachRefused(this.connection);

  final LocalServerConnection connection;
}
