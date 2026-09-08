import 'dart:async';

import 'package:config_protocol/config_protocol.dart';
import 'package:config_repository/src/config_key_resolver.dart';
import 'package:config_repository/src/config_repository.dart';

/// A [ConfigRepository] backed by a plain map of key id to value, for testing
/// the consumers that resolve and subscribe to configuration. A key with no
/// entry resolves to its declared default.
final class FakeConfigRepository implements ConfigRepository {
  FakeConfigRepository([Map<String, Object?> values = const {}])
    : _values = {...values};

  final Map<String, Object?> _values;
  final Map<String, Object?> _scopeDefaults = {};
  final _changes = StreamController<ConfigChange>.broadcast();

  @override
  Stream<ConfigChange> get changes => _changes.stream;

  /// The current value for [keyId], or null when it falls through to the
  /// key's own default.
  Object? operator [](String keyId) => _values[keyId];

  /// Sets [keyId] to [value] and announces it, the way a commit would, so a
  /// subscriber re-resolves.
  void operator []=(String keyId, Object? value) {
    _values[keyId] = value;
    announce({keyId});
  }

  /// Sets several values and announces them as one change.
  void setAll(Map<String, Object?> values) {
    _values.addAll(values);
    announce(values.keys.toSet());
  }

  /// Announces [keyIds] as changed without altering any value.
  void announce(Set<String> keyIds) {
    if (_changes.isClosed) return;
    _changes.add(ConfigChange.ids(keyIds: keyIds));
  }

  /// Scope defaults, flattened to key ids the same way user values are.
  @override
  void applyScopeDefaults(Map<ConfigAddressBase, Object?> defaults) {
    _scopeDefaults
      ..clear()
      ..addEntries(
        defaults.entries.map(
          (entry) => MapEntry(entry.key.key.id, entry.value),
        ),
      );
    announce({for (final address in defaults.keys) address.key.id});
  }

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) => Resolved<Object?>(
    value: _resolved(address.key),
    source: address,
  );

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) => Resolved<T>(
    value: _resolved(address.key) as T,
    source: address,
  );

  Object? _resolved(ConfigKeyBase key) {
    if (_values.containsKey(key.id)) return _values[key.id];
    if (_scopeDefaults.containsKey(key.id)) return _scopeDefaults[key.id];
    return key.defaultObjectValue();
  }

  @override
  Object? resolveBase(ConfigAddressBase address) => inspectBase(address).value;

  @override
  T resolve<T>(ConfigAddress<T> address) => inspect(address).value;

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _values.containsKey(address.key.id);

  @override
  bool isExplicit<T>(ConfigAddress<T> address) => isExplicitBase(address);

  @override
  bool definesBase(ConfigAddressBase address) =>
      isExplicitBase(address) || _scopeDefaults.containsKey(address.key.id);

  @override
  bool defines<T>(ConfigAddress<T> address) => definesBase(address);

  @override
  ConfigView view({ConfigEdits edits = const {}}) => this;

  @override
  void applyLive(ConfigEdits edits) => _announceEdits(edits);

  @override
  void commit(ConfigEdits edits) => _announceEdits(edits);

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

  void _announceEdits(ConfigEdits edits) {
    if (edits.isEmpty) return;
    for (final entry in edits.entries) {
      if (entry.value case SetConfigValue(:final value)) {
        _values[entry.key.key.id] = value;
      } else {
        _values.remove(entry.key.key.id);
      }
    }
    announce({for (final address in edits.keys) address.key.id});
  }
}
