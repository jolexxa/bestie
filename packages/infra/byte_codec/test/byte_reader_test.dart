// Test file: full-width 64-bit values are the point of the fixed-width
// readers, and this codec only ever runs on a native VM.
// ignore_for_file: avoid_js_rounded_ints

import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:test/test.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('ByteReader', () {
    test('reads bytes in order', () {
      final reader = ByteReader(_bytes([1, 2, 3]));

      expect(reader.byte(), 1);
      expect(reader.byte(), 2);
      expect(reader.byte(), 3);
      expect(reader.isEmpty, isTrue);
    });

    test('starts where it is told to', () {
      final reader = ByteReader(_bytes([1, 2, 3]), 2);

      expect(reader.offset, 2);
      expect(reader.byte(), 3);
    });

    test('reports what is left', () {
      final reader = ByteReader(_bytes([1, 2, 3]));

      expect(reader.remaining, 3);
      expect(reader.isNotEmpty, isTrue);

      reader.byte();

      expect(reader.remaining, 2);
    });

    test('reads fixed widths little-endian', () {
      final reader = ByteReader(
        _bytes([
          1, 2, //
          1, 2, 3, 4, //
          1, 2, 3, 4, 5, 6, 7, 8, //
        ]),
      );

      expect(reader.uint16(), 0x0201);
      expect(reader.uint32(), 0x04030201);
      expect(reader.uint64(), 0x0807060504030201);
    });

    group('varint', () {
      test('reads a single group', () {
        expect(ByteReader(_bytes([0])).varint(), 0);
        expect(ByteReader(_bytes([127])).varint(), 127);
      });

      test('follows the continuation bit', () {
        expect(ByteReader(_bytes([0x80, 0x01])).varint(), 128);
        expect(ByteReader(_bytes([0xAC, 0x02])).varint(), 300);
        expect(ByteReader(_bytes([0x80, 0x80, 0x01])).varint(), 16384);
      });

      test('stops at the end of the varint, not the end of the bytes', () {
        final reader = ByteReader(_bytes([0xAC, 0x02, 9]));

        expect(reader.varint(), 300);
        expect(reader.byte(), 9);
      });
    });

    test('hands back a run of bytes and moves past it', () {
      final reader = ByteReader(_bytes([1, 2, 3, 4]));

      expect(reader.bytes(3), [1, 2, 3]);
      expect(reader.offset, 3);
      expect(reader.byte(), 4);
    });

    test('reads zero bytes without moving', () {
      final reader = ByteReader(_bytes([1]));

      expect(reader.bytes(0), isEmpty);
      expect(reader.offset, 0);
    });

    test('refuses a run that runs off the end', () {
      // A truncated record has to fail loudly rather than hand back a short
      // one — a scan over a damaged file is what catches this.
      final reader = ByteReader(_bytes([1, 2]));

      expect(() => reader.bytes(3), throwsA(isA<RangeError>()));
    });

    test('throws reading past the end', () {
      final reader = ByteReader(_bytes([1]))..byte();

      expect(reader.byte, throwsA(isA<RangeError>()));
    });

    test('seeks to wherever it is pointed', () {
      final reader = ByteReader(_bytes([1, 2, 3, 4]))..offset = 3;

      expect(reader.byte(), 4);

      reader.offset = 1;

      expect(reader.byte(), 2);
    });

    test('skips without reading', () {
      final reader = ByteReader(_bytes([1, 2, 3]))..skip(2);

      expect(reader.byte(), 3);
    });

    // A length read out of the bytes themselves can be longer than what is
    // left, and a reader that ran past the end would report room it has not
    // got rather than reporting that it is done.
    test('stops at the end rather than skipping past it', () {
      final reader = ByteReader(_bytes([1, 2, 3]))..skip(9);

      expect(reader.remaining, 0);
      expect(reader.isEmpty, isTrue);
    });

    test('reads a slice of a larger buffer', () {
      // Records are read out of a window of the file, so the reader has to
      // respect where its view starts rather than the buffer behind it.
      final whole = _bytes([9, 9, 1, 2, 3, 4]);
      final slice = Uint8List.sublistView(whole, 2);

      final reader = ByteReader(slice);

      expect(reader.uint16(), 0x0201);
      expect(reader.remaining, 2);
    });
  });

  group('a writer and a reader', () {
    test('round-trip every primitive in order', () {
      final writer = ByteWriter()
        ..byte(7)
        ..uint16(1000)
        ..uint32(100000)
        ..uint64(1 << 40)
        ..varint(0)
        ..varint(300)
        ..varint(1 << 40)
        ..bytes(_bytes([4, 5, 6]));

      final reader = ByteReader(writer.take());

      expect(reader.byte(), 7);
      expect(reader.uint16(), 1000);
      expect(reader.uint32(), 100000);
      expect(reader.uint64(), 1 << 40);
      expect(reader.varint(), 0);
      expect(reader.varint(), 300);
      expect(reader.varint(), 1 << 40);
      expect(reader.bytes(3), [4, 5, 6]);
      expect(reader.isEmpty, isTrue);
    });

    test('round-trip varints across every group boundary', () {
      for (var shift = 0; shift < 56; shift += 7) {
        for (final value in [1 << shift, (1 << shift) - 1]) {
          final reader = ByteReader((ByteWriter()..varint(value)).take());
          expect(reader.varint(), value, reason: 'round trip of $value');
        }
      }
    });
  });
}
