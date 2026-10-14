import 'dart:async';

import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/owner_session.dart';
import 'package:built_in_server_client/src/server_attacher.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:process_host/process_host.dart';

@model
sealed class ServerConnectionInput {
  const ServerConnectionInput();
}

/// Hold the owner session, finding or starting the server first; [reply]
/// says where that left things.
@model
final class AttachRequested extends ServerConnectionInput {
  const AttachRequested(this.reply);

  final Completer<BuiltInServerConnection> reply;
}

/// Unload the model and let go of the server; [reply] completes once it is
/// let go.
@model
final class ReleaseRequested extends ServerConnectionInput {
  const ReleaseRequested(this.reply);

  final Completer<void> reply;
}

/// Unload the model, keeping the server; [reply] completes once it is
/// unloaded.
@model
final class UnloadRequested extends ServerConnectionInput {
  const UnloadRequested(this.reply);

  final Completer<void> reply;
}

/// Load the model [request] names.
@model
final class LoadRequested extends ServerConnectionInput {
  const LoadRequested({required this.request, required this.reply});

  final ModelLoadRequest request;

  final Completer<ModelLoadResult> reply;
}

/// Let go of the server for good; [reply] completes once it is let go.
@model
final class CloseRequested extends ServerConnectionInput {
  const CloseRequested(this.reply);

  final Completer<void> reply;
}

/// Open a lease for [agent] on behalf of [holder].
@model
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
@model
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
@model
final class AttachSettled extends ServerConnectionInput {
  const AttachSettled({required this.attempt, required this.outcome});

  final int attempt;

  final AttachOutcome outcome;
}

/// Whatever was held has been let go.
@model
final class LetGo extends ServerConnectionInput {
  const LetGo();
}

/// The client has let go of the server for good.
@model
final class HungUp extends ServerConnectionInput {
  const HungUp();
}

/// An unload asked for over [session] finished; [reply] is told.
@model
final class UnloadSettled extends ServerConnectionInput {
  const UnloadSettled({required this.session, required this.reply});

  final OwnerSession session;

  final Completer<void> reply;
}

/// A load asked for over [session] answered [result].
@model
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
@model
final class ModelStatusReported extends ServerConnectionInput {
  const ModelStatusReported({required this.session, required this.status});

  final OwnerSession session;

  final ModelStatus status;
}

/// [session] heard the server is stopping for [reason].
@model
final class SessionClosingReported extends ServerConnectionInput {
  const SessionClosingReported({required this.session, required this.reason});

  final OwnerSession session;

  final ServerStopReason reason;
}

/// The server ended [session].
@model
final class SessionEnded extends ServerConnectionInput {
  const SessionEnded(this.session);

  final OwnerSession session;
}

/// The process serving [session] ended with [exit].
@model
final class ProcessExitReported extends ServerConnectionInput {
  const ProcessExitReported({required this.session, required this.exit});

  final OwnerSession session;

  final ProcessExit exit;
}

/// The wait for the exit of the process that served the session numbered
/// [attempt] is over.
@model
final class LossGraceExpired extends ServerConnectionInput {
  const LossGraceExpired({required this.attempt});

  final int attempt;
}
