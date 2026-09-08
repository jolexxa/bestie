import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class ConfigLayer {
  ConfigLayer([Map<String, Object?>? tree]) : _tree = _copyMap(tree ?? {});

  final Map<String, Object?> _tree;

  Object? read(ConfigPath path) {
    if (path.isEmpty) return toMap();

    Object? current = _tree;
    for (final segment in path) {
      if (current is! Map<String, Object?>) return null;
      current = current[segment];
      if (current == null) return null;
    }
    return _copyValue(current);
  }

  void write(ConfigPath path, Object? value) {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path must not be empty.');
    }
    if (value == null) {
      _delete(path);
      return;
    }

    var current = _tree;
    for (final segment in path.take(path.length - 1)) {
      final next = current[segment];
      if (next is Map<String, Object?>) {
        current = next;
      } else {
        final child = <String, Object?>{};
        current[segment] = child;
        current = child;
      }
    }
    current[path.last] = _copyValue(value);
  }

  Map<String, Object?> toMap() => _copyMap(_tree);

  bool get isEmpty => _tree.isEmpty;

  void _delete(ConfigPath path) {
    final parents = <({Map<String, Object?> map, String segment})>[];
    var current = _tree;
    for (final segment in path.take(path.length - 1)) {
      final next = current[segment];
      if (next is! Map<String, Object?>) return;
      parents.add((map: current, segment: segment));
      current = next;
    }
    current.remove(path.last);

    for (final parent in parents.reversed) {
      final child = parent.map[parent.segment];
      if (child is Map<String, Object?> && child.isEmpty) {
        parent.map.remove(parent.segment);
      } else {
        break;
      }
    }
  }

  static Map<String, Object?> _copyMap(Map<String, Object?> source) => {
    for (final entry in source.entries)
      if (entry.value != null) entry.key: _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) => switch (value) {
    null => null,
    Map<String, Object?>() => _copyMap(value),
    Map() => _copyMap(value.cast<String, Object?>()),
    List() => [for (final item in value) _copyValue(item)],
    _ => value,
  };
}
