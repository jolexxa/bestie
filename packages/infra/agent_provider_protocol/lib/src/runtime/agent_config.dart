import 'package:tool_protocol/tool_protocol.dart';
import 'package:agent_provider_protocol/src/runtime/sampling_options.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'agent_config.mapper.dart';

@MappableClass(generateMethods: GenerateMethods.copy)
final class AgentConfig with AgentConfigMappable {
  const AgentConfig({
    required this.systemPrompt,
    required this.sampling,
    required this.reasoningMode,
    required this.compactionReasoningMode,
    required this.compactionRatio,
    required this.tools,
  });

  final String systemPrompt;
  final SamplingOptions sampling;
  final String reasoningMode;
  final String compactionReasoningMode;

  /// Fraction of the compaction limit at which pre-step compaction fires.
  final double compactionRatio;
  final List<ToolDefinition> tools;

  bool get isValid =>
      reasoningMode.trim().isNotEmpty &&
      compactionReasoningMode.trim().isNotEmpty &&
      compactionRatio > 0 &&
      compactionRatio <= 1;
}
