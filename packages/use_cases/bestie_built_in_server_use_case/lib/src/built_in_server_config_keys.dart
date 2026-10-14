import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// How the built-in server loads models, kept under `provider.local`.
@model
final class BuiltInServerConfigKeys {
  const BuiltInServerConfigKeys({required this.contextCap});

  factory BuiltInServerConfigKeys.defaults() => BuiltInServerConfigKeys(
    contextCap: ConfigKey<int>(
      id: 'provider.local.context_cap',
      path: const ['provider', 'local', 'contextCap'],
      codec: ConfigCodecs.integers,
      defaultValue: () => 0,
      field: const NumericField(
        label: 'Context cap',
        description:
            'The most context a local model may run with. 0 = as much as '
            'fits in memory. Applies on reconnect.',
        min: 0,
        max: 2097152,
        step: 1024,
      ),
      effect: ConfigEffect.onCommit,
    ),
  );

  /// The most context a model may run with; 0 for as much as fits.
  final ConfigKey<int> contextCap;

  /// Keys the load options are built from.
  Iterable<ConfigKeyBase> get optionsKeys => [contextCap];
}
