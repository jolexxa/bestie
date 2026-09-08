import 'dart:async';

import 'package:terminal_screen/src/snapshot.dart';

/// A single pending `waitFor` request. Created by `Screen.waitFor`
/// (and the convenience helpers), fulfilled from
/// `_afterMutation()` when its predicate matches, or completed
/// with a [TimeoutException] when its timer fires.
class Waiter {
  /// Create and immediately arm a waiter. The [timeout] timer
  /// starts running as soon as this constructor returns.
  Waiter({
    required this.predicate,
    required Duration timeout,
    required void Function(Waiter) onRemove,
  }) : completer = Completer<ScreenSnapshot>() {
    _timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('waitFor predicate did not match', timeout),
        );
        onRemove(this);
      }
    });
  }

  /// The user-supplied predicate evaluated against each snapshot
  /// after a mutation.
  final bool Function(ScreenSnapshot) predicate;

  /// The completer the user is awaiting.
  final Completer<ScreenSnapshot> completer;

  late final Timer _timer;

  /// Complete with [snapshot] if the predicate holds. Returns
  /// `true` if the waiter was fulfilled (and should be removed
  /// from the screen's waiter list).
  bool tryComplete(ScreenSnapshot snapshot) {
    if (completer.isCompleted) return true;
    if (predicate(snapshot)) {
      _timer.cancel();
      completer.complete(snapshot);
      return true;
    }
    return false;
  }
}
