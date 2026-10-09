import 'package:llm_model_profiles/llm_model_profiles.dart' show ModelProfileId;
import 'package:llm_model_templates/src/extractors/gemma_tool_call_extractor.dart';
import 'package:llm_model_templates/src/extractors/glm_tool_call_extractor.dart';
import 'package:llm_model_templates/src/extractors/json_tool_call_extractor.dart';
import 'package:llm_model_templates/src/extractors/xml_tool_call_extractor.dart';
import 'package:llm_model_templates/src/formatters/gemma4_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/glm_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/harmony_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/qwen25_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/qwen35_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/qwen3_coder_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/qwen3_prompt_formatter.dart';
import 'package:llm_model_templates/src/stream/harmony_stream_parser.dart';
import 'package:llm_model_templates/src/stream/stream_parser.dart';
import 'package:llm_model_templates/src/stream/stream_tokenizer.dart';
import 'package:llm_model_templates/src/stream/universal_stream_parser.dart';

final class ModelProfiles {
  // -- Stream parsers --

  static final StreamParser qwenStreamParser = UniversalStreamParser(
    config: StreamParserConfig(
      toolCallExtractor: JsonToolCallExtractor(),
      tags: StreamTokenizer.defaultTags,
      supportsReasoning: true,
    ),
  );

  // -- Model profiles --

  static final List<String> _qwenTagStrings = StreamTokenizer.defaultTags
      .map((definition) => definition.tag)
      .toList();

  static const List<String> _harmonyTagStrings = [
    '<|channel|>',
    '<|message|>',
    '<|end|>',
    '<|call|>',
    '<|start|>',
    '<|constrain|>',
    'to=functions.',
  ];

  static final ModelProfile qwen3 = ModelProfile(
    formatter: const Qwen3PromptFormatter(),
    streamParser: qwenStreamParser,
    tags: _qwenTagStrings,
  );

  // Qwen 3.5

  // Thinking model with XML tool calls: the coder-style `<function=` /
  // `</function>` fallback boundaries (see `_qwen3CoderTags`) plus the
  // standard think tags.
  static const _qwen35Tags = <TagDefinition>[
    TagDefinition(tag: '<think>', type: StreamTokenType.thinkStart),
    TagDefinition(tag: '</think>', type: StreamTokenType.thinkEnd),
    TagDefinition(tag: '<tool_call>', type: StreamTokenType.toolStart),
    TagDefinition(tag: '</tool_call>', type: StreamTokenType.toolEnd),
    TagDefinition(
      tag: '<function=',
      type: StreamTokenType.toolStart,
      keepInBuffer: true,
    ),
    TagDefinition(
      tag: '</function>',
      type: StreamTokenType.toolEnd,
      keepInBuffer: true,
    ),
  ];

  static final List<String> _qwen35TagStrings = _qwen35Tags
      .map((definition) => definition.tag)
      .toList();

  static final StreamParser qwen35StreamParser = UniversalStreamParser(
    config: StreamParserConfig(
      toolCallExtractor: XmlToolCallExtractor(),
      tags: _qwen35Tags,
      supportsReasoning: true,
    ),
  );

  static final ModelProfile qwen35 = ModelProfile(
    formatter: const Qwen35PromptFormatter(),
    streamParser: qwen35StreamParser,
    tags: _qwen35TagStrings,
  );

  static final ModelProfile qwen25 = ModelProfile(
    formatter: const Qwen25PromptFormatter(),
    streamParser: qwenStreamParser,
    tags: _qwenTagStrings,
  );

  // Qwen3-Coder is non-thinking only — no <think> tags in the tokenizer.
  //
  // The `<function=` / `</function>` entries are *fallback* tool-call
  // boundaries for the case where the model emits the XML body without
  // a surrounding `<tool_call>` wrapper — a known quirk of the smaller
  // Coder checkpoints. `keepInBuffer: true` lets the parser preserve
  // the matched tag text inside the tool-call buffer so
  // `XmlToolCallExtractor` still sees the function name. When a
  // `<tool_call>` wrapper IS present, the earliest-match semantics of
  // `_findEarliestTag` make it win over `<function=`, preserving the
  // wrapped-case behaviour.
  static const _qwen3CoderTags = <TagDefinition>[
    TagDefinition(tag: '<tool_call>', type: StreamTokenType.toolStart),
    TagDefinition(tag: '</tool_call>', type: StreamTokenType.toolEnd),
    TagDefinition(
      tag: '<function=',
      type: StreamTokenType.toolStart,
      keepInBuffer: true,
    ),
    TagDefinition(
      tag: '</function>',
      type: StreamTokenType.toolEnd,
      keepInBuffer: true,
    ),
  ];

  static final List<String> _qwen3CoderTagStrings = _qwen3CoderTags
      .map((definition) => definition.tag)
      .toList();

  static final StreamParser qwen3CoderStreamParser = UniversalStreamParser(
    config: StreamParserConfig(
      toolCallExtractor: XmlToolCallExtractor(),
      tags: _qwen3CoderTags,
      supportsReasoning: false,
    ),
  );

  static final ModelProfile qwen3Coder = ModelProfile(
    formatter: const Qwen3CoderPromptFormatter(),
    streamParser: qwen3CoderStreamParser,
    tags: _qwen3CoderTagStrings,
  );

  static final ModelProfile gptOss = ModelProfile(
    formatter: const HarmonyPromptFormatter(),
    streamParser: HarmonyStreamParser(),
    tags: _harmonyTagStrings,
  );

  // -- Gemma 4 --

  static const _gemma4Tags = <TagDefinition>[
    TagDefinition(
      tag: '<|channel>thought\n',
      type: StreamTokenType.thinkStart,
    ),
    TagDefinition(tag: '<channel|>', type: StreamTokenType.thinkEnd),
    TagDefinition(tag: '<|tool_call>', type: StreamTokenType.toolStart),
    TagDefinition(tag: '<tool_call|>', type: StreamTokenType.toolEnd),
  ];

  static final List<String> _gemma4TagStrings = _gemma4Tags
      .map((definition) => definition.tag)
      .toList();

  static final StreamParser gemma4StreamParser = UniversalStreamParser(
    config: StreamParserConfig(
      toolCallExtractor: GemmaToolCallExtractor(),
      tags: _gemma4Tags,
      supportsReasoning: true,
    ),
  );

  static final ModelProfile gemma4 = ModelProfile(
    formatter: const Gemma4PromptFormatter(),
    streamParser: gemma4StreamParser,
    tags: _gemma4TagStrings,
  );

  // -- GLM-4 family --

  static const _glm4Tags = <TagDefinition>[
    TagDefinition(tag: '<think>', type: StreamTokenType.thinkStart),
    TagDefinition(tag: '</think>', type: StreamTokenType.thinkEnd),
    TagDefinition(tag: '<tool_call>', type: StreamTokenType.toolStart),
    TagDefinition(tag: '</tool_call>', type: StreamTokenType.toolEnd),
  ];

  static final List<String> _glm4TagStrings = _glm4Tags
      .map((definition) => definition.tag)
      .toList();

  static final StreamParser glm4StreamParser = UniversalStreamParser(
    config: StreamParserConfig(
      toolCallExtractor: GlmToolCallExtractor(),
      tags: _glm4Tags,
      supportsReasoning: true,
    ),
  );

  static final ModelProfile glm4 = ModelProfile(
    formatter: const GlmPromptFormatter(),
    streamParser: glm4StreamParser,
    tags: _glm4TagStrings,
  );

  static ModelProfile profileFor(ModelProfileId id) {
    return switch (id) {
      ModelProfileId.qwen3 => qwen3,
      ModelProfileId.qwen35 => qwen35,
      ModelProfileId.qwen25 => qwen25,
      ModelProfileId.gptOss => gptOss,
      ModelProfileId.qwen3Coder => qwen3Coder,
      ModelProfileId.gemma4 => gemma4,
      ModelProfileId.glm4 => glm4,
    };
  }
}
