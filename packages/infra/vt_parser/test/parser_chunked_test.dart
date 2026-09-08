import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

/// Parses [bytes] in one pass and returns the collected events.
List<ParserEvent> _parseWhole(List<int> bytes) {
  final c = Collector();
  VtParser(sink: c).advance(bytes);
  return c.events;
}

/// Parses [bytes] by feeding them one at a time and returns the
/// collected events.
List<ParserEvent> _parseByteByByte(List<int> bytes) {
  final c = Collector();
  final parser = VtParser(sink: c);
  for (final b in bytes) {
    parser.advance([b]);
  }
  return c.events;
}

/// Parses [bytes] in chunks of size [chunkSize].
List<ParserEvent> _parseInChunks(List<int> bytes, int chunkSize) {
  final c = Collector();
  final parser = VtParser(sink: c);
  for (var i = 0; i < bytes.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, bytes.length);
    parser.advance(bytes.sublist(i, end));
  }
  return c.events;
}

void main() {
  group('chunked invariance', () {
    // A mixed input with printable ASCII, a CSI SGR sequence, an
    // OSC window title with BEL termination, a C0 control, and some
    // UTF-8 multi-byte characters.
    final input = <int>[
      ...'hello '.codeUnits,
      0x1B, 0x5B, 0x33, 0x31, 0x6D, // ESC [ 3 1 m — SGR red fg
      ...'world'.codeUnits,
      0x1B, 0x5B, 0x30, 0x6D, // ESC [ 0 m — SGR reset
      0x0A, // LF
      0x1B, 0x5D, 0x32, 0x3B, // ESC ] 2 ;
      ...'title'.codeUnits,
      0x07, // BEL
      0xC3, 0xA9, // é
      0xF0, 0x9F, 0x98, 0x80, // 😀
    ];

    test('whole vs byte-by-byte produces identical events', () {
      expect(_parseByteByByte(input), _parseWhole(input));
    });

    test('every chunk size from 1..len produces identical events', () {
      final whole = _parseWhole(input);
      for (var size = 1; size <= input.length; size++) {
        expect(
          _parseInChunks(input, size),
          whole,
          reason: 'chunkSize=$size',
        );
      }
    });
  });

  group('reset', () {
    test('reset() drops in-progress CSI state', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance('\x1B[1;2'.codeUnits)
        ..reset()
        ..advance('hi'.codeUnits);
      expect(c.events, [
        const PrintEvent(0x68),
        const PrintEvent(0x69),
      ]);
    });

    test('reset() drops partial UTF-8 state', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xE6, 0x9C]) // partial 末
        ..reset()
        ..advance([0x41]);
      expect(c.events, [const PrintEvent(0x41)]);
    });
  });

  group('events stream', () {
    test('broadcast stream fires synchronously during advance', () async {
      final parser = VtParser();
      final events = <ParserEvent>[];
      final sub = parser.events.listen(events.add);
      parser.advance([0x41, 0x42]);
      await Future<void>.delayed(Duration.zero);
      expect(events, [const PrintEvent(0x41), const PrintEvent(0x42)]);
      await sub.cancel();
    });
  });
}
