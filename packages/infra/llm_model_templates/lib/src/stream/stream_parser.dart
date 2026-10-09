import 'package:llm_model_templates/src/stream/model_output.dart';
import 'package:llm_model_templates/src/stream/stream_chunk.dart';

abstract interface class StreamParser {
  /// Starts a stateful parser session for a single model output stream.
  ///
  /// [answerPrefilled] tells the session the prompt already opened the answer
  /// channel, so generation begins mid-answer with no leading channel marker.
  /// Parsers that route by channel marker (Harmony) must start in their answer
  /// state or the prefilled continuation is misclassified; parsers that default
  /// to a plain-text state ignore it.
  ///
  /// [reasoningPrefilled] tells the session the prompt already opened a
  /// reasoning block (e.g. a trailing `<think>\n`), so generation begins
  /// mid-reasoning and no opening think tag will ever arrive. Sessions that
  /// track reasoning must start in their reasoning state or the entire block
  /// is misclassified as answer text.
  StreamParserSession start({
    Set<String>? knownToolNames,
    bool answerPrefilled = false,
    bool reasoningPrefilled = false,
  });
}

abstract interface class StreamParserSession {
  Iterable<ModelOutput> add(StreamChunk chunk);

  Iterable<ModelOutput> finish();
}
