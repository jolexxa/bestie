import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

void main() {
  group('ground state', () {
    test('prints ASCII printable characters', () {
      final c = Collector();
      VtParser(sink: c).advance('hello'.codeUnits);
      expect(c.events, [
        const PrintEvent(0x68),
        const PrintEvent(0x65),
        const PrintEvent(0x6C),
        const PrintEvent(0x6C),
        const PrintEvent(0x6F),
      ]);
    });

    test('executes C0 controls', () {
      final c = Collector();
      // BEL, BS, HT, LF, CR, SO, SI
      VtParser(sink: c).advance([0x07, 0x08, 0x09, 0x0A, 0x0D, 0x0E, 0x0F]);
      expect(c.events, [
        const ExecuteEvent(0x07),
        const ExecuteEvent(0x08),
        const ExecuteEvent(0x09),
        const ExecuteEvent(0x0A),
        const ExecuteEvent(0x0D),
        const ExecuteEvent(0x0E),
        const ExecuteEvent(0x0F),
      ]);
    });

    test('DEL (0x7F) is executed', () {
      final c = Collector();
      VtParser(sink: c).advance([0x7F]);
      expect(c.events, [const ExecuteEvent(0x7F)]);
    });

    test('interleaves prints and controls', () {
      final c = Collector();
      VtParser(sink: c).advance('hi\n'.codeUnits);
      expect(c.events, [
        const PrintEvent(0x68),
        const PrintEvent(0x69),
        const ExecuteEvent(0x0A),
      ]);
    });

    test('empty input is a no-op', () {
      final c = Collector();
      VtParser(sink: c).advance(const <int>[]);
      expect(c.events, isEmpty);
    });

    test('ESC transitions out of ground', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x37]); // ESC 7 — save cursor
      expect(c.events, [
        const EscDispatchEvent(
          intermediates: [],
          finalByte: 0x37,
          ignore: false,
        ),
      ]);
    });

    test('8-bit C1 byte (0x85 NEL) is executed in ground', () {
      final c = Collector();
      VtParser(sink: c).advance([0x85]);
      expect(c.events, [const ExecuteEvent(0x85)]);
    });

    test('prints Unicode BMP (U+00E9)', () {
      final c = Collector();
      VtParser(sink: c).advance([0xC3, 0xA9]); // é
      expect(c.events, [const PrintEvent(0xE9)]);
    });

    test('prints Unicode astral (U+1F600)', () {
      final c = Collector();
      VtParser(sink: c).advance([0xF0, 0x9F, 0x98, 0x80]); // 😀
      expect(c.events, [const PrintEvent(0x1F600)]);
    });

    test('emits U+FFFD for invalid lead byte', () {
      final c = Collector();
      VtParser(sink: c).advance([0xFF]);
      expect(c.events, [const PrintEvent(0xFFFD)]);
    });

    test('emits U+FFFD for invalid continuation', () {
      final c = Collector();
      // 0xC3 expects a continuation byte in 0x80..0xBF; feed 0x20.
      VtParser(sink: c).advance([0xC3, 0x20]);
      expect(c.events, [const PrintEvent(0xFFFD), const PrintEvent(0x20)]);
    });

    test('rejects overlong 3-byte encoding of NUL', () {
      final c = Collector();
      // 0xE0 0x80 0x80 would "encode" U+0000; it's overlong → invalid.
      VtParser(sink: c).advance([0xE0, 0x80, 0x80]);
      expect(c.events.first, const PrintEvent(0xFFFD));
    });

    test('rejects surrogate encoded via 3-byte sequence', () {
      final c = Collector();
      // 0xED 0xA0 0x80 would encode U+D800; surrogates are invalid.
      VtParser(sink: c).advance([0xED, 0xA0, 0x80]);
      expect(c.events.first, const PrintEvent(0xFFFD));
    });
  });
}
