import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

const _call = ToolCallDefault(id: 'call', name: 'read', arguments: {});
const _definition = ToolDefinition(
  name: 'read',
  description: 'Reads.',
  parameters: {},
  onProgress: 'Reading',
  onSuccess: 'Read',
  onError: 'Failed',
);

ToolCallRequest request() => ToolCallRequest(
  _call,
  definition: _definition,
  conversationId: 'conversation',
  agentId: 'agent',
  outputPath: 'conversations/conversation/agent/tools/call',
  maxOutputChars: 4000,
);

void main() {
  test('carries the call and its addressing context', () {
    final value = request();

    expect(value.call, _call);
    expect(value.conversationId, 'conversation');
    expect(value.agentId, 'agent');
  });

  test('measures elapsed time from its creation, including queueing', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final value = withClock(Clock(() => now), request);

    now = now.add(const Duration(milliseconds: 250));
    withClock(Clock(() => now), () => expect(value.elapsedMs, 250));
  });

  test('the first terminal response wins', () async {
    final value = request()
      ..settle(
        const ToolCallSucceeded(
          callId: 'call',
          toolName: 'read',
          content: 'first',
        ),
      )
      ..settle(
        const ToolCallFailed(
          callId: 'call',
          toolName: 'read',
          message: 'late',
        ),
      );

    expect((await value.response as ToolCallSucceeded).content, 'first');
  });
}
