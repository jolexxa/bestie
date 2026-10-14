import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/built_in_server_client.dart';
import 'package:provider_local/src/models/built_in_server_connection.dart';
import 'package:provider_local/src/owner_session.dart';

@PartOf(BuiltInServerClient)
sealed class ServerConnectionOutput {
  const ServerConnectionOutput();
}

/// Where this bestie stands with the server changed.
@PartOf(BuiltInServerClient)
final class ConnectionChanged extends ServerConnectionOutput {
  const ConnectionChanged(this.connection);

  final BuiltInServerConnection connection;
}

/// The model's status changed.
@PartOf(BuiltInServerClient)
final class ModelStatusChanged extends ServerConnectionOutput {
  const ModelStatusChanged(this.status);

  final ModelStatus status;
}

/// [session] is now held; whoever owns side effects follows its events.
@PartOf(BuiltInServerClient)
final class SessionStarted extends ServerConnectionOutput {
  const SessionStarted(this.session);

  final OwnerSession session;
}
