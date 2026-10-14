import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';

/// The runtime-side operations an [CompletionAgent] forwards to.
abstract interface class AgentRuntimeHost {
  Future<RunResult> run(
    AgentHandle handle,
    Transcript transcript,
    AgentConfig? config,
    TurnGoal goal,
  );

  Future<SubmitToolResultsResult> submitToolResults(
    AgentHandle handle,
    List<ToolCallResponse> responses,
  );

  Future<SubmitCompactionPromptResult> submitCompactionPrompt(
    AgentHandle handle,
    CompactionPromptContent content,
  );

  Future<CancelResult> cancel(AgentHandle handle);
}

/// A handle onto one agent run by a completion agent runtime.
final class CompletionAgent implements Agent {
  CompletionAgent({
    required this.handle,
    required this.events,
    required AgentRuntimeHost host,
  }) : _host = host;

  final AgentRuntimeHost _host;

  @override
  final AgentHandle handle;

  @override
  final Stream<AgentRuntimeEvent> events;

  @override
  AgentKind get kind => handle.kind;

  @override
  String? get label => handle.label;

  @override
  Future<RunResult> run(
    Transcript transcript, {
    AgentConfig? config,
    TurnGoal goal = TurnGoal.respond,
  }) => _host.run(handle, transcript, config, goal);

  @override
  Future<SubmitToolResultsResult> submitToolResults(
    List<ToolCallResponse> responses,
  ) => _host.submitToolResults(handle, responses);

  @override
  Future<SubmitCompactionPromptResult> submitCompactionPrompt(
    CompactionPromptContent content,
  ) => _host.submitCompactionPrompt(handle, content);

  @override
  Future<CancelResult> cancel() => _host.cancel(handle);
}
