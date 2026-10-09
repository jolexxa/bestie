import 'dart:async';

import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';

/// Starts a one-shot timer; injectable so tests control time.
typedef StartTimer = Timer Function(Duration duration, void Function() fire);

/// Passes values through at most once per [interval]: the first value at
/// once, then the latest of any that arrive too soon at the end of the
/// interval, so the last value always lands.
@model
final class LatestThrottle<Value> {
  LatestThrottle({
    required this.interval,
    required this.emit,
    required Clock clock,
    required StartTimer startTimer,
  }) : _clock = clock,
       _startTimer = startTimer;

  final Duration interval;

  final void Function(Value value) emit;

  final Clock _clock;
  final StartTimer _startTimer;
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
    _timer = _startTimer(wait, _flush);
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

/// [source] passed through a [LatestThrottle] of its own for each listener.
Stream<Value> latestThrottled<Value>(
  Stream<Value> source, {
  required Duration interval,
  required Clock clock,
  required StartTimer startTimer,
}) => Stream<Value>.multi((controller) {
  final throttle = LatestThrottle<Value>(
    interval: interval,
    emit: controller.add,
    clock: clock,
    startTimer: startTimer,
  );
  final subscription = source.listen(
    throttle.add,
    onError: controller.addError,
    onDone: controller.close,
  );
  controller.onCancel = () {
    throttle.cancel();
    return subscription.cancel();
  };
});
