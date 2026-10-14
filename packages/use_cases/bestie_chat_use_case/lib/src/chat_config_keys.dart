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
    required this.sampling,
  });

  factory ChatConfigKeys.defaults({required String defaultSystemPrompt}) =>
      ChatConfigKeys(
        systemPrompt: ConfigKey<String>(
          id: 'prompt.system',
          path: const ['systemPromptOverride'],
          codec: ConfigCodecs.strings,
          defaultValue: () => defaultSystemPrompt,
          field: const OpaqueField(
            label: 'System Prompt',
            description: 'System prompt.',
            maxLines: 8,
          ),
        ),
        memoryCompactionRatio: ConfigKey<double>(
          id: 'memory.compaction_ratio',
          path: const ['compaction', 'compactionRatio'],
          codec: ConfigCodecs.doubles,
          defaultValue: () => defaultCompactionRatio,
          field: const NumericField(
            label: 'Compaction Ratio',
            description:
                'Used context at or above this fraction triggers compaction '
                'before the next agent step. Applies on next turn.',
            min: 0.1,
            max: 0.95,
            step: 0.05,
          ),
        ),
        maxToolCallCharacters: ConfigKey<int>(
          id: 'tools.max_call_characters',
          path: const ['tools', 'maxCallCharacters'],
          codec: ConfigCodecs.integers,
          defaultValue: () => defaultMaxToolCallCharacters,
          field: const NumericField(
            label: 'Max Tool Call Characters',
            description: 'Tool call response cap. Applies next turn.',
            min: 500,
            max: 32000,
            step: 500,
          ),
        ),
        sampling: ChatSamplingConfigKeys.defaults(),
      );

  final ConfigKey<String> systemPrompt;
  final ConfigKey<double> memoryCompactionRatio;

  /// Ceiling on what one tool result may put into the conversation.
  final ConfigKey<int> maxToolCallCharacters;

  /// How every turn samples tokens.
  final ChatSamplingConfigKeys sampling;
}

/// The sampling every turn runs under, kept under `provider.sampling`.
@model
final class ChatSamplingConfigKeys {
  const ChatSamplingConfigKeys({
    required this.temperature,
    required this.topP,
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.seed,
  });

  factory ChatSamplingConfigKeys.defaults() => ChatSamplingConfigKeys(
    temperature: _samplingKey(
      'temperature',
      'temperature',
      0.7,
      const NumericField(
        label: 'Temperature',
        description:
            'Controls randomness in token selection. '
            'Higher values produce more creative output.',
        min: 0,
        max: 2,
        step: 0.1,
        unsetLabel: _modelDefault,
      ),
    ),
    topP: _samplingKey(
      'top_p',
      'topP',
      1,
      const NumericField(
        label: 'Top-P',
        description:
            'Limits token selection to a cumulative probability. '
            'Lower values make output more focused.',
        min: 0,
        max: 1,
        step: 0.05,
        unsetLabel: _modelDefault,
      ),
    ),
    frequencyPenalty: _samplingKey(
      'frequency_penalty',
      'frequencyPenalty',
      0,
      const NumericField(
        label: 'Frequency Penalty',
        description: 'Penalizes tokens proportional to how often they appear.',
        min: -2,
        max: 2,
        step: 0.1,
        unsetLabel: _modelDefault,
      ),
    ),
    presencePenalty: _samplingKey(
      'presence_penalty',
      'presencePenalty',
      0,
      const NumericField(
        label: 'Presence Penalty',
        description: 'Flat penalty for any token that has appeared at all.',
        min: -2,
        max: 2,
        step: 0.1,
        unsetLabel: _modelDefault,
      ),
    ),
    seed: ConfigKey<int>(
      id: 'provider.sampling.seed',
      path: const ['provider', 'sampling', 'seed'],
      codec: ConfigCodecs.integers,
      defaultValue: () => 0,
      field: const NumericField(
        label: 'Seed',
        description:
            'Sampling seed for providers that honor one. 0 = unseeded.',
        min: 0,
        max: 999999999,
        step: 1,
      ),
    ),
  );

  final ConfigKey<double> temperature;
  final ConfigKey<double> topP;
  final ConfigKey<double> frequencyPenalty;
  final ConfigKey<double> presencePenalty;

  /// 0 leaves sampling unseeded.
  final ConfigKey<int> seed;
}

const _modelDefault = 'model default';

ConfigKey<double> _samplingKey(
  String id,
  String path,
  double defaultValue,
  ConfigField<double> field,
) => ConfigKey<double>(
  id: 'provider.sampling.$id',
  path: ['provider', 'sampling', path],
  codec: ConfigCodecs.doubles,
  defaultValue: () => defaultValue,
  field: field,
);
