import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

const double defaultCompactionRatio = 0.85;

@model
final class ChatConfigKeys {
  const ChatConfigKeys({
    required this.systemPrompt,
    required this.memoryCompactionRatio,
    required this.maxToolCallCharacters,
  });

  factory ChatConfigKeys.defaults({required String defaultSystemPrompt}) =>
      ChatConfigKeys(
        systemPrompt: ConfigKey<String>(
          id: 'prompt.system',
          path: const ['systemPromptOverride'],
          codec: ConfigCodecs.strings,
          defaultValue: () => defaultSystemPrompt,
        ),
        memoryCompactionRatio: ConfigKey<double>(
          id: 'memory.compaction_ratio',
          path: const ['compaction', 'compactionRatio'],
          codec: ConfigCodecs.doubles,
          defaultValue: () => defaultCompactionRatio,
        ),
        maxToolCallCharacters: ConfigKey<int>(
          id: 'tools.max_call_characters',
          path: const ['tools', 'maxCallCharacters'],
          codec: ConfigCodecs.integers,
          defaultValue: () => defaultMaxToolCallCharacters,
        ),
      );

  final ConfigKey<String> systemPrompt;
  final ConfigKey<double> memoryCompactionRatio;

  /// Ceiling on what one tool result may put into the conversation.
  final ConfigKey<int> maxToolCallCharacters;
}
