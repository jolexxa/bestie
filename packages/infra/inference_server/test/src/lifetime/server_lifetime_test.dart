import 'package:fake_async/fake_async.dart';
import 'package:inference_server/inference_server.dart';
import 'package:test/test.dart';

const _grace = Duration(seconds: 30);

void main() {
  late ServerStopReason? stopped;

  ServerLifetime started() {
    stopped = null;
    final lifetime = ServerLifetime()..start();
    lifetime.ended.then((reason) => stopped = reason).ignore();
    return lifetime;
  }

  test('gives a fresh server thirty seconds by default', () {
    expect(ServerLifetime.defaultStartupGrace, _grace);
    expect(ServerLifetime().startupGrace, _grace);
  });

  group('awaiting the first connection', () {
    test('stops unclaimed once the grace runs out', () {
      fakeAsync((async) {
        final lifetime = started();

        async.elapse(_grace - const Duration(milliseconds: 1));
        expect(stopped, isNull);
        expect(lifetime.shuttingDown, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(stopped, ServerStopReason.unclaimed);
        expect(lifetime.shuttingDown, isTrue);
        lifetime.dispose();
      });
    });

    test('a first connection ends the grace', () {
      fakeAsync((async) {
        final lifetime = started()..opened();

        async.elapse(_grace * 2);

        expect(stopped, isNull);
        expect(async.pendingTimers, isEmpty);
        lifetime.dispose();
      });
    });

    test('stops when asked', () {
      fakeAsync((async) {
        final lifetime = started()..requestShutdown();
        async.flushMicrotasks();

        expect(stopped, ServerStopReason.requested);
        expect(lifetime.shuttingDown, isTrue);
        lifetime.dispose();
      });
    });
  });

  group('serving', () {
    test('stops the moment its last connection closes', () {
      fakeAsync((async) {
        final lifetime = started()
          ..opened()
          ..opened()
          ..closed();
        async.flushMicrotasks();
        expect(stopped, isNull);
        expect(lifetime.shuttingDown, isFalse);

        lifetime.closed();
        expect(lifetime.shuttingDown, isTrue);
        async.flushMicrotasks();

        expect(stopped, ServerStopReason.drained);
        lifetime.dispose();
      });
    });

    test('a connection opened before the last closes keeps it up', () {
      fakeAsync((async) {
        final lifetime = started()
          ..opened()
          ..opened()
          ..closed();
        async.elapse(const Duration(hours: 1));

        expect(stopped, isNull);
        expect(lifetime.shuttingDown, isFalse);
        lifetime.dispose();
      });
    });

    test('stops when asked with connections still open', () {
      fakeAsync((async) {
        final lifetime = started()
          ..opened()
          ..requestShutdown();
        async.flushMicrotasks();

        expect(stopped, ServerStopReason.requested);
        expect(lifetime.shuttingDown, isTrue);
        lifetime.dispose();
      });
    });
  });

  group('draining', () {
    test('connections opening or closing change nothing', () {
      fakeAsync((async) {
        final lifetime = started()
          ..opened()
          ..requestShutdown()
          ..closed()
          ..opened()
          ..requestShutdown();
        async.flushMicrotasks();

        expect(stopped, ServerStopReason.requested);
        expect(lifetime.shuttingDown, isTrue);
        lifetime.dispose();
      });
    });

    test('a reopen right after the last close is turned away', () {
      fakeAsync((async) {
        final lifetime = started()
          ..opened()
          ..closed();

        expect(lifetime.shuttingDown, isTrue);
        lifetime.dispose();
      });
    });
  });

  test('disposing cancels the grace', () {
    fakeAsync((async) {
      started().dispose();

      async.elapse(_grace);

      expect(stopped, isNull);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
