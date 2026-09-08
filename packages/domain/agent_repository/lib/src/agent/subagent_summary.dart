import 'package:agent_repository/src/agent/agent_session_id.dart';
import 'package:intentions/intentions.dart';

/// Lifecycle outcome of a subagent, surfaced on its [SubagentSummary].
///
/// Distinct from `ConversationPhase` — this answers "how did this subagent's
/// work end", not "is a turn in flight". In Phase 1 `running` derives from the
/// session's live phase and only the terminal outcome is stored.
@model
enum SubagentStatus { running, completed, failed }

/// A lightweight, read-only projection of a subagent session — the row shown
/// in the subagent zone bar. The full renderable session lives in
/// `AgentRepository`'s session registry and is fetched via `sessionFor(id)`.
@model
final class SubagentSummary {
  const SubagentSummary({
    required this.id,
    required this.title,
    required this.status,
  });

  final AgentSessionId id;
  final String title;
  final SubagentStatus status;
}
