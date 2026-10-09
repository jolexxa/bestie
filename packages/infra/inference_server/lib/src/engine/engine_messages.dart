import 'dart:isolate';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference_server/src/model_engine.dart';

/// What the server asks of an engine running in another isolate.
sealed class EngineCommand {
  const EngineCommand();
}

final class LoadModelCommand extends EngineCommand {
  const LoadModelCommand({required this.loadId, required this.request});

  final int loadId;

  final ModelEngineRequest request;
}

/// The server no longer wants the load; a model it produces is unloaded.
final class AbandonLoadCommand extends EngineCommand {
  const AbandonLoadCommand({required this.loadId});

  final int loadId;
}

/// The server can take another batch of a completion's events.
final class PullTurnCommand extends EngineCommand {
  const PullTurnCommand({required this.turnId});

  final int turnId;
}

/// The server no longer wants a completion's events; the completion stops.
final class CancelTurnCommand extends EngineCommand {
  const CancelTurnCommand({required this.turnId});

  final int turnId;
}

/// A command answered once, by [CallAnswered] or [CallFailed].
sealed class EngineCall extends EngineCommand {
  const EngineCall({required this.callId});

  final int callId;
}

/// A call on a loaded model, named by the load that produced it.
sealed class ModelCall extends EngineCall {
  const ModelCall({required super.callId, required this.modelId});

  final int modelId;
}

/// Answered with an [AgentOpenOutcome].
final class OpenPrimaryCall extends ModelCall {
  const OpenPrimaryCall({
    required super.callId,
    required super.modelId,
    required this.agentId,
  });

  final String agentId;
}

/// Answered with an [AgentOpenOutcome].
final class OpenSubagentCall extends ModelCall {
  const OpenSubagentCall({
    required super.callId,
    required super.modelId,
    required this.agentId,
  });

  final String agentId;
}

/// Answered with an [AgentCloseOutcome].
final class CloseAgentCall extends ModelCall {
  const CloseAgentCall({
    required super.callId,
    required super.modelId,
    required this.agentId,
  });

  final String agentId;
}

final class CloseAllAgentsCall extends ModelCall {
  const CloseAllAgentsCall({required super.callId, required super.modelId});
}

/// Answered with the [CompletionRejected] that refused the completion, or
/// null when it started; its events then follow under [turnId].
final class CompleteCall extends ModelCall {
  const CompleteCall({
    required super.callId,
    required super.modelId,
    required this.turnId,
    required this.request,
  });

  final int turnId;

  final CompletionRequest request;
}

final class DisposeRuntimeCall extends ModelCall {
  const DisposeRuntimeCall({required super.callId, required super.modelId});
}

final class UnloadModelCall extends ModelCall {
  const UnloadModelCall({required super.callId, required super.modelId});
}

/// Abandons every load and closes the engine.
final class CloseEngineCall extends EngineCall {
  const CloseEngineCall({required super.callId});
}

/// What an engine running in another isolate tells the server.
sealed class EngineMessage {
  const EngineMessage();
}

/// What the engine's isolate says about itself rather than its work.
sealed class EngineNotice extends EngineMessage {
  const EngineNotice();
}

/// The engine's answers to commands, and the work they started.
sealed class EngineReply extends EngineMessage {
  const EngineReply();
}

/// The engine started, or why it could not, and where to send commands.
final class EngineStartAnswered extends EngineNotice {
  const EngineStartAnswered({required this.commands, this.unavailable});

  final SendPort commands;

  /// Why no engine started, or null when one did.
  final ModelEngineUnavailable? unavailable;
}

final class EngineLogged extends EngineNotice {
  const EngineLogged({required this.message, required this.isError});

  final String message;

  final bool isError;
}

final class CallAnswered extends EngineReply {
  const CallAnswered({required this.callId, required this.answer});

  final int callId;

  final Object? answer;
}

final class CallFailed extends EngineReply {
  const CallFailed({required this.callId, required this.message});

  final int callId;

  final String message;
}

/// A step of a load that has not settled.
final class LoadStepped extends EngineReply {
  const LoadStepped({required this.loadId, required this.step});

  final int loadId;

  final ModelEngineStep step;
}

/// The load produced a model, which later calls name by [modelId].
final class ModelHosted extends EngineReply {
  const ModelHosted({
    required this.modelId,
    required this.contextSize,
    required this.maxAgents,
    required this.deviceBytes,
    required this.pool,
  });

  /// The id of the load that produced the model.
  final int modelId;

  final int contextSize;

  final int maxAgents;

  final int deviceBytes;

  final PoolSnapshot pool;
}

/// The load's events have ended.
final class LoadEnded extends EngineReply {
  const LoadEnded({required this.loadId});

  final int loadId;
}

final class PoolChanged extends EngineReply {
  const PoolChanged({required this.modelId, required this.pool});

  final int modelId;

  final PoolSnapshot pool;
}

/// A batch of a completion's events, sent once per pull. Adjacent deltas
/// are merged while the server catches up.
final class TurnEvents extends EngineReply {
  const TurnEvents({
    required this.turnId,
    required this.events,
    required this.ended,
  });

  final int turnId;

  final List<CompletionEvent> events;

  /// Whether these are the last of the completion's events.
  final bool ended;
}
