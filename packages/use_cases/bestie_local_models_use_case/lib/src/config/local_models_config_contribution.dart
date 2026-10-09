import 'package:bestie_local_models_use_case/src/config/local_models_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class LocalModelsConfigContribution implements ConfigContribution {
  LocalModelsConfigContribution()
    : configKeys = LocalModelsConfigKeys.defaults();

  final LocalModelsConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(key: configKeys.paths, field: _pathsField),
  ];
}

final _pathsField = ListField(
  label: 'Model folders',
  description:
      'Folders to look in for model files, one per line. "Add model folder" '
      'in the palette adds one too.',
);
