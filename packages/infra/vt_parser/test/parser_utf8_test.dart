import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

void main() {
  group('partial UTF-8', () {
    test('2-byte sequence split across two advances', () {
      final c = Collector();
      final parser = VtParser(sink: c)..advance([0xC3]);
      expect(c.events, isEmpty);
      parser.advance([0xA9]);
      expect(c.events, [const PrintEvent(0xE9)]);
    });

    test('3-byte sequence split 1+2', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xE6])
        ..advance([0x9C, 0xAB]); // 末
      expect(c.events, [const PrintEvent(0x672B)]);
    });

    test('3-byte sequence split 2+1', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xE6, 0x9C])
        ..advance([0xAB]);
      expect(c.events, [const PrintEvent(0x672B)]);
    });

    test('4-byte sequence split across every possible boundary', () {
      const bytes = [0xF0, 0x9F, 0x98, 0x80]; // 😀
      for (var splitAt = 1; splitAt < 4; splitAt++) {
        final c = Collector();
        VtParser(sink: c)
          ..advance(bytes.sublist(0, splitAt))
          ..advance(bytes.sublist(splitAt));
        expect(
          c.events,
          [const PrintEvent(0x1F600)],
          reason: 'splitAt=$splitAt',
        );
      }
    });

    test('incomplete sequence followed by more incomplete waits', () {
      final c = Collector();
      final parser = VtParser(sink: c)
        ..advance([0xF0]) // lead
        ..advance([0x9F]); // one continuation
      expect(c.events, isEmpty);
      parser.advance([0x98, 0x80]); // finish
      expect(c.events, [const PrintEvent(0x1F600)]);
    });

    test('invalid continuation after valid lead emits U+FFFD', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xC3])
        ..advance([0x20]); // not a continuation byte
      // The partial buffer's bad completion emits replacement, then
      // the 0x20 goes into ground and prints as space.
      expect(c.events.first, const PrintEvent(0xFFFD));
    });

    test('ASCII printable immediately after completing a partial', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xC3])
        ..advance([0xA9, 0x41]); // é then 'A'
      expect(c.events, [
        const PrintEvent(0xE9),
        const PrintEvent(0x41),
      ]);
    });
  });
}
