import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  final contribution = ChatConfigContribution(defaultSystemPrompt: 'Be kind.');
  final keys = contribution.configKeys;

  test('keys default to the prompt, compaction ratio, and tool cap', () {
    expect(keys.systemPrompt.defaultValue(), 'Be kind.');
    expect(keys.memoryCompactionRatio.defaultValue(), defaultCompactionRatio);
    expect(
      keys.maxToolCallCharacters.defaultValue(),
      defaultMaxToolCallCharacters,
    );
  });

  test('contributes one global entry per key', () {
    final entries = contribution.entries.toList();

    expect(entries.map((entry) => entry.key.id), [
      keys.systemPrompt.id,
      keys.memoryCompactionRatio.id,
      keys.maxToolCallCharacters.id,
    ]);
    expect(entries[0].field, isA<OpaqueField<String>>());
    expect(entries[1].field, isA<NumericField<double>>());
    expect(entries[2].field, isA<NumericField<int>>());
  });
}
