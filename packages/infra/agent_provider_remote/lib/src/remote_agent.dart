import 'package:agent_provider_protocol/agent_provider_protocol.dart';

/// The provider-side operations a [RemoteAgent] forwards to.
abstract interface class RemoteAgentHost {
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

/// A handle onto one agent hosted by a remote provider.
final class RemoteAgent implements Agent {
  RemoteAgent({
    required this.handle,
    required this.events,
    required RemoteAgentHost host,
  }) : _host = host;

  final RemoteAgentHost _host;

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
