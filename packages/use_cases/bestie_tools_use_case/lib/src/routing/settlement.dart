import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/job_manager.dart';
import 'package:bestie_tools_use_case/src/routing/job_reporter.dart';
import 'package:bestie_tools_use_case/src/routing/tool_router.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// The first thing a settlement observes for one call.
sealed class _Signal {}

final class _Outcome extends _Signal {
  _Outcome(this.outcome);
  final JobOutcome outcome;
}

final class _Handoff extends _Signal {
  _Handoff(this.handoff);
  final String handoff;
}

final class _RequestLost extends _Signal {}

/// Reads the job, writes the response — the only writer of terminal
/// responses.
@PartOf(ToolRouter)
final class Settlement {
  Settlement({required JobReporter reporter}) : _reporter = reporter;

  final JobReporter _reporter;

  /// Settles [request] from [entry]'s job: a foreground outcome becomes the
  /// terminal response, a handoff becomes [ToolCallInBackground] and hands
  /// the entry to the reporter, and a request settled from the other side
  /// stops the job.
  Future<void> settle(ToolCallRequest request, JobEntry entry) async {
    switch (await _first(entry.job, until: request.response)) {
      case _Outcome(:final outcome):
        request.settle(_bounded(request, _terminal(request, outcome)));
      case _Handoff(:final handoff):
        request.settle(
          _bounded(
            request,
            ToolCallInBackground(
              callId: request.call.id,
              toolName: request.call.name,
              content: handoff,
              elapsedMs: request.elapsedMs,
            ),
          ),
        );
        _reporter.watch(entry);
      case _RequestLost():
        entry.job.stop();
    }
  }

  /// [response], or a failure in its place when it would put more into the
  /// conversation than the call was allowed.
  ToolCallResponse _bounded(
    ToolCallRequest request,
    ToolCallResponse response,
  ) {
    final length = response.modelText.length;
    if (length <= request.maxOutputChars) return response;
    return ToolCallFailed(
      callId: request.call.id,
      toolName: request.call.name,
      message:
          'Output was $length characters, over the '
          '${request.maxOutputChars} allowed. Request less at a time.',
      elapsedMs: request.elapsedMs,
    );
  }

  Future<_Signal> _first(Job job, {required Future<Object?> until}) =>
      Future.any<_Signal>([
        job.settled.then(_Outcome.new),
        job.inBackground.then(_Handoff.new),
        until.then((_) => _RequestLost()),
      ]);

  ToolCallResponse _terminal(ToolCallRequest request, JobOutcome outcome) =>
      switch (outcome) {
        JobSucceeded(:final content, :final contributions) => ToolCallSucceeded(
          callId: request.call.id,
          toolName: request.call.name,
          content: content,
          contributions: contributions,
          elapsedMs: request.elapsedMs,
        ),
        JobFailed(:final message, :final content) => ToolCallFailed(
          callId: request.call.id,
          toolName: request.call.name,
          message: message,
          content: content,
          elapsedMs: request.elapsedMs,
        ),
      };
}
