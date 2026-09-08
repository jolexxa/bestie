import 'package:config_protocol/src/config_codec.dart';
import 'package:config_protocol/src/config_effect.dart';
import 'package:config_protocol/src/config_path.dart';
import 'package:meta/meta.dart';

abstract interface class ConfigKeyBase {
  String get id;
  ConfigPath get path;
  ConfigEffect get effect;
  ConfigResolutionBase get resolution;

  Object? defaultObjectValue();
  Object? decode(Object? raw);
  Object? encode(Object? value);
  ConfigAddressBase atScope(ConfigScope scope);
}

final class ConfigKey<T> implements ConfigKeyBase {
  const ConfigKey({
    required this.id,
    required this.path,
    required this.codec,
    required this.defaultValue,
    this.effect = ConfigEffect.live,
    this.resolution = const ConfigResolution.exact(),
  });

  @override
  final String id;
  @override
  final ConfigPath path;
  final ConfigCodec<T> codec;
  final T Function() defaultValue;
  @override
  final ConfigEffect effect;
  @override
  final ConfigResolution<T> resolution;

  ConfigAddress<T> at(ConfigScope scope) => ConfigAddress<T>(
    key: this,
    scope: scope,
  );

  ConfigAddress<T> get global => at(ConfigScope.global);

  @override
  Object? defaultObjectValue() => defaultValue();

  @override
  Object? decode(Object? raw) => codec.decode(raw);

  @override
  Object? encode(Object? value) => codec.encode(value as T);

  @override
  ConfigAddressBase atScope(ConfigScope scope) => at(scope);
}

@immutable
final class ConfigScope {
  ConfigScope._(Iterable<String> path, {this.parent})
    : path = List.unmodifiable(path);

  factory ConfigScope.path(Iterable<String> path, {ConfigScope? parent}) {
    final segments = List<String>.unmodifiable(path);
    if (segments.isEmpty) return global;
    return ConfigScope._(segments, parent: parent ?? global);
  }

  static final global = ConfigScope._(const []);

  final ConfigPath path;
  final ConfigScope? parent;

  Iterable<ConfigScope> get ancestry sync* {
    ConfigScope? current = this;
    while (current != null) {
      yield current;
      current = current.parent;
    }
  }

  ConfigScope child(ConfigScope child) {
    if (child.path.isEmpty) return this;
    if (path.isEmpty) return child;
    return ConfigScope._([...path, ...child.path], parent: this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfigScope) return false;
    if (path.length != other.path.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (path[i] != other.path[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(path);
}

@immutable
abstract interface class ConfigAddressBase {
  ConfigKeyBase get key;
  ConfigScope get scope;
  ConfigPath get path;
}

@immutable
final class ConfigAddress<T> implements ConfigAddressBase {
  const ConfigAddress({required this.key, required this.scope});

  @override
  final ConfigKey<T> key;
  @override
  final ConfigScope scope;

  @override
  ConfigPath get path => [...scope.path, ...key.path];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigAddressBase &&
          other.key.id == key.id &&
          other.scope == scope;

  @override
  int get hashCode => Object.hash(key.id, scope);
}

abstract interface class ConfigResolutionBase {
  bool get includeScopeAncestry;

  Iterable<ConfigAddressBase> chainBase(ConfigAddressBase address);
}

final class ConfigResolution<T> implements ConfigResolutionBase {
  const ConfigResolution({
    required this.includeScopeAncestry,
    this.fallbackKeys = const [],
  });

  const ConfigResolution.exact()
    : includeScopeAncestry = false,
      fallbackKeys = const [];

  const ConfigResolution.scoped({
    this.fallbackKeys = const [],
  }) : includeScopeAncestry = true;

  @override
  final bool includeScopeAncestry;
  final List<ConfigKey<T>> fallbackKeys;

  Iterable<ConfigAddress<T>> chain(ConfigAddress<T> address) sync* {
    final scopes = includeScopeAncestry
        ? address.scope.ancestry
        : [address.scope];
    for (final scope in scopes) {
      yield address.key.at(scope);
      for (final key in fallbackKeys) {
        yield key.at(scope);
      }
    }
  }

  @override
  Iterable<ConfigAddressBase> chainBase(ConfigAddressBase address) sync* {
    final scopes = includeScopeAncestry
        ? address.scope.ancestry
        : [address.scope];
    for (final scope in scopes) {
      yield address.key.atScope(scope);
      for (final key in fallbackKeys) {
        yield key.at(scope);
      }
    }
  }
}

sealed class ConfigEditBase {
  const ConfigEditBase();

  const factory ConfigEditBase.set(Object? value) = SetConfigValue<Object?>;

  const factory ConfigEditBase.clear() = ClearConfigValue<Object?>;
}

sealed class ConfigEdit<T> extends ConfigEditBase {
  const ConfigEdit();

  const factory ConfigEdit.set(T value) = SetConfigValue<T>;

  const factory ConfigEdit.clear() = ClearConfigValue<T>;
}

final class SetConfigValue<T> extends ConfigEdit<T> {
  const SetConfigValue(this.value);

  final T value;
}

final class ClearConfigValue<T> extends ConfigEdit<T> {
  const ClearConfigValue();
}

typedef ConfigEdits = Map<ConfigAddressBase, ConfigEditBase>;
