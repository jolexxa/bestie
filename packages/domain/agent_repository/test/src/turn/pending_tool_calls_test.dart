import 'dart:async';

import 'package:agent_repository/src/conversation/conversation_store.dart';
import 'package:agent_repository/src/turn/pending_tool_calls.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockConversationStore extends Mock implements ConversationStore {}

const _definition = ToolDefinition(
  name: 'search',
  description: 'Searches.',
  parameters: {},
  onProgress: 'Searching',
  onSuccess: 'Searched',
  onError: 'Search failed',
);

void main() {
  late StreamController<ToolCallRequest> requests;
  late PendingToolCalls pending;

  setUp(() {
    requests = StreamController<ToolCallRequest>.broadcast();
    final store = _MockConversationStore();
    when(
      () => store.toolOutputPath(
        conversationId: any(named: 'conversationId'),
        agentId: any(named: 'agentId'),
        callId: any(named: 'callId'),
      ),
    ).thenReturn('/conversations/conversation/agent/tools/call');
    pending = PendingToolCalls(
      definitions: ToolDefinitions([_definition]),
      requests: requests.sink,
      conversationStore: store,
      conversationId: 'conversation',
      agentId: 'agent',
    );
  });

  tearDown(() async {
    pending.dispose();
    await requests.close();
  });

  test(
    'forwards an offered call with its conversation and agent address',
    () async {
      const call = ToolCallDefault(
        id: 'call',
        name: 'search',
        arguments: {},
      );
      final next = requests.stream.first;

      pending.start(call, maxOutputChars: 4000);

      final request = await next;
      expect(request.call, call);
      expect(request.conversationId, 'conversation');
      expect(request.agentId, 'agent');
      expect(
        request.outputPath,
        '/conversations/conversation/agent/tools/call',
      );
      request.settle(
        const ToolCallSucceeded(
          callId: 'call',
          toolName: 'search',
          content: 'ok',
        ),
      );
      expect((await pending.join([call])).single.modelText, 'ok');
    },
  );

  test('locally fails a call that was never offered', () async {
    const call = ToolCallDefault(id: 'call', name: 'unknown', arguments: {});

    pending.start(call, maxOutputChars: 4000);

    final response = (await pending.join([call])).single as ToolCallFailed;
    expect(response.message, contains('Unrecognized tool'));
  });

  test('cancels an unanswered request when the turn is abandoned', () async {
    const call = ToolCallDefault(id: 'call', name: 'search', arguments: {});
    final next = requests.stream.first;
    pending.start(call, maxOutputChars: 4000);
    final request = await next;

    pending.abortTurn();

    expect(await request.response, isA<ToolCallCanceled>());
  });

  test('leaves a call that already moved to the background alone', () async {
    const call = ToolCallDefault(id: 'call', name: 'search', arguments: {});
    final next = requests.stream.first;
    pending.start(call, maxOutputChars: 4000);
    final request = await next;
    request.settle(
      const ToolCallInBackground(
        callId: 'call',
        toolName: 'search',
        content: 'working',
      ),
    );
    await pending.join([call]);

    pending.abortTurn();

    expect(await request.response, isA<ToolCallInBackground>());
  });

  test(
    'abandons a join when its owning turn settles first',
    () async {
      const call = ToolCallDefault(id: 'call', name: 'search', arguments: {});
      final next = requests.stream.first;
      final aborted = Completer<void>();
      pending.start(call, maxOutputChars: 4000);
      await next;

      final joined = pending.join([call], aborted: aborted.future);
      aborted.complete();

      expect(await joined, isEmpty);
      pending.abortTurn();
    },
  );
}
