import 'dart:async';

import 'package:bestie_local_models_use_case/src/support/latest_throttle.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  group('LatestThrottle', () {
    const interval = Duration(milliseconds: 250);

    LatestThrottle<int> throttleIn(FakeAsync async, List<int> emitted) =>
        LatestThrottle(
          interval: interval,
          emit: emitted.add,
          clock: async.getClock(DateTime(2026)),
          startTimer: Timer.new,
        );

    test('passes the first value through at once', () {
      fakeAsync((async) {
        final emitted = <int>[];
        throttleIn(async, emitted).add(1);
        expect(emitted, [1]);
      });
    });

    test('holds values that arrive too soon and lands the latest', () {
      fakeAsync((async) {
        final emitted = <int>[];
        final throttle = throttleIn(async, emitted)..add(1);
        async.elapse(const Duration(milliseconds: 50));
        throttle
          ..add(2)
          ..add(3);
        expect(emitted, [1]);
        async.elapse(const Duration(milliseconds: 199));
        expect(emitted, [1]);
        async.elapse(const Duration(milliseconds: 1));
        expect(emitted, [1, 3]);
      });
    });

    test('emits at most once per interval under a steady stream', () {
      fakeAsync((async) {
        final emitted = <int>[];
        final throttle = throttleIn(async, emitted);
        for (var tick = 0; tick < 100; tick++) {
          throttle.add(tick);
          async.elapse(const Duration(milliseconds: 10));
        }
        async.flushTimers();
        expect(emitted.length, lessThanOrEqualTo(5));
        expect(emitted.last, 99);
      });
    });

    test('passes a value straight through once an interval has passed', () {
      fakeAsync((async) {
        final emitted = <int>[];
        final throttle = throttleIn(async, emitted)..add(1);
        async.elapse(interval);
        throttle.add(2);
        expect(emitted, [1, 2]);
      });
    });

    test('drops the held value when cancelled', () {
      fakeAsync((async) {
        final emitted = <int>[];
        throttleIn(async, emitted)
          ..add(1)
          ..add(2)
          ..cancel();
        async.flushTimers();
        expect(emitted, [1]);
      });
    });

    test('uses the injected clock and timer', () {
      final clock = Clock.fixed(DateTime(2026));
      final waits = <Duration>[];
      final emitted = <int>[];
      LatestThrottle<int>(
          interval: interval,
          emit: emitted.add,
          clock: clock,
          startTimer: (duration, fire) {
            waits.add(duration);
            return Timer(Duration.zero, () {});
          },
        )
        ..add(1)
        ..add(2);
      expect(waits, [interval]);
      expect(emitted, [1]);
    });
  });

  group('latestThrottled', () {
    const interval = Duration(milliseconds: 250);

    Stream<int> throttledIn(FakeAsync async, Stream<int> source) =>
        latestThrottled(
          source,
          interval: interval,
          clock: async.getClock(DateTime(2026)),
          startTimer: Timer.new,
        );

    test('throttles each listener on its own and lands the latest', () {
      fakeAsync((async) {
        final source = StreamController<int>.broadcast();
        final first = <int>[];
        final second = <int>[];
        final stream = throttledIn(async, source.stream)..listen(first.add);
        source.add(1);
        async.flushMicrotasks();
        stream.listen(second.add);
        source
          ..add(2)
          ..add(3);
        async.flushMicrotasks();
        expect(first, [1]);
        expect(second, [2]);
        async.elapse(interval);
        expect(first, [1, 3]);
        expect(second, [2, 3]);
      });
    });

    test('passes errors and the end of the source on', () async {
      final source = StreamController<int>();
      final errors = <Object>[];
      final done = Completer<void>();
      latestThrottled(
        source.stream,
        interval: interval,
        clock: const Clock(),
        startTimer: Timer.new,
      ).listen(null, onError: errors.add, onDone: done.complete);
      source.addError('broken');
      await source.close();
      await done.future;
      expect(errors, ['broken']);
    });

    test('lets go of the source and drops the held value on cancel', () {
      fakeAsync((async) {
        final source = StreamController<int>.broadcast();
        final emitted = <int>[];
        final subscription = throttledIn(
          async,
          source.stream,
        ).listen(emitted.add);
        source
          ..add(1)
          ..add(2);
        async.flushMicrotasks();
        unawaited(subscription.cancel());
        async.flushMicrotasks();
        expect(source.hasListener, isFalse);
        async.flushTimers();
        expect(emitted, [1]);
      });
    });
  });
}
