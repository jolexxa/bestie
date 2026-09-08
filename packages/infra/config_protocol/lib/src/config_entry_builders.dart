import 'package:config_protocol/src/config_entry.dart';
import 'package:config_protocol/src/config_field.dart';
import 'package:config_protocol/src/config_key.dart';

ConfigScope globalConfigScope({required ConfigScope? targetScope}) =>
    ConfigScope.global;

ConfigScope? targetConfigScope({required ConfigScope? targetScope}) =>
    targetScope;

ConfigEntry globalEntry<T>({
  required ConfigKey<T> key,
  required ConfigField<T> field,
}) => ConfigEntry.typed<T>(
  key: key,
  field: field,
  resolver: globalConfigScope,
);

ConfigEntry scopedEntry<T>({
  required ConfigKey<T> key,
  required ConfigField<T> field,
  ConfigSourceLabel<T>? sourceLabel,
}) => ConfigEntry.typed<T>(
  key: key,
  field: field,
  resolver: targetConfigScope,
  sourceLabel: sourceLabel,
);

ConfigSourceLabel<T> sourceLabelFor<T>({
  required ConfigKey<T> key,
  required String label,
}) => ConfigSourceLabel<T>(key: key, label: label);
