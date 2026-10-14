import 'package:intentions/intentions.dart';
import 'package:openai_endpoint_client/openai_endpoint_client.dart';

/// The custom OpenAI-compatible endpoint as the user configured it,
/// reached through its client.
@repository
class OpenAiEndpointRepository {
  OpenAiEndpointRepository({required OpenAiEndpointClient client})
    : _client = client;

  final OpenAiEndpointClient _client;
  OpenAiEndpointSettings _settings = OpenAiEndpointSettings.unset;

  /// What the user gave us, last configured.
  OpenAiEndpointSettings get settings => _settings;

  /// Reaches the custom OpenAI-compatible endpoint with [settings] from now on.
  void configure(OpenAiEndpointSettings settings) {
    _settings = settings;
    _client.configure(settings);
  }
}
