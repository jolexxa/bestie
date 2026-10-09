import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('PromptMessageFormatting', () {
    test('exposes content and metadata for tool messages', () {
      const message = PromptToolMessage(
        toolCallId: 'call-1',
        name: 'search',
        content: 'result',
      );

      expect(PromptMessageFormatting(message).content, 'result');
      expect(message.chatMlRole, 'tool');
      expect(message.reasoning, isNull);
      expect(message.toolCalls, isEmpty);
      expect(message.toolCallId, 'call-1');
      expect(message.name, 'search');
      expect(message.isSystemLike, isFalse);
    });

    test('exposes assistant reasoning and tool calls', () {
      const call = ToolCallDefault(
        id: 'call-1',
        name: 'search',
        arguments: {'q': 'cow'},
      );
      const message = PromptAssistantMessage(
        content: 'answer',
        reasoning: 'plan',
        toolCalls: [call],
      );

      expect(message.content, 'answer');
      expect(message.chatMlRole, 'assistant');
      expect(message.reasoning, 'plan');
      expect(message.toolCalls, [call]);
      expect(message.toolCallId, isNull);
      expect(message.name, isNull);
    });
  });
}
