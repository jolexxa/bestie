import 'package:fireworks_client/fireworks_client.dart';
import 'package:intentions/intentions.dart';

/// Fireworks AI as the user configured it, reached through its client.
@repository
class FireworksRepository {
  FireworksRepository({required FireworksClient client}) : _client = client;

  final FireworksClient _client;
  FireworksSettings _settings = FireworksSettings.unset;

  /// What the user gave us, last configured.
  FireworksSettings get settings => _settings;

  /// Reaches Fireworks AI with [settings] from now on.
  void configure(FireworksSettings settings) {
    _settings = settings;
    _client.configure(settings);
  }
}
