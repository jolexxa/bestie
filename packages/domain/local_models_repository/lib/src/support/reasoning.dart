/// What a model can do with reasoning, from its profile and the signals in
/// its chat template.
library;

import 'package:local_inference_protocol/local_inference_protocol.dart';

const _gptOssEfforts = ['low', 'medium', 'high'];

/// The generation prompt opens a `<think>` block on its own, so the model
/// thinks on every turn whatever the request says.
final _forcedThinking = RegExp(
  '''assistant[^'"{}]{0,16}<think>''',
  caseSensitive: false,
);

/// A profile that cannot reason never gains it from its template; one that
/// can is pinned down by the first template signal it finds. Without a
/// signal, GLM-4 reads as not reasoning, since its 0414 chat models carry
/// no thinking in their template, while the other families keep their
/// profile's default.
ModelReasoning detectReasoning(ModelProfileId profile, String? chatTemplate) {
  final template = chatTemplate ?? '';
  return switch (profile) {
    ModelProfileId.qwen25 ||
    ModelProfileId.qwen3Coder => const ModelReasoningNone(),
    _ when template.contains('reasoning_effort') => const ModelReasoningEfforts(
      efforts: _gptOssEfforts,
    ),
    _ when template.contains('enable_thinking') => const ModelReasoningToggle(),
    _ when _forcedThinking.hasMatch(template) => const ModelReasoningAlways(),
    ModelProfileId.gptOss => const ModelReasoningEfforts(
      efforts: _gptOssEfforts,
    ),
    ModelProfileId.glm4 => const ModelReasoningNone(),
    ModelProfileId.qwen3 ||
    ModelProfileId.qwen35 ||
    ModelProfileId.gemma4 => const ModelReasoningToggle(),
  };
}
