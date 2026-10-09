import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:tool_protocol/tool_protocol.dart';

const goldenTool = PromptTool(
  name: 'search_web',
  description: 'Search the web',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Search query'},
      'limit': {'type': 'integer', 'description': 'Max results'},
    },
    'required': ['query'],
  },
);

const List<PromptMessage> goldenMessages = [
  PromptSystemMessage('You are helpful.'),
  PromptUserMessage('Find facts about cows.'),
  PromptAssistantMessage(
    content: 'I will search.',
    reasoning: 'Need current facts.',
    toolCalls: [
      ToolCallDefault(
        id: 'call-1',
        name: 'search_web',
        arguments: {'query': 'cows', 'limit': 2},
      ),
    ],
  ),
  PromptToolMessage(
    toolCallId: 'call-1',
    name: 'search_web',
    content: 'Cows are domesticated bovines.',
  ),
  PromptAssistantMessage(content: 'Cows are domesticated bovines.'),
];

String goldenLines(List<String> lines) => lines.join('\n');

String goldenLine(List<String> parts) => parts.join();
