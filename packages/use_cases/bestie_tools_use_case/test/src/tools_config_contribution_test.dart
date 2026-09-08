import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:test/test.dart';

void main() {
  final contribution = ToolsConfigContribution();
  final keys = contribution.configKeys;

  test('keys default to the shipped concurrency and cache size', () {
    expect(keys.concurrentTools.id, 'tools.concurrent');
    expect(keys.concurrentTools.defaultValue(), defaultConcurrentTools);
    expect(keys.toolCacheChars.id, 'tools.cache_characters');
    expect(keys.toolCacheChars.defaultValue(), defaultToolCacheChars);
  });

  test('offers only the concurrency in the overlay, held to its range', () {
    final entry = contribution.entries.single;

    expect(entry.key.id, keys.concurrentTools.id);
    final field = entry.field as NumericField<int>;
    expect(field.min, minConcurrentTools);
    expect(field.max, maxConcurrentTools);
  });
}
