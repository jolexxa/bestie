import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/job_manager.dart';
import 'package:bestie_tools_use_case/src/routing/job_reporter.dart';
import 'package:bestie_tools_use_case/src/routing/settlement.dart';
import 'package:bestie_tools_use_case/src/tools_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Owns the call-to-job lifecycle for every tool an agent may invoke.
@PartOf(ToolsUseCase)
final class ToolRouter {
  ToolRouter({
    required ToolRequester requester,
    required List<ToolResponder> responders,
  }) : _responders = {
         for (final responder in responders)
           for (final definition in responder.definitions.definitions)
             definition.name: responder,
       },
       _reporter = JobReporter(requester: requester) {
    _requests = requester.toolRequests.listen(_fulfil);
  }

  final Map<String, ToolResponder> _responders;
  final JobManager _jobs = JobManager();
  final JobReporter _reporter;
  late final Settlement _settlement = Settlement(reporter: _reporter);
  late final StreamSubscription<ToolCallRequest> _requests;

  Stream<List<JobEntry>> get jobs => _jobs.jobs;

  /// The jobs held right now, for a reader arriving after the last change.
  List<JobEntry> get entries => _jobs.entries;

  Future<void> _fulfil(ToolCallRequest request) async {
    final responder = _responders[request.call.name];
    if (responder == null) {
      request.settle(
        ToolCallFailed(
          callId: request.call.id,
          toolName: request.call.name,
          message: 'No such tool: ${request.call.name}.',
          elapsedMs: request.elapsedMs,
        ),
      );
      return;
    }
    if (request.maxOutputChars <= 0) {
      // Refused before the responder runs: a tool with side effects must not
      // do work whose answer has nowhere to go.
      request.settle(
        ToolCallFailed(
          callId: request.call.id,
          toolName: request.call.name,
          message:
              'No context left to answer this call. '
              'Continue after the conversation is compacted.',
          elapsedMs: request.elapsedMs,
        ),
      );
      return;
    }
    try {
      final job = await responder.respond(
        ToolCallInvocation(
          conversationId: request.conversationId,
          agentId: request.agentId,
          callId: request.call.id,
          toolName: request.call.name,
          outputPath: request.outputPath,
          maxOutputChars: request.maxOutputChars,
          arguments: coerceArguments(
            request.definition,
            request.call.arguments,
          ),
        ),
      );
      final entry = JobEntry(
        call: request.call,
        conversationId: request.conversationId,
        agentId: request.agentId,
        job: job,
      );
      if (job.outcome == null) _jobs.add(entry);
      await _settlement.settle(request, entry);
    } on Object catch (error) {
      request.settle(
        ToolCallFailed(
          callId: request.call.id,
          toolName: request.call.name,
          message: '${error.runtimeType}: $error',
          elapsedMs: request.elapsedMs,
        ),
      );
    }
  }

  /// Stops every job the router holds — pending-call and in background alike.
  void stopAllJobs() => _jobs.stopAll();

  Future<void> dispose() async {
    await _requests.cancel();
    _jobs.stopAll();
    await _jobs.dispose();
    _reporter.dispose();
  }
}
