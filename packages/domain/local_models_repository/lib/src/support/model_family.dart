/// Which prompt format runs a model, from its architecture and chat
/// template. Template signatures follow llama.cpp's
/// `llm_chat_detect_template` (MIT, the ggml authors).
library;

import 'package:intentions/intentions.dart';
import 'package:llm_model_profiles/llm_model_profiles.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';

/// Architectures with exactly one prompt format, in canonical form.
const _profileByArchitecture = <String, ModelProfileId>{
  'qwen2': ModelProfileId.qwen25,
  'qwen35': ModelProfileId.qwen35,
  'qwen35moe': ModelProfileId.qwen35,
  'gptoss': ModelProfileId.gptOss,
  'gemma4': ModelProfileId.gemma4,
  'glm4': ModelProfileId.glm4,
  'glm4moe': ModelProfileId.glm4,
};

/// Architectures shared by Qwen 3, Qwen 3 Coder and some Qwen 3.5 builds,
/// which only the chat template tells apart.
const _qwen3Architectures = {'qwen3', 'qwen3moe', 'qwen3next'};

@model
sealed class ProfileMatch {
  const ProfileMatch();
}

@model
final class ProfileMatched extends ProfileMatch {
  const ProfileMatched(this.profile);

  final ModelProfileId profile;
}

@model
final class ProfileUnmatched extends ProfileMatch {
  const ProfileUnmatched(this.reason);

  final ProfileUnavailable reason;
}

/// The prompt format for [architecture], provided [chatTemplate] is written
/// in it. A fine-tune that swapped in another family's template, such as
/// DeepSeek's R1 distills of Qwen, matches nothing.
///
/// GLM-5 (`glm-dsa`) and Phi-4 (`phi3`) fall through on purpose: their
/// templates resemble GLM-4 and ChatML but neither format runs them.
ProfileMatch profileFor(String architecture, String? chatTemplate) {
  final canonical = _canonical(architecture);
  final template = chatTemplate ?? '';
  final profile =
      _profileByArchitecture[canonical] ??
      (_qwen3Architectures.contains(canonical)
          ? _qwen3Profile(template)
          : null);
  return switch (profile) {
    final profile? when _speaks(profile, template) => ProfileMatched(profile),
    _? => ProfileUnmatched(TemplateUnrecognized(architecture)),
    null => ProfileUnmatched(ArchitectureUnsupported(architecture)),
  };
}

/// Lowercase with separators stripped, so `gpt-oss` and `gpt_oss` agree.
String _canonical(String architecture) =>
    architecture.toLowerCase().replaceAll(RegExp('[-_]'), '');

/// Thinking takes priority over XML tools: some coder fine-tunes carry both,
/// and they think.
ModelProfileId _qwen3Profile(String template) => switch (template) {
  _ when _isQwen35(template) => ModelProfileId.qwen35,
  _ when template.contains('enable_thinking') => ModelProfileId.qwen3,
  _ when template.contains('<function=') || template.contains('<parameter') =>
    ModelProfileId.qwen3Coder,
  _ => ModelProfileId.qwen3,
};

bool _isQwen35(String template) =>
    template.contains('enable_thinking') &&
    template.contains('<function=') &&
    template.contains('<|vision_start|>');

/// Whether [template] carries the turn markers of [profile]'s format.
bool _speaks(ModelProfileId profile, String template) => switch (profile) {
  ModelProfileId.qwen25 ||
  ModelProfileId.qwen3 ||
  ModelProfileId.qwen3Coder ||
  ModelProfileId.qwen35 =>
    template.contains('<|im_start|>') && !template.contains('<|im_sep|>'),
  ModelProfileId.gptOss =>
    template.contains('<|start|>') && template.contains('<|channel|>'),
  ModelProfileId.gemma4 =>
    template.contains('<|turn>') && template.contains('<turn|>'),
  ModelProfileId.glm4 => template.contains('[gMASK]<sop>'),
};
