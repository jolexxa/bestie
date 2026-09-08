import 'package:agent_provider_protocol/src/runtime/agent_config.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_handle.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_runtime_event.dart';
import 'package:agent_provider_protocol/src/runtime/models/cancel_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/run_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/submit_compaction_prompt_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/submit_tool_results_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/turn_goal.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript.dart';
import 'package:prompt_builder/prompt_builder.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// A live agent handed back by [AgentProvider.startPrimary] /
/// [AgentProvider.startSubagent].
///
/// The provider owns birth and death (start / dispose); an [Agent] owns
/// everything in between. Its [events] stream carries only this agent's
/// events — no cross-agent demux required.
abstract interface class Agent {
  AgentHandle get handle;

  AgentKind get kind;

  String? get label;

  /// This agent's events only.
  Stream<AgentRuntimeEvent> get events;

  /// Runs another turn. A [TurnGoal.compact] turn folds the transcript into a
  /// summary checkpoint and completes without generating a reply.
  Future<RunResult> run(
    Transcript transcript, {
    AgentConfig? config,
    TurnGoal goal = TurnGoal.respond,
  });

  /// Continues an in-flight turn that emitted [AgentNeedsToolResults].
  Future<SubmitToolResultsResult> submitToolResults(
    List<ToolCallResponse> responses,
  );

  /// Continues an in-flight compaction that emitted
  /// [AgentNeedsCompactionPrompt], supplying the summarizer's prompt content.
  Future<SubmitCompactionPromptResult> submitCompactionPrompt(
    CompactionPromptContent content,
  );

  /// Stops the current run. The agent stays alive and can [run] again.
  Future<CancelResult> cancel();
}
