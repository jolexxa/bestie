import 'dart:async';

import 'package:bestie_openrouter_use_case/src/open_router_config_keys.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:openrouter_repository/openrouter_repository.dart';
import 'package:provider_openrouter/provider_openrouter.dart';

/// Keeps OpenRouter configured the way the user set it up.
@useCase
class OpenRouterUseCase implements CommandContribution {
  OpenRouterUseCase({
    required ConfigRepository config,
    required OpenRouterConfigKeys configKeys,
    required OpenRouterRepository repository,
  }) : _config = config,
       _configKeys = configKeys,
       _repository = repository {
    _repository.configure(settings);
    _configSub = _config.changes.listen(_onConfigChange);
  }

  @override
  List<Command> get commands => const [];

  final ConfigRepository _config;
  final OpenRouterConfigKeys _configKeys;
  final OpenRouterRepository _repository;
  late final StreamSubscription<ConfigChange> _configSub;

  late final Set<String> _settingsKeyIds = {
    for (final key in _configKeys.settingsKeys) key.id,
  };

  /// The settings as configured right now.
  OpenRouterSettings get settings => OpenRouterSettings(
    apiKey: _config.resolve(_configKeys.apiKey.global).trim(),
  );

  Future<void> dispose() => _configSub.cancel();

  void _onConfigChange(ConfigChange change) {
    if (!change.keyIds.any(_settingsKeyIds.contains)) return;
    _repository.configure(settings);
  }
}
