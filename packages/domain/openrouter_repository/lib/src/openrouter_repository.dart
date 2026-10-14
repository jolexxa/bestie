import 'package:intentions/intentions.dart';
import 'package:openrouter_client/openrouter_client.dart';

/// OpenRouter as the user configured it, reached through its client.
@repository
class OpenRouterRepository {
  OpenRouterRepository({required OpenRouterClient client}) : _client = client;

  final OpenRouterClient _client;
  OpenRouterSettings _settings = OpenRouterSettings.unset;

  /// What the user gave us, last configured.
  OpenRouterSettings get settings => _settings;

  /// Reaches OpenRouter with [settings] from now on.
  void configure(OpenRouterSettings settings) {
    _settings = settings;
    _client.configure(settings);
  }
}
