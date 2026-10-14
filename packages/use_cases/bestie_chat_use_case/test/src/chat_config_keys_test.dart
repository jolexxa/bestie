import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  final keys = ChatConfigKeys.defaults(defaultSystemPrompt: 'Be kind.');

  test('keys default to the prompt, compaction ratio, and tool cap', () {
    expect(keys.systemPrompt.defaultValue(), 'Be kind.');
    expect(keys.memoryCompactionRatio.defaultValue(), defaultCompactionRatio);
    expect(
      keys.maxToolCallCharacters.defaultValue(),
      defaultMaxToolCallCharacters,
    );
  });

  test('shows the prompt as text and the numbers held to their ranges', () {
    expect(keys.systemPrompt.field, isA<OpaqueField<String>>());
    expect(keys.systemPrompt.field.maxLines, 8);
    expect(keys.memoryCompactionRatio.field, isA<NumericField<double>>());
    expect(keys.maxToolCallCharacters.field, isA<NumericField<int>>());
  });

  test('keeps the sampling where it was stored', () {
    final sampling = keys.sampling;

    expect(sampling.temperature.id, 'provider.sampling.temperature');
    expect(sampling.topP.path, ['provider', 'sampling', 'topP']);
    expect(sampling.frequencyPenalty.id, 'provider.sampling.frequency_penalty');
    expect(sampling.presencePenalty.path, [
      'provider',
      'sampling',
      'presencePenalty',
    ]);
    expect(sampling.seed.path, ['provider', 'sampling', 'seed']);
    expect(sampling.seed.defaultValue(), 0);
  });

  test('leaves sampling at the model default until chosen', () {
    final sampling = keys.sampling;

    expect(sampling.temperature.field.unsetLabel, 'model default');
    expect(sampling.topP.field.unsetLabel, 'model default');
    expect(sampling.seed.field.unsetLabel, isNull);
  });
}
