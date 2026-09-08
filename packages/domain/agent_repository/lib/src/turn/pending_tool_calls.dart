import 'dart:async';

import 'package:agent_repository/src/agent/agent_repository.dart';
import 'package:agent_repository/src/conversation/conversation_store.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// The tool calls one conversation is waiting on an answer for.
@PartOf(AgentRepository)
class PendingToolCalls {
  PendingToolCalls({
    required ToolDefinitions definitions,
    required Sink<ToolCallRequest> requests,
    required ConversationStore conversationStore,
    required String conversationId,
    required String agentId,
  }) : _definitions = definitions,
       _requests = requests,
       _conversationStore = conversationStore,
       _conversationId = conversationId,
       _agentId = agentId;

  /// What this conversation's agent is allowed to call.
  final ToolDefinitions _definitions;

  final Sink<ToolCallRequest> _requests;

  /// Names where each call may spill, so no caller has to know the layout.
  final ConversationStore _conversationStore;

  /// Which agent of which conversation this holder's spilled output belongs to.
  final String _conversationId;
  final String _agentId;

  /// This turn's answers, by tool call id. Held until the turn ends because
  /// the barrier looks them up long after they arrive.
  final Map<String, Future<ToolCallResponse>> _answers = {};

  /// Calls still awaiting their terminal response, by tool call id.
  final Map<String, ToolCallRequest> _live = {};

  /// Clears turn-scoped state. Work that outlived its turn deliberately
  /// survives.
  void reset() => _answers.clear();

  /// Asks for [call] to be answered in no more than [maxOutputChars].
  void start(ToolCall call, {required int maxOutputChars}) {
    if (_answers.containsKey(call.id)) return;

    final definition = _definitions.definitionFor(call.name);
    if (definition == null) {
      _answers[call.id] = Future.value(
        ToolCallFailed(
          callId: call.id,
          toolName: call.name,
          message: 'Unrecognized tool "${call.name}".',
        ),
      );
      return;
    }

    final request = ToolCallRequest(
      call,
      definition: definition,
      conversationId: _conversationId,
      agentId: _agentId,
      outputPath: _conversationStore.toolOutputPath(
        conversationId: _conversationId,
        agentId: _agentId,
        callId: call.id,
      ),
      maxOutputChars: maxOutputChars,
    );
    _live[call.id] = request;
    _answers[call.id] = _answerFor(request);
    _requests.add(request);
  }

  /// Awaits the answers for [order], in that order, and returns them.
  Future<List<ToolCallResponse>> join(
    List<ToolCall> order, {
    Future<void>? aborted,
  }) async {
    assert(
      order.every((call) => _answers.containsKey(call.id)),
      'join before start: every tool call must be started by its stream delta',
    );
    final all = Future.wait([for (final call in order) _answers[call.id]!]);
    if (aborted == null) return all;
    final results = await Future.any<List<ToolCallResponse>?>([
      all,
      aborted.then((_) => null),
    ]);
    return results ?? const [];
  }

  /// Cancels calls that have not yet received a terminal response.
  void abortTurn() => _abandonAll();

  void dispose() => _abandonAll();

  void _abandonAll() {
    final live = _live.values.toList();
    _live.clear();
    for (final request in live) {
      request.settle(
        ToolCallCanceled(
          callId: request.call.id,
          toolName: request.call.name,
          message: 'The tool call was interrupted.',
          elapsedMs: request.elapsedMs,
        ),
      );
    }
  }

  /// Stops tracking a call once its work is over. Work that handed back a
  /// background handle is not over, so it stays stoppable.
  Future<ToolCallResponse> _answerFor(ToolCallRequest request) async {
    final response = await request.response;
    _live.remove(request.call.id);
    return response;
  }
}
