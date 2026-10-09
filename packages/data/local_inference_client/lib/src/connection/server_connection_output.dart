import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/owner_session.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

@PartOf(LocalInferenceClient)
sealed class ServerConnectionOutput {
  const ServerConnectionOutput();
}

/// Where this bestie stands with the server changed.
@PartOf(LocalInferenceClient)
final class ConnectionChanged extends ServerConnectionOutput {
  const ConnectionChanged(this.connection);

  final LocalServerConnection connection;
}

/// The model's status changed.
@PartOf(LocalInferenceClient)
final class ModelStatusChanged extends ServerConnectionOutput {
  const ModelStatusChanged(this.status);

  final ModelStatus status;
}

/// [session] is now held; whoever owns side effects follows its events.
@PartOf(LocalInferenceClient)
final class SessionStarted extends ServerConnectionOutput {
  const SessionStarted(this.session);

  final OwnerSession session;
}
