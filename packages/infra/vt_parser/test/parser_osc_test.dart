import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

void main() {
  group('OSC', () {
    test('BEL-terminated OSC 2; title', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B]2;hello\x07'.codeUnits);
      expect(c.events.length, 1);
      final osc = c.events.single as OscDispatchEvent;
      expect(osc.bellTerminated, isTrue);
      expect(osc.params, [
        [0x32],
        'hello'.codeUnits,
      ]);
    });

    test('ST-terminated OSC 11; color', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B]11;ff/00/ff\x1B\\'.codeUnits);
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.bellTerminated, isFalse);
      expect(osc.params, [
        [0x31, 0x31],
        'ff/00/ff'.codeUnits,
      ]);
    });

    test('empty OSC (ESC ] BEL)', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x5D, 0x07]);
      expect(c.events, [
        const OscDispatchEvent(
          params: [<int>[]],
          bellTerminated: true,
        ),
      ]);
    });

    test('OSC 8 hyperlink with `;` inside URL param', () {
      // Syntax: OSC 8 ; <params> ; <URI> ST
      // The extra `;` splits the payload into 3 params.
      final c = Collector();
      VtParser(sink: c).advance(
        '\x1B]8;;https://example.com\x07'.codeUnits,
      );
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.params.length, 3);
      expect(osc.params[0], [0x38]);
      expect(osc.params[1], <int>[]);
      expect(osc.params[2], 'https://example.com'.codeUnits);
    });

    test('UTF-8 inside OSC payload is preserved byte-for-byte', () {
      // "echo '¯\\_(ツ)_/¯'" — ツ is 3 bytes UTF-8.
      final payloadBytes = <int>[
        0x32,
        0x3B,
        ...'echo '.codeUnits,
        0x27,
        0xC2,
        0xAF,
        0x5C,
        0x5F,
        0x28,
        0xE3,
        0x83,
        0x84,
        0x29,
        0x5F,
        0x2F,
        0xC2,
        0xAF,
        0x27,
      ];
      final input = <int>[0x1B, 0x5D, ...payloadBytes, 0x07];
      final c = Collector();
      VtParser(sink: c).advance(input);
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.params[0], [0x32]);
      expect(osc.params[1], payloadBytes.sublist(2));
    });

    test('overflowing max OSC raw buffer still dispatches known bytes', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance('\x1B]52;s'.codeUnits)
        ..advance(List<int>.filled(2000, 0x61)) // 2000 'a's
        ..advance([0x07]);
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.params[0], [0x35, 0x32]);
      // Second param is truncated but must be non-empty.
      expect(osc.params[1], isNotEmpty);
    });

    test('overflowing max OSC params still dispatches', () {
      final buffer = StringBuffer('\x1B]');
      // 17 `;`-separated empty params → overflow maxOscParams (16).
      for (var i = 0; i < 17; i++) {
        buffer.write(';');
      }
      buffer.write('\x07');
      final c = Collector();
      VtParser(sink: c).advance(buffer.toString().codeUnits);
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.params.length, lessThanOrEqualTo(16));
    });
  });
}
