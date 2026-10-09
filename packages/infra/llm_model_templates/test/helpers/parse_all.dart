import 'package:llm_model_templates/llm_model_templates.dart';

extension ParseAll on StreamParser {
  /// Runs one session over [chunks] and finishes it.
  Iterable<ModelOutput> parseAll(
    Iterable<StreamChunk> chunks, {
    Set<String>? knownToolNames,
  }) sync* {
    final session = start(knownToolNames: knownToolNames);
    for (final chunk in chunks) {
      yield* session.add(chunk);
    }
    yield* session.finish();
  }
}
