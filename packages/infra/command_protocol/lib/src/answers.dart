import 'package:command_protocol/src/param_key.dart';
import 'package:meta/meta.dart';

/// Immutable, ordered bag of collected parameter values threaded through a
/// command's flow.
@immutable
final class Answers {
  const Answers.empty() : _entries = const [];

  const Answers._(this._entries);

  final List<_Answer> _entries;

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  /// A new [Answers] with [value] recorded under [key].
  Answers put<T>(ParamKey<T> key, T value) => Answers._(
    List.unmodifiable([
      ..._entries.where((entry) => entry.key != key),
      _Answer(key, value),
    ]),
  );

  /// A new [Answers] without the most recent answer; empty stays empty.
  Answers pop() => _entries.isEmpty
      ? this
      : Answers._(List.unmodifiable(_entries.take(_entries.length - 1)));

  /// The value recorded under [key], or null when unanswered.
  T? maybe<T>(ParamKey<T> key) {
    for (final entry in _entries) {
      if (entry.key == key) return entry.value as T;
    }
    return null;
  }

  /// The value recorded under [key]. Reading an unanswered key is a
  /// programming error in the command's flow.
  T get<T>(ParamKey<T> key) {
    final value = maybe(key);
    if (value == null) {
      throw ArgumentError.value(key.id, 'key', 'has not been answered');
    }
    return value;
  }
}

final class _Answer {
  const _Answer(this.key, this.value);

  final ParamKey<Object?> key;
  final Object? value;
}
