import 'dart:async';

import 'package:config_protocol/config_protocol.dart';
import 'package:config_repository/src/config_key_resolver.dart';
import 'package:config_repository/src/config_repository.dart';
import 'package:meta/meta.dart';

/// A [ConfigRepository] backed by a plain map, for testing the consumers that
/// resolve and subscribe to configuration. Values are kept per address and
/// read the way the real repository reads them: along the key's resolution
/// chain, then a scope default, then the key's own default.
final class FakeConfigRepository implements ConfigRepository {
  FakeConfigRepository([Map<String, Object?> values = const {}])
    : _values = {
        for (final entry in values.entries)
          _Slot.global(entry.key): entry.value,
      };

  final Map<_Slot, Object?> _values;
  final Map<_Slot, Object?> _scopeDefaults = {};
  final _changes = StreamController<ConfigChange>.broadcast();

  @override
  Stream<ConfigChange> get changes => _changes.stream;

  /// The value set for [keyId] at the global scope, or null when it falls
  /// through to the key's own default.
  Object? operator [](String keyId) => _values[_Slot.global(keyId)];

  /// Sets [keyId] to [value] at the global scope and announces it, the way a
  /// commit would, so a subscriber re-resolves.
  void operator []=(String keyId, Object? value) {
    _values[_Slot.global(keyId)] = value;
    announce({keyId});
  }

  /// Sets several global values and announces them as one change.
  void setAll(Map<String, Object?> values) {
    for (final entry in values.entries) {
      _values[_Slot.global(entry.key)] = entry.value;
    }
    announce(values.keys.toSet());
  }

  /// Announces [keyIds] as changed without altering any value.
  void announce(Set<String> keyIds) =>
      _announce(ConfigChange.ids(keyIds: keyIds));

  /// Sets [value] at [address], whatever its scope, and announces it.
  void set(ConfigAddressBase address, Object? value) => seed({address: value});

  /// Sets several values at their addresses and announces them as one change.
  void seed(Map<ConfigAddressBase, Object?> values) {
    for (final entry in values.entries) {
      _values[_Slot.of(entry.key)] = entry.value;
    }
    _announce(ConfigChange(values.keys));
  }

  @override
  void applyScopeDefaults(Map<ConfigAddressBase, Object?> defaults) {
    _scopeDefaults
      ..clear()
      ..addEntries(
        defaults.entries.map(
          (entry) => MapEntry(_Slot.of(entry.key), entry.value),
        ),
      );
    _announce(ConfigChange(defaults.keys));
  }

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) {
    for (final candidate in address.key.resolution.chainBase(address)) {
      final read = _read(candidate);
      if (read != null) return read;
    }
    return Resolved<Object?>(
      value: address.key.defaultObjectValue(),
      source: null,
    );
  }

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) {
    final resolved = inspectBase(address);
    return Resolved<T>(value: resolved.value as T, source: resolved.source);
  }

  Resolved<Object?>? _read(ConfigAddressBase address) {
    final slot = _Slot.of(address);
    if (_values.containsKey(slot)) {
      return Resolved<Object?>(value: _values[slot], source: address);
    }
    if (_scopeDefaults.containsKey(slot)) {
      return Resolved<Object?>(value: _scopeDefaults[slot], source: address);
    }
    return null;
  }

  @override
  Object? resolveBase(ConfigAddressBase address) => inspectBase(address).value;

  @override
  T resolve<T>(ConfigAddress<T> address) => inspect(address).value;

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _values.containsKey(_Slot.of(address));

  @override
  bool isExplicit<T>(ConfigAddress<T> address) => isExplicitBase(address);

  @override
  bool definesBase(ConfigAddressBase address) =>
      isExplicitBase(address) || _scopeDefaults.containsKey(_Slot.of(address));

  @override
  bool defines<T>(ConfigAddress<T> address) => definesBase(address);

  @override
  ConfigView view({ConfigEdits edits = const {}}) => this;

  @override
  void applyLive(ConfigEdits edits) => _applyEdits(edits);

  @override
  void commit(ConfigEdits edits) => _applyEdits(edits);

  @override
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

  @override
  Future<void> dispose() => _changes.close();

  void _applyEdits(ConfigEdits edits) {
    if (edits.isEmpty) return;
    for (final entry in edits.entries) {
      final slot = _Slot.of(entry.key);
      if (entry.value case SetConfigValue(:final value)) {
        _values[slot] = value;
      } else {
        _values.remove(slot);
      }
    }
    _announce(ConfigChange(edits.keys));
  }

  void _announce(ConfigChange change) {
    if (_changes.isClosed) return;
    _changes.add(change);
  }
}

/// One stored value: a key at a scope, compared by value so that addresses
/// built from different key instances still meet.
@immutable
final class _Slot {
  _Slot.of(ConfigAddressBase address)
    : keyId = address.key.id,
      scope = address.scope;

  _Slot.global(this.keyId) : scope = ConfigScope.global;

  final String keyId;
  final ConfigScope scope;

  @override
  bool operator ==(Object other) =>
      other is _Slot && other.keyId == keyId && other.scope == scope;

  @override
  int get hashCode => Object.hash(keyId, scope);
}
