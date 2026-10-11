import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/local_connection.dart';
import 'package:provider_local/src/owner_session.dart';

@PartOf(LocalConnection)
sealed class ServerConnectionOutput {
  const ServerConnectionOutput();
}

/// The model's status changed.
@PartOf(LocalConnection)
final class ModelStatusChanged extends ServerConnectionOutput {
  const ModelStatusChanged(this.status);

  final ModelStatus status;
}

/// [session] is now held; whoever owns side effects follows its events.
@PartOf(LocalConnection)
final class SessionStarted extends ServerConnectionOutput {
  const SessionStarted(this.session);

  final OwnerSession session;
}
