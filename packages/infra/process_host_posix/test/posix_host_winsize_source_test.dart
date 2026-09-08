@TestOn('vm')
library;

import 'dart:async';

import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:test/test.dart';

void main() {
  group('PosixHostWinsizeSource.current', () {
    test('reports the reader value', () {
      const source = PosixHostWinsizeSource(
        reader: _fixedReader,
        watcher: _emptyWatcher,
      );
      expect(source.current, (rows: 42, cols: 120));
    });

    test('falls back to 24x80 when no terminal is attached', () {
      const source = PosixHostWinsizeSource(
        reader: _nullReader,
        watcher: _emptyWatcher,
      );
      expect(source.current, (rows: 24, cols: 80));
    });
  });

  group('PosixHostWinsizeSource.changes', () {
    test('emits a winsize on each SIGWINCH tick', () async {
      final ticker = StreamController<void>();
      final frames = <Winsize>[
        (rows: 10, cols: 20),
        (rows: 11, cols: 21),
      ];
      var frame = 0;

      final source = PosixHostWinsizeSource(
        reader: () => frames[frame++],
        watcher: () => ticker.stream,
      );
      final events = <Winsize>[];
      final sub = source.changes.listen(events.add);

      ticker
        ..add(null)
        ..add(null);
      await Future<void>.delayed(Duration.zero);

      expect(events, frames);

      await sub.cancel();
      await ticker.close();
    });

    test('skips ticks where the host has no terminal', () async {
      final ticker = StreamController<void>();
      final responses = <Winsize?>[
        (rows: 24, cols: 80),
        null,
        (rows: 30, cols: 100),
      ];
      var i = 0;

      final source = PosixHostWinsizeSource(
        reader: () => responses[i++],
        watcher: () => ticker.stream,
      );
      final events = <Winsize>[];
      final sub = source.changes.listen(events.add);

      ticker
        ..add(null)
        ..add(null)
        ..add(null);
      await Future<void>.delayed(Duration.zero);

      expect(events, const [
        (rows: 24, cols: 80),
        (rows: 30, cols: 100),
      ]);

      await sub.cancel();
      await ticker.close();
    });
  });

  group('defaultSigwinchWatcher', () {
    test(
      'returns a stream of signal ticks',
      () {
        expect(defaultSigwinchWatcher(), isA<Stream<void>>());
      },
      testOn: '!windows',
    );
  });
}

Winsize? _fixedReader() => (rows: 42, cols: 120);

Winsize? _nullReader() => null;

Stream<void> _emptyWatcher() => const Stream<void>.empty();
