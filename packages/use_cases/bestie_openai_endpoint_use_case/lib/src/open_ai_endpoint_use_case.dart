import 'dart:async';

import 'package:bestie_openai_endpoint_use_case/src/open_ai_endpoint_config_keys.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:openai_endpoint_client/openai_endpoint_client.dart';
import 'package:openai_endpoint_repository/openai_endpoint_repository.dart';

/// Keeps the custom endpoint configured the way the user set it up.
@useCase
class OpenAiEndpointUseCase implements CommandContribution {
  OpenAiEndpointUseCase({
    required ConfigRepository config,
    required OpenAiEndpointConfigKeys configKeys,
    required OpenAiEndpointRepository repository,
  }) : _config = config,
       _configKeys = configKeys,
       _repository = repository {
    _repository.configure(settings);
    _configSub = _config.changes.listen(_onConfigChange);
  }

  @override
  List<Command> get commands => const [];

  final ConfigRepository _config;
  final OpenAiEndpointConfigKeys _configKeys;
  final OpenAiEndpointRepository _repository;
  late final StreamSubscription<ConfigChange> _configSub;

  late final Set<String> _settingsKeyIds = {
    for (final key in _configKeys.settingsKeys) key.id,
  };

  /// The settings as configured right now. An address that is not an
  /// absolute URL leaves the endpoint unset.
  OpenAiEndpointSettings get settings {
    final apiKey = _resolve(_configKeys.apiKey).trim();
    return OpenAiEndpointSettings(
      baseUrl: _absoluteUrl(_resolve(_configKeys.baseUrl)),
      apiKey: apiKey.isEmpty ? null : apiKey,
      contextWindow: _resolve(_configKeys.contextWindow),
    );
  }

  Future<void> dispose() => _configSub.cancel();

  T _resolve<T>(ConfigKey<T> key) => _config.resolve(key.global);

  void _onConfigChange(ConfigChange change) {
    if (!change.keyIds.any(_settingsKeyIds.contains)) return;
    _repository.configure(settings);
  }

  static Uri? _absoluteUrl(String typed) =>
      switch (Uri.tryParse(typed.trim())) {
        final url? when url.hasScheme && url.host.isNotEmpty => url,
        _ => null,
      };
}
