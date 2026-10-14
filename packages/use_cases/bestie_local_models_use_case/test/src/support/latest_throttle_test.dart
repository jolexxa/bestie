import 'package:bestie_local_models_use_case/src/support/latest_throttle.dart';
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

    test('waits out the interval before passing the latest value on', () {
      fakeAsync((async) {
        final emitted = <int>[];
        throttleIn(async, emitted)
          ..add(1)
          ..add(2);
        expect(async.pendingTimers.single.duration, interval);
        expect(emitted, [1]);
        async.elapse(interval);
        expect(emitted, [1, 2]);
      });
    });
  });
}
