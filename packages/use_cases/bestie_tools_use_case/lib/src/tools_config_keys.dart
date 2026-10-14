import 'package:config_protocol/config_protocol.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

/// How many tool calls may execute at once.
const int defaultConcurrentTools = 16;

/// The range the concurrency setting offers. A worker costs about 30KB and is
/// spawned only once it is needed, so the ceiling is headroom rather than a
/// reservation.
const int minConcurrentTools = 1;
const int maxConcurrentTools = 64;

@model
final class ToolsConfigKeys {
  const ToolsConfigKeys({
    required this.concurrentTools,
    required this.toolCacheChars,
  });

  factory ToolsConfigKeys.defaults() => ToolsConfigKeys(
    concurrentTools: ConfigKey<int>(
      id: 'tools.concurrent',
      path: const ['tools', 'concurrent'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultConcurrentTools,
      field: const NumericField(
        label: 'Concurrent Tools',
        description:
            'How many tool calls may run at once. Each runs off the '
            'interface thread, so lowering this only trades tool speed '
            'for room the model can generate in. Applies immediately.',
        min: minConcurrentTools,
        max: maxConcurrentTools,
        step: 1,
      ),
    ),
    toolCacheChars: ConfigKey<int>(
      id: 'tools.cache_characters',
      path: const ['tools', 'cacheCharacters'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultToolCacheChars,
      field: const NumericField(
        label: 'Tool Cache Characters',
        description:
            'How much of the start of a stored tool output is kept on hand '
            'to answer from.',
        min: 1024,
        max: 1 << 20,
        step: 1024,
      ),
    ),
  );

  /// How many tool calls may execute at once.
  final ConfigKey<int> concurrentTools;

  /// Characters of a stored tool output's beginning the store caches to
  /// answer with.
  final ConfigKey<int> toolCacheChars;
}
