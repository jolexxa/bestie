import 'package:fake_async/fake_async.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:test/test.dart';

void main() {
  group('current', () {
    test('reports the reader value when a terminal is attached', () {
      const source = WindowsHostWinsizeSource(reader: _fixed);

      expect(source.current, (rows: 40, cols: 120));
    });

    test('falls back when no terminal is attached', () {
      const source = WindowsHostWinsizeSource(
        reader: _noTerminal,
        fallbackRows: 24,
        fallbackCols: 80,
      );

      expect(source.current, (rows: 24, cols: 80));
    });
  });

  group('changes', () {
    test('emits only when the polled size actually changes', () {
      fakeAsync((async) {
        var size = (rows: 24, cols: 80);
        final source = WindowsHostWinsizeSource(
          reader: () => size,
          pollInterval: const Duration(milliseconds: 100),
        );
        final seen = <Winsize>[];
        final subscription = source.changes.listen(seen.add);

        async.elapse(const Duration(milliseconds: 100));
        size = (rows: 30, cols: 100);
        async.elapse(const Duration(milliseconds: 100));
        // Two more polls with no change emit nothing.
        async.elapse(const Duration(milliseconds: 200));

        expect(seen, [(rows: 24, cols: 80), (rows: 30, cols: 100)]);
        subscription.cancel();
      });
    });

    test('ignores polls with no terminal', () {
      fakeAsync((async) {
        final source = WindowsHostWinsizeSource(
          reader: _noTerminal,
          pollInterval: const Duration(milliseconds: 100),
        );
        final seen = <Winsize>[];
        final subscription = source.changes.listen(seen.add);

        async.elapse(const Duration(milliseconds: 500));

        expect(seen, isEmpty);
        subscription.cancel();
      });
    });
  });
}

Winsize? _fixed() => (rows: 40, cols: 120);
Winsize? _noTerminal() => null;
