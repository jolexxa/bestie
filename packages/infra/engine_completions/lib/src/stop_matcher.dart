import 'dart:math' as math;

/// Watches generated text for stop sequences. Text that could still be the
/// start of a stop is held back until the next text settles it, so a stop
/// split across tokens never leaks out.
final class StopMatcher {
  StopMatcher(Iterable<String> stops)
    : _stops = {
        for (final stop in stops)
          if (stop.isNotEmpty) stop,
      }.toList();

  final List<String> _stops;
  var _held = '';

  late final int _longestHold = _stops.fold(
    0,
    (longest, stop) => math.max(longest, stop.length - 1),
  );

  /// Feeds the next [text], answering with the text that is now safe to
  /// release.
  StopScan add(String text) {
    final buffered = '$_held$text';
    final stopAt = _firstStopIn(buffered);
    if (stopAt != null) {
      _held = '';
      return StopMatched(buffered.substring(0, stopAt));
    }
    final release = buffered.length - _heldLengthOf(buffered);
    _held = buffered.substring(release);
    return StopUnmatched(buffered.substring(0, release));
  }

  /// Releases whatever is held, once no more text is coming.
  String flush() {
    final held = _held;
    _held = '';
    return held;
  }

  int? _firstStopIn(String text) => _stops
      .map(text.indexOf)
      .where((index) => index >= 0)
      .fold<int?>(
        null,
        (first, index) => first == null ? index : math.min(first, index),
      );

  /// The longest tail of [text] that begins some stop.
  int _heldLengthOf(String text) {
    for (
      var length = math.min(_longestHold, text.length);
      length > 0;
      length--
    ) {
      final tail = text.substring(text.length - length);
      if (_stops.any((stop) => stop.startsWith(tail))) return length;
    }
    return 0;
  }
}

/// What a stop matcher made of the text it was fed.
sealed class StopScan {
  const StopScan(this.released);

  /// The text before any stop, safe to pass on.
  final String released;
}

/// No stop appeared; [released] is everything that cannot start one.
final class StopUnmatched extends StopScan {
  const StopUnmatched(super.released);
}

/// A stop appeared; [released] is the text before it, and nothing after it
/// counts.
final class StopMatched extends StopScan {
  const StopMatched(super.released);
}
