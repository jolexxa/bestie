import 'dart:async';

import 'package:bestie_config/bestie_config.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:config_repository/src/config_key_resolver.dart';
import 'package:intentions/intentions.dart';

@repository
class ConfigRepository implements ConfigView {
  ConfigRepository({required ConfigDataSource dataSource})
    : _dataSource = dataSource;

  final ConfigDataSource _dataSource;
  final ConfigEdits _liveEdits = {};
  Map<ConfigAddressBase, Object?> _scopeDefaults = const {};
  final _changeController = StreamController<ConfigChange>.broadcast();

  Stream<ConfigChange> get changes => _changeController.stream;

  @override
  Object? resolveBase(ConfigAddressBase address) => inspectBase(address).value;

  @override
  T resolve<T>(ConfigAddress<T> address) => inspect(address).value;

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) => _inspectBase(
    address,
  );

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) => _inspect(address);

  ConfigView view({ConfigEdits edits = const {}}) =>
      edits.isEmpty ? this : _ConfigRepositoryReadView(this, edits);

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _readExplicitBase(address) != null;

  @override
  bool isExplicit<T>(ConfigAddress<T> address) => isExplicitBase(address);

  @override
  bool definesBase(ConfigAddressBase address) =>
      _readExactBase(address) != null;

  @override
  bool defines<T>(ConfigAddress<T> address) => definesBase(address);

  /// Replaces the values that stand in wherever the user has set nothing.
  void applyScopeDefaults(Map<ConfigAddressBase, Object?> defaults) {
    final touched = {..._scopeDefaults.keys, ...defaults.keys};
    final before = _snapshots(touched);
    _scopeDefaults = Map.unmodifiable(defaults);
    _emitChanged(before);
  }

  void applyLive(ConfigEdits edits) {
    if (edits.isEmpty) return;
    final before = _snapshots(edits.keys);
    _liveEdits.addAll(edits);
    _emitChanged(before);
  }

  void commit(ConfigEdits edits) {
    if (edits.isEmpty) return;
    final before = _snapshots(edits.keys);
    for (final entry in edits.entries) {
      _applyPersistedEdit(entry.key, entry.value);
      _liveEdits.remove(entry.key);
    }
    _dataSource.persist();
    _emitChanged(before);
  }

  /// The value at [address] now and after every change to it, told once per
  /// value.
  ///
  /// Deliberately not a generator: canceling one waits on it winding down, a
  /// wait a fake clock or a disposed repository never ends.
  Stream<T> watch<T>(ConfigAddress<T> address) => Stream<T>.multi((listener) {
    var last = inspect(address).value;
    listener.add(last);
    final sub = changes.listen(
      (_) {
        final next = inspect(address).value;
        if (next == last) return;
        last = next;
        listener.add(next);
      },
      onDone: listener.close,
    );
    listener.onCancel = sub.cancel;
  });

  Future<void> dispose() => _changeController.close();

  Resolved<T> _inspect<T>(
    ConfigAddress<T> address, {
    ConfigEdits edits = const {},
  }) {
    final resolved = _inspectBase(address, edits: edits);
    return Resolved<T>(
      value: resolved.value as T,
      source: resolved.source,
    );
  }

  Resolved<Object?> _inspectBase(
    ConfigAddressBase address, {
    ConfigEdits edits = const {},
  }) {
    for (final candidate in address.key.resolution.chainBase(address)) {
      final read = _readExactBase(candidate, edits: edits);
      if (read != null) return read;
    }
    return Resolved<Object?>(
      value: address.key.defaultObjectValue(),
      source: null,
    );
  }

  Resolved<Object?>? _readExactBase(
    ConfigAddressBase address, {
    ConfigEdits edits = const {},
  }) {
    final explicit = _readExplicitBase(address, edits: edits);
    if (explicit != null) return explicit;
    return _readScopeDefaultBase(address);
  }

  Resolved<Object?>? _readExplicitBase(
    ConfigAddressBase address, {
    ConfigEdits edits = const {},
  }) {
    final draft = edits[address];
    if (draft != null) {
      return _readEditBase(address, draft);
    }

    final live = _liveEdits[address];
    if (live != null) {
      return _readEditBase(address, live);
    }

    return _decodeBase(address, _dataSource.user.read(address.path));
  }

  Resolved<Object?>? _readEditBase(
    ConfigAddressBase address,
    ConfigEditBase edit,
  ) {
    if (edit is SetConfigValue) {
      return Resolved<Object?>(value: edit.value, source: address);
    }
    return null;
  }

  Resolved<Object?>? _readScopeDefaultBase(ConfigAddressBase address) {
    final value = _scopeDefaults[address];
    if (value == null) return null;
    return Resolved<Object?>(value: value, source: address);
  }

  Resolved<Object?>? _decodeBase(ConfigAddressBase address, Object? raw) {
    if (raw == null) return null;
    final decoded = address.key.decode(raw);
    if (decoded == null) return null;
    return Resolved<Object?>(value: decoded, source: address);
  }

  void _applyPersistedEdit(ConfigAddressBase address, ConfigEditBase edit) {
    switch (edit) {
      case SetConfigValue(:final value):
        final encoded = address.key.encode(value);
        if (encoded == null) {
          throw ArgumentError.value(
            value,
            'value',
            'Encoded config values must be non-null. Use ConfigEdit.clear().',
          );
        }
        _dataSource.user.write(address.path, encoded);
      case ClearConfigValue():
        _dataSource.user.write(address.path, null);
    }
  }

  Map<ConfigAddressBase, Object> _snapshots(
    Iterable<ConfigAddressBase> addresses,
  ) => {
    for (final address in addresses) address: _snapshot(inspectBase(address)),
  };

  Object _snapshot(Resolved<Object?> resolved) => (
    value: resolved.value,
    source: resolved.source == null
        ? null
        : (key: resolved.source!.key.id, scope: resolved.source!.scope.path),
  );

  void _emitChanged(Map<ConfigAddressBase, Object> before) {
    final changed = <ConfigAddressBase>[];
    for (final address in before.keys) {
      if (before[address] != _snapshot(inspectBase(address))) {
        changed.add(address);
      }
    }
    if (changed.isNotEmpty) _changeController.add(ConfigChange(changed));
  }
}

final class _ConfigRepositoryReadView implements ConfigView {
  _ConfigRepositoryReadView(ConfigRepository repo, ConfigEdits edits)
    : _repo = repo,
      _edits = Map.unmodifiable(edits);

  final ConfigRepository _repo;
  final ConfigEdits _edits;

  @override
  Object? resolveBase(ConfigAddressBase address) => inspectBase(address).value;

  @override
  T resolve<T>(ConfigAddress<T> address) => inspect(address).value;

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) =>
      _repo._inspectBase(address, edits: _edits);

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) =>
      _repo._inspect(address, edits: _edits);

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _repo._readExplicitBase(address, edits: _edits) != null;

  @override
  bool isExplicit<T>(ConfigAddress<T> address) => isExplicitBase(address);

  @override
  bool definesBase(ConfigAddressBase address) =>
      _repo._readExactBase(address, edits: _edits) != null;

  @override
  bool defines<T>(ConfigAddress<T> address) => definesBase(address);
}
