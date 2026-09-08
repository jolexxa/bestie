import 'package:config_protocol/src/config_field.dart';
import 'package:config_protocol/src/config_key.dart';

typedef ConfigEntryScopeResolver =
    ConfigScope? Function({
      required ConfigScope? targetScope,
    });

sealed class ConfigEntry {
  const ConfigEntry();

  static ConfigEntry typed<T>({
    required ConfigKey<T> key,
    required ConfigField<T> field,
    required ConfigEntryScopeResolver resolver,
    ConfigSourceLabel<T>? sourceLabel,
  }) => _TypedConfigEntry<T>(
    key: key,
    field: field,
    resolver: resolver,
    sourceLabel: sourceLabel,
  );

  ConfigKeyBase get key;
  ConfigFieldBase get field;
  ConfigEntryScopeResolver get resolver;
  ConfigSourceLabelBase? get sourceLabel;

  ConfigAddressBase? addressFor({required ConfigScope? targetScope});
}

final class _TypedConfigEntry<T> extends ConfigEntry {
  const _TypedConfigEntry({
    required this.key,
    required this.field,
    required this.resolver,
    this.sourceLabel,
  });

  @override
  final ConfigKey<T> key;

  @override
  final ConfigField<T> field;

  @override
  final ConfigEntryScopeResolver resolver;

  @override
  final ConfigSourceLabel<T>? sourceLabel;

  @override
  ConfigAddress<T>? addressFor({required ConfigScope? targetScope}) {
    final resolvedScope = resolver(targetScope: targetScope);
    if (resolvedScope == null) return null;
    return key.at(resolvedScope);
  }
}

abstract interface class ConfigSourceLabelBase {
  ConfigKeyBase get key;
  String get label;
}

final class ConfigSourceLabel<T> implements ConfigSourceLabelBase {
  const ConfigSourceLabel({
    required this.key,
    required this.label,
  });

  @override
  final ConfigKey<T> key;
  @override
  final String label;
}
