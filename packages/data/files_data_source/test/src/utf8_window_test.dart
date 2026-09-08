import 'dart:convert';

import 'package:files_data_source/src/utf8_window.dart';
import 'package:test/test.dart';

void main() {
  final euro = utf8.encode('€');
  final clef = utf8.encode('𝄞');

  group('isUtf8Continuation', () {
    test('is true only for 10xxxxxx bytes', () {
      expect(isUtf8Continuation(0x41), isFalse);
      expect(isUtf8Continuation(0xC3), isFalse);
      expect(isUtf8Continuation(0xA9), isTrue);
      expect(isUtf8Continuation(0xBF), isTrue);
    });
  });

  group('utf8SequenceLength', () {
    test('reads the length off the lead byte', () {
      expect(utf8SequenceLength(0x41), 1);
      expect(utf8SequenceLength(0xC3), 2);
      expect(utf8SequenceLength(0xE2), 3);
      expect(utf8SequenceLength(0xF0), 4);
    });

    test('treats a continuation or invalid lead as one byte', () {
      expect(utf8SequenceLength(0xA9), 1);
      expect(utf8SequenceLength(0xFF), 1);
    });
  });

  group('alignDown', () {
    test('walks back off a continuation byte', () {
      expect(alignDown(euro, 2), 0);
      expect(alignDown(euro, 1), 0);
    });

    test('leaves a boundary alone', () {
      expect(alignDown(utf8.encode('abc'), 2), 2);
    });

    test('treats the end of the buffer as a boundary', () {
      expect(alignDown(euro, euro.length), euro.length);
    });

    test('clamps out-of-range indices', () {
      expect(alignDown(euro, -5), 0);
      expect(alignDown(euro, 99), euro.length);
    });
  });

  group('alignUp', () {
    test('walks forward off a continuation byte', () {
      expect(alignUp(euro, 1), euro.length);
    });

    test('leaves a boundary alone', () {
      expect(alignUp(utf8.encode('abc'), 1), 1);
    });

    test('clamps out-of-range indices', () {
      expect(alignUp(euro, -5), 0);
      expect(alignUp(euro, 99), euro.length);
    });
  });

  group('utf8Window', () {
    test('keeps a clean chunk whole', () {
      final bytes = utf8.encode('hello');
      final window = utf8Window(bytes);

      expect(window.start, 0);
      expect(window.end, bytes.length);
      expect(window.length, bytes.length);
      expect(window.isEmpty, isFalse);
    });

    test('drops continuation bytes orphaned at the front', () {
      final bytes = [...euro.sublist(1), ...utf8.encode('ok')];
      final window = utf8Window(bytes);

      expect(utf8.decode(bytes.sublist(window.start, window.end)), 'ok');
    });

    test('drops a sequence left incomplete at the back', () {
      final bytes = [...utf8.encode('ok'), ...euro.sublist(0, 2)];
      final window = utf8Window(bytes);

      expect(utf8.decode(bytes.sublist(window.start, window.end)), 'ok');
    });

    test('handles a four-byte sequence cut one byte short', () {
      final bytes = [...utf8.encode('x'), ...clef.sublist(0, 3)];
      final window = utf8Window(bytes);

      expect(utf8.decode(bytes.sublist(window.start, window.end)), 'x');
    });

    test('keeps a four-byte sequence that is complete', () {
      final bytes = [...utf8.encode('x'), ...clef];

      expect(utf8Window(bytes).end, bytes.length);
    });

    test('is empty for a chunk that is all continuation bytes', () {
      final window = utf8Window(const [0xA9, 0xA9]);

      expect(window.isEmpty, isTrue);
      expect(window.length, 0);
    });

    test('is empty for an empty chunk', () {
      expect(utf8Window(const []).isEmpty, isTrue);
    });
  });
}
