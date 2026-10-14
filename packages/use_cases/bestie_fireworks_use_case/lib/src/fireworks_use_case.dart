import 'dart:async';

import 'package:bestie_fireworks_use_case/src/fireworks_config_keys.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:fireworks_repository/fireworks_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_fireworks/provider_fireworks.dart';

/// Keeps Fireworks AI configured the way the user set it up.
@useCase
class FireworksUseCase implements CommandContribution {
  FireworksUseCase({
    required ConfigRepository config,
    required FireworksConfigKeys configKeys,
    required FireworksRepository repository,
  }) : _config = config,
       _configKeys = configKeys,
       _repository = repository {
    _repository.configure(settings);
    _configSub = _config.changes.listen(_onConfigChange);
  }

  @override
  List<Command> get commands => const [];

  final ConfigRepository _config;
  final FireworksConfigKeys _configKeys;
  final FireworksRepository _repository;
  late final StreamSubscription<ConfigChange> _configSub;

  late final Set<String> _settingsKeyIds = {
    for (final key in _configKeys.settingsKeys) key.id,
  };

  /// The settings as configured right now.
  FireworksSettings get settings => FireworksSettings(
    apiKey: _config.resolve(_configKeys.apiKey.global).trim(),
  );

  Future<void> dispose() => _configSub.cancel();

  void _onConfigChange(ConfigChange change) {
    if (!change.keyIds.any(_settingsKeyIds.contains)) return;
    _repository.configure(settings);
  }
}
