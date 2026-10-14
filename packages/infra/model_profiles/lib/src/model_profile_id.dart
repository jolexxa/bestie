import 'package:dart_mappable/dart_mappable.dart';

part 'model_profile_id.mapper.dart';

/// Identifies which prompt formatter / chat template family a model belongs to.
@MappableEnum()
enum ModelProfileId {
  /// Qwen 3 family — supports a binary on/off reasoning toggle.
  @MappableValue('qwen3')
  qwen3,

  /// Qwen 3.5 family — hybrid-attention lineage with a binary on/off
  /// reasoning toggle and XML tool calls.
  @MappableValue('qwen35')
  qwen35,

  /// Qwen 2.5 family — no reasoning support.
  @MappableValue('qwen25')
  qwen25,

  /// OpenAI's open-weights GPT family — exposes low/medium/high
  /// reasoning intensities.
  @MappableValue('gpt_oss')
  gptOss,

  /// Qwen 3 Coder variant — coding-focused, no reasoning.
  @MappableValue('qwen3_coder')
  qwen3Coder,

  /// Gemma 4 family — supports a binary on/off reasoning toggle.
  @MappableValue('gemma4')
  gemma4,

  /// GLM-4 family — covers GLM-4, 4.5, 4.5-Air, 4.6, 4.7. Supports a
  /// binary on/off reasoning toggle.
  @MappableValue('glm4')
  glm4;

  /// Human-readable label for this family, surfaced in UI listings of
  /// supported architectures.
  String get displayName => switch (this) {
    ModelProfileId.qwen3 => 'Qwen 3',
    ModelProfileId.qwen35 => 'Qwen 3.5',
    ModelProfileId.qwen25 => 'Qwen 2.5',
    ModelProfileId.gptOss => 'GPT-OSS',
    ModelProfileId.qwen3Coder => 'Qwen 3 Coder',
    ModelProfileId.gemma4 => 'Gemma 4',
    ModelProfileId.glm4 => 'GLM-4',
  };
}
