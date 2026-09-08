import 'package:meta/meta.dart';

/// Typed handle for one collected parameter value.
@immutable
final class ParamKey<T> {
  const ParamKey(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is ParamKey && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
