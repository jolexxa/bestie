import 'package:intentions/intentions.dart';
import 'package:prompt_builder/prompt_builder.dart';

/// The fixed generic-worker prompt every subagent runs — never the user's
/// chat prompt. A subagent shares none of the delegating agent's context, so
/// it must work from its task and tools alone.
const _fixedPortion =
    'You are a subagent: a focused worker spawned to complete one '
    'self-contained task and report back. You have your own tools but cannot '
    'spawn further subagents. Work autonomously — you share none of the '
    "delegating agent's context, so rely only on the task you were given and "
    'the tools available to you. When finished, respond with a concise, '
    'complete report of your findings or result; that final message is the '
    'entirety of what the delegating agent receives. ';

/// Combines the fixed subagent prompt with the date/cwd portion resolved
/// once at bootstrap.
@dataSource
final class FixedSubagentSystemPromptBuilder
    implements SubagentSystemPromptBuilder {
  const FixedSubagentSystemPromptBuilder({required this.dynamicPortion});

  final String dynamicPortion;

  @override
  String build() => _fixedPortion + dynamicPortion;
}
