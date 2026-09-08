import 'package:bestie_chat_use_case/src/chat_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class ChatConfigContribution implements ConfigContribution {
  ChatConfigContribution({required String defaultSystemPrompt})
    : configKeys = ChatConfigKeys.defaults(
        defaultSystemPrompt: defaultSystemPrompt,
      );

  final ChatConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.systemPrompt,
      field: OpaqueField<String>(
        label: 'System Prompt',
        description: 'System prompt.',
        maxLines: 8,
      ),
    ),
    globalEntry(
      key: configKeys.memoryCompactionRatio,
      field: NumericField<double>(
        label: 'Compaction Ratio',
        description:
            'Used context at or above this fraction triggers compaction '
            'before the next agent step. Applies on next turn.',
        min: 0.1,
        max: 0.95,
        step: 0.05,
      ),
    ),
    globalEntry(
      key: configKeys.maxToolCallCharacters,
      field: NumericField<int>(
        label: 'Max Tool Call Characters',
        description: 'Tool call response cap. Applies next turn.',
        min: 500,
        max: 32000,
        step: 500,
      ),
    ),
  ];
}
