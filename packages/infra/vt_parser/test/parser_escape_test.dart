import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

void main() {
  group('ESC dispatch', () {
    test('ESC 7 (save cursor)', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x37]);
      expect(c.events, [
        const EscDispatchEvent(
          intermediates: [],
          finalByte: 0x37,
          ignore: false,
        ),
      ]);
    });

    test('ESC 8 (restore cursor)', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x38]);
      expect((c.events.single as EscDispatchEvent).finalByte, 0x38);
    });

    test('ESC D (index), ESC E (next line), ESC M (reverse index)', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x44, 0x1B, 0x45, 0x1B, 0x4D]);
      expect(
        c.events.map((e) => (e as EscDispatchEvent).finalByte),
        [0x44, 0x45, 0x4D],
      );
    });

    test('ESC c (RIS — full reset)', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x63]);
      expect((c.events.single as EscDispatchEvent).finalByte, 0x63);
    });

    test('charset designator ESC ( B', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x28, 0x42]);
      final e = c.events.single as EscDispatchEvent;
      expect(e.intermediates, [0x28]);
      expect(e.finalByte, 0x42);
    });

    test('charset designator ESC ) 0', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x29, 0x30]);
      final e = c.events.single as EscDispatchEvent;
      expect(e.intermediates, [0x29]);
      expect(e.finalByte, 0x30);
    });

    test(r'ESC \ (ST) dispatches as a plain esc sequence', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x5C]);
      expect((c.events.single as EscDispatchEvent).finalByte, 0x5C);
    });

    test('ESC CAN returns to ground and executes', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x18, 0x41]);
      expect(c.events, [
        const ExecuteEvent(0x18),
        const PrintEvent(0x41),
      ]);
    });

    test('ESC SUB returns to ground and executes', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x1A, 0x41]);
      expect(c.events, [
        const ExecuteEvent(0x1A),
        const PrintEvent(0x41),
      ]);
    });

    test('ESC ESC stays in escape and resets', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x1B, 0x37]);
      // Second ESC resets; then 0x37 is dispatched as a normal esc.
      expect((c.events.single as EscDispatchEvent).finalByte, 0x37);
    });

    test('ESC C0 control is executed, state stays in escape', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x07, 0x37]);
      expect(c.events.first, const ExecuteEvent(0x07));
      expect(
        (c.events.last as EscDispatchEvent).finalByte,
        0x37,
      );
    });

    test('SOS/PM/APC are collected and silently dropped', () {
      final c = Collector();
      // ESC X junk ESC \
      VtParser(sink: c).advance('\x1BXjunk\x1B\\'.codeUnits);
      // Only ESC \ dispatches at the end (that's the ST sequence).
      expect(c.events.whereType<EscDispatchEvent>().length, 1);
      expect(c.events.whereType<PrintEvent>(), isEmpty);
    });
  });
}
