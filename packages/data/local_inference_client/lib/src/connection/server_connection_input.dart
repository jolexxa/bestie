import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_client/src/owner_session.dart';
import 'package:local_inference_client/src/server_attacher.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

@PartOf(LocalInferenceClient)
sealed class ServerConnectionInput {
  const ServerConnectionInput();
}

/// Hold the owner session, finding or starting the server first; [reply]
/// says where that left things.
@PartOf(LocalInferenceClient)
final class AttachRequested extends ServerConnectionInput {
  const AttachRequested(this.reply);

  final Completer<LocalServerConnection> reply;
}

/// Unload the model and let go of the server; [reply] completes once it is
/// let go.
@PartOf(LocalInferenceClient)
final class ReleaseRequested extends ServerConnectionInput {
  const ReleaseRequested(this.reply);

  final Completer<void> reply;
}

/// Load the model [request] names.
@PartOf(LocalInferenceClient)
final class LoadRequested extends ServerConnectionInput {
  const LoadRequested({required this.request, required this.reply});

  final ModelLoadRequest request;

  final Completer<ModelLoadResult> reply;
}

/// Let go of the server for good; [reply] completes once it is let go.
@PartOf(LocalInferenceClient)
final class CloseRequested extends ServerConnectionInput {
  const CloseRequested(this.reply);

  final Completer<void> reply;
}

/// Open a lease for [agent] on behalf of [holder].
@PartOf(LocalInferenceClient)
final class LeaseOpenRequested extends ServerConnectionInput {
  const LeaseOpenRequested({
    required this.holder,
    required this.agent,
    required this.reply,
  });

  final Object holder;

  final AgentIdentity agent;

  final Completer<AgentSessionResult> reply;
}

/// Close the lease of [agentId] if [holder] holds it, or every lease it
/// holds when [agentId] is null.
@PartOf(LocalInferenceClient)
final class LeaseCloseRequested extends ServerConnectionInput {
  const LeaseCloseRequested({
    required this.holder,
    required this.reply,
    this.agentId,
  });

  final Object holder;

  final String? agentId;

  final Completer<void> reply;
}

/// The attempt to hold the session numbered [attempt] ended.
@PartOf(LocalInferenceClient)
final class AttachSettled extends ServerConnectionInput {
  const AttachSettled({required this.attempt, required this.outcome});

  final int attempt;

  final AttachOutcome outcome;
}

/// Whatever was held has been let go.
@PartOf(LocalInferenceClient)
final class LetGo extends ServerConnectionInput {
  const LetGo();
}

/// The client has let go of the server for good.
@PartOf(LocalInferenceClient)
final class HungUp extends ServerConnectionInput {
  const HungUp();
}

/// A load asked for over [session] answered [result].
@PartOf(LocalInferenceClient)
final class LoadSettled extends ServerConnectionInput {
  const LoadSettled({
    required this.session,
    required this.request,
    required this.result,
  });

  final OwnerSession session;

  final ModelLoadRequest request;

  final ModelLoadResult result;
}

/// [session] reported the model's [status].
@PartOf(LocalInferenceClient)
final class ModelStatusReported extends ServerConnectionInput {
  const ModelStatusReported({required this.session, required this.status});

  final OwnerSession session;

  final ModelStatus status;
}

/// The server ended [session].
@PartOf(LocalInferenceClient)
final class SessionEnded extends ServerConnectionInput {
  const SessionEnded(this.session);

  final OwnerSession session;
}
