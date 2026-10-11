import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class LocalModelsConfigKeys {
  const LocalModelsConfigKeys({required this.paths});

  factory LocalModelsConfigKeys.defaults() => LocalModelsConfigKeys(
    paths: ConfigKey<List<String>>(
      id: 'models.paths',
      path: const ['models', 'paths'],
      codec: ConfigCodecs.stringLists,
      defaultValue: () => const [],
      effect: ConfigEffect.onCommit,
      field: const ListField(
        label: 'Model folders',
        description: 'Folders to look in for model files, one per line.',
      ),
    ),
  );

  /// Folders searched for model files besides bestie's own.
  final ConfigKey<List<String>> paths;
}
