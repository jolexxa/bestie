import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// What the user gives us to reach Fireworks AI, kept under
/// `provider.fireworks`.
@model
final class FireworksConfigKeys {
  const FireworksConfigKeys({required this.apiKey});

  factory FireworksConfigKeys.defaults() => FireworksConfigKeys(
    apiKey: ConfigKey<String>(
      id: 'provider.fireworks.api_key',
      path: const ['provider', 'fireworks', 'apiKey'],
      codec: ConfigCodecs.strings,
      defaultValue: () => '',
      field: const OpaqueField(
        label: 'Fireworks AI API key',
        description:
            'Your Fireworks AI key. Bestie reconnects when it changes.',
        secret: true,
      ),
      effect: ConfigEffect.onCommit,
    ),
  );

  final ConfigKey<String> apiKey;

  /// Keys the settings are built from.
  Iterable<ConfigKeyBase> get settingsKeys => [apiKey];
}
