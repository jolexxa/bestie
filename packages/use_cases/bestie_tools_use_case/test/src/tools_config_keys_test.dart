import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:test/test.dart';

void main() {
  final keys = ToolsConfigKeys.defaults();

  test('keys default to the shipped concurrency and cache size', () {
    expect(keys.concurrentTools.id, 'tools.concurrent');
    expect(keys.concurrentTools.defaultValue(), defaultConcurrentTools);
    expect(keys.toolCacheChars.id, 'tools.cache_characters');
    expect(keys.toolCacheChars.defaultValue(), defaultToolCacheChars);
  });

  test('holds the concurrency to its range', () {
    final field = keys.concurrentTools.field as NumericField<int>;

    expect(field.min, minConcurrentTools);
    expect(field.max, maxConcurrentTools);
  });

  test('keeps the cache size within what the store can hold', () {
    final field = keys.toolCacheChars.field as NumericField<int>;

    expect(field.validateValue(defaultToolCacheChars), const Valid());
    expect(field.validateValue(0), isA<Invalid>());
  });
}
