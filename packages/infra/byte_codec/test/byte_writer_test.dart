// Test file: full-width 64-bit values are the point of the fixed-width
// writers, and this codec only ever runs on a native VM.
// ignore_for_file: avoid_js_rounded_ints

import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:test/test.dart';

void main() {
  group('ByteWriter', () {
    test('starts empty', () {
      final writer = ByteWriter();

      expect(writer.length, 0);
      expect(writer.isEmpty, isTrue);
      expect(writer.isNotEmpty, isFalse);
      expect(writer.view(), isEmpty);
    });

    test('appends bytes in order', () {
      final writer = ByteWriter()
        ..byte(1)
        ..byte(2)
        ..byte(3);

      expect(writer.view(), [1, 2, 3]);
      expect(writer.length, 3);
      expect(writer.isNotEmpty, isTrue);
    });

    test('keeps only the low eight bits of a byte', () {
      final writer = ByteWriter()..byte(0x1FF);

      expect(writer.view(), [0xFF]);
    });

    test('writes fixed widths little-endian', () {
      final writer = ByteWriter()
        ..uint16(0x0201)
        ..uint32(0x04030201)
        ..uint64(0x0807060504030201);

      expect(writer.view(), [
        1, 2, //
        1, 2, 3, 4, //
        1, 2, 3, 4, 5, 6, 7, 8, //
      ]);
    });

    group('varint', () {
      test('spends one byte on anything under 128', () {
        for (final value in [0, 1, 42, 127]) {
          expect(
            (ByteWriter()..varint(value)).view(),
            [value],
            reason: '$value should be a single group',
          );
        }
      });

      test('carries into a second byte at 128', () {
        expect((ByteWriter()..varint(128)).view(), [0x80, 0x01]);
        expect((ByteWriter()..varint(300)).view(), [0xAC, 0x02]);
        expect((ByteWriter()..varint(16383)).view(), [0xFF, 0x7F]);
        expect((ByteWriter()..varint(16384)).view(), [0x80, 0x80, 0x01]);
      });

      test('sets the continuation bit on every byte but the last', () {
        final bytes = (ByteWriter()..varint(1 << 40)).view();

        expect(
          bytes.take(bytes.length - 1).every((b) => b & 0x80 != 0),
          isTrue,
        );
        expect(bytes.last & 0x80, 0);
      });

      test('refuses a negative value', () {
        expect(() => ByteWriter().varint(-1), throwsA(isA<AssertionError>()));
      });
    });

    test('appends a whole byte list', () {
      final writer = ByteWriter()
        ..byte(9)
        ..bytes(Uint8List.fromList([1, 2, 3]));

      expect(writer.view(), [9, 1, 2, 3]);
    });

    test('takes an empty list in stride', () {
      final writer = ByteWriter()
        ..byte(9)
        ..bytes(Uint8List(0));

      expect(writer.view(), [9]);
    });

    test('grows past the capacity it was given', () {
      // Deliberately smaller than what is about to be written, several times
      // over, so the buffer has to grow more than once.
      final writer = ByteWriter(8);
      final written = List<int>.generate(500, (i) => i & 0xFF)
        ..forEach(writer.byte);

      expect(writer.view(), written);
    });

    test('grows to fit a single write larger than a doubling', () {
      final writer = ByteWriter(8)..bytes(Uint8List(1000));

      expect(writer.length, 1000);
    });

    test('holds a floor under the capacity it was asked for', () {
      final writer = ByteWriter(0)..uint64(1);

      expect(writer.length, 8);
    });

    group('reset', () {
      test('drops what was written', () {
        final writer = ByteWriter()
          ..byte(1)
          ..byte(2)
          ..reset();

        expect(writer.length, 0);
        expect(writer.isEmpty, isTrue);
        expect(writer.view(), isEmpty);
      });

      test('leaves the writer ready for the next record', () {
        final writer = ByteWriter()
          ..byte(1)
          ..reset()
          ..byte(2)
          ..byte(3);

        expect(writer.view(), [2, 3]);
      });
    });

    test('take copies, so it survives the next record', () {
      // The whole reason both exist: one writer serves many records, and a
      // caller that means to keep a record has to say so.
      final writer = ByteWriter()
        ..byte(1)
        ..byte(2);

      final kept = writer.take();
      writer
        ..reset()
        ..byte(9);

      expect(kept, [1, 2]);
    });

    test('view reads the bytes written so far', () {
      final writer = ByteWriter()..byte(1);
      expect(writer.view(), [1]);

      writer.byte(2);
      expect(writer.view(), [1, 2]);
    });
  });
}
