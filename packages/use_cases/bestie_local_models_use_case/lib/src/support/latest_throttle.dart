import 'dart:async';

import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';

/// Passes values through at most once per [interval]: the first value at
/// once, then the latest of any that arrive too soon at the end of the
/// interval, so the last value always lands.
@model
final class LatestThrottle<Value> {
  LatestThrottle({
    required this.interval,
    required this.emit,
    required Clock clock,
  }) : _clock = clock;

  final Duration interval;

  final void Function(Value value) emit;

  final Clock _clock;
  DateTime? _lastEmitted;
  Timer? _timer;
  Value? _pending;

  void add(Value value) {
    _pending = value;
    if (_timer != null) return;
    final wait = switch (_lastEmitted) {
      null => Duration.zero,
      final last => interval - _clock.now().difference(last),
    };
    if (wait <= Duration.zero) return _flush();
    _timer = Timer(wait, _flush);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _flush() {
    _timer = null;
    _lastEmitted = _clock.now();
    emit(_pending as Value);
  }
}
