import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/owner_session.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

@model
sealed class ServerConnectionOutput {
  const ServerConnectionOutput();
}

/// Where this bestie stands with the server changed.
@model
final class ConnectionChanged extends ServerConnectionOutput {
  const ConnectionChanged(this.connection);

  final BuiltInServerConnection connection;
}

/// The model's status changed.
@model
final class ModelStatusChanged extends ServerConnectionOutput {
  const ModelStatusChanged(this.status);

  final ModelStatus status;
}

/// [session] is now held; whoever owns side effects follows its events.
@model
final class SessionStarted extends ServerConnectionOutput {
  const SessionStarted(this.session);

  final OwnerSession session;
}
