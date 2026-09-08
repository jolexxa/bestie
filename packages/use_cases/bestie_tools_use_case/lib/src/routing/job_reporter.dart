import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/job_manager.dart';
import 'package:bestie_tools_use_case/src/routing/tool_router.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Produces reports for background jobs and nothing else.
///
/// A report is the deferred answer to a call the requester already stopped
/// waiting on, so it goes straight back to whoever made that call.
@PartOf(ToolRouter)
final class JobReporter {
  JobReporter({required ToolRequester requester}) : _requester = requester;

  final ToolRequester _requester;
  final Map<String, List<JobEntry>> _heldByAgent = {};
  bool _disposed = false;

  void watch(JobEntry entry) {
    _heldByAgent.putIfAbsent(entry.agentId, () => []).add(entry);

    _requester.noteBackgrounded(
      JobBackgrounded(
        conversationId: entry.conversationId,
        agentId: entry.agentId,
        callId: entry.call.id,
        toolName: entry.call.name,
        arguments: entry.call.arguments,
      ),
    );
    unawaited(_reportWhenSettled(entry));
  }

  void dispose() => _disposed = true;

  /// Delivers [entry]'s outcome once it settles.
  Future<void> _reportWhenSettled(JobEntry entry) async {
    final outcome = await entry.job.settled;
    final held = _heldByAgent[entry.agentId];
    held?.remove(entry);
    if (held != null && held.isEmpty) _heldByAgent.remove(entry.agentId);
    if (_disposed) return;
    _requester.deliverReport(
      JobReport(
        conversationId: entry.conversationId,
        agentId: entry.agentId,
        callId: entry.call.id,
        toolName: entry.call.name,
        arguments: entry.call.arguments,
        outcome: outcome,
        outstanding: held?.length ?? 0,
      ),
    );
  }
}
