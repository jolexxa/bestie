import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

CsiDispatchEvent _onlyCsi(Collector c) {
  expect(c.events, hasLength(1));
  expect(c.events.single, isA<CsiDispatchEvent>());
  return c.events.single as CsiDispatchEvent;
}

void main() {
  group('CSI', () {
    test('CSI H (cursor home) emits a single implicit zero', () {
      // The dispatch action unconditionally closes the current
      // parameter, so `CSI H` — which collected no digits — still
      // yields a single zero param. This matches alacritty/vte.
      final c = Collector();
      VtParser(sink: c).advance('\x1B[H'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.finalByte, 0x48);
      expect(e.params, [
        [0],
      ]);
      expect(e.intermediates, isEmpty);
      expect(e.ignore, isFalse);
    });

    test('CSI 5;10H (cursor position)', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[5;10H'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.finalByte, 0x48);
      expect(e.params, [
        [5],
        [10],
      ]);
    });

    test('CSI ?25h (show cursor) preserves `?` as intermediate/prefix', () {
      // `?` (0x3F) in the private-range byte slot before params.
      final c = Collector();
      VtParser(sink: c).advance('\x1B[?25h'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.finalByte, 0x68);
      expect(e.intermediates, [0x3F]);
      expect(e.params, [
        [25],
      ]);
    });

    test('CSI > 0c (secondary device attributes)', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[>0c'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.intermediates, [0x3E]);
      expect(e.finalByte, 0x63);
      expect(e.params, [
        [0],
      ]);
    });

    test('extended foreground color via `:` subparams', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[38:2:255:0:0m'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.finalByte, 0x6D);
      expect(e.params, [
        [38, 2, 255, 0, 0],
      ]);
    });

    test('CSI with space intermediate', () {
      // CSI 2 SP q — set cursor style to blinking block
      final c = Collector();
      VtParser(sink: c).advance('\x1B[2 q'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.params, [
        [2],
      ]);
      expect(e.intermediates, [0x20]);
      expect(e.finalByte, 0x71);
    });

    test('CSI with too many intermediates sets ignore', () {
      final c = Collector();
      // Three intermediates (space, !, ") — max is 2.
      VtParser(sink: c).advance('\x1B[ !"p'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.ignore, isTrue);
    });

    test('CSI with parameter beyond 16-bit saturates', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[999999m'.codeUnits);
      final e = _onlyCsi(c);
      expect(e.params.single.single, 0xFFFF);
    });

    test('C0 control inside CSI is executed and parsing continues', () {
      // CSI digits <BEL> m — vte dispatches BEL then CSI m with the
      // already-collected digits still in place.
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x5B, 0x31, 0x07, 0x6D]);
      expect(c.events, [
        const ExecuteEvent(0x07),
        const CsiDispatchEvent(
          params: [
            [1],
          ],
          intermediates: [],
          finalByte: 0x6D,
          ignore: false,
        ),
      ]);
    });

    test('CSI ignore state consumes to final byte then resets to ground', () {
      // 0x3C..0x3F after csiParam triggers csiIgnore. Feed
      // `CSI 1;<`, which jumps to csiIgnore, then drain bytes until
      // a 0x40..0x7E final.
      final c = Collector();
      VtParser(sink: c).advance(
        '\x1B[1;<garbagem'
                'HELLO'
            .codeUnits,
      );
      // The CSI sequence is dropped silently (no dispatch), and then
      // HELLO is printed.
      expect(c.events.whereType<CsiDispatchEvent>(), isEmpty);
      expect(
        c.events.whereType<PrintEvent>().map((e) => e.char),
        containsAllInOrder(
          'HELLO'.codeUnits,
        ),
      );
    });

    test('ESC inside CSI aborts and restarts', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[1;\x1B[2m'.codeUnits);
      final csi = c.events.whereType<CsiDispatchEvent>().single;
      expect(csi.params, [
        [2],
      ]);
    });
  });
}
