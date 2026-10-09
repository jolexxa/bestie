import 'dart:convert';

import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

void main() {
  group('Utf8StreamDecoder', () {
    late Utf8StreamDecoder decoder;

    setUp(() {
      decoder = Utf8StreamDecoder();
    });

    test('decodes complete ascii in a single call', () {
      expect(decoder.add(utf8.encode('moo')), 'moo');
      expect(decoder.flush(), isEmpty);
    });

    test('returns empty for an empty byte run', () {
      expect(decoder.add(const []), isEmpty);
    });

    test('buffers a codepoint split across calls and joins it', () {
      final wave = utf8.encode('👋');

      expect(decoder.add(wave.sublist(0, 2)), isEmpty);
      expect(decoder.add(wave.sublist(2)), '👋');
      expect(decoder.flush(), isEmpty);
    });

    test('stitches a codepoint split into three byte runs', () {
      final bytes = utf8.encode('é👋'); // 2-byte + 4-byte codepoints

      final out = StringBuffer()
        ..write(decoder.add(bytes.sublist(0, 1)))
        ..write(decoder.add(bytes.sublist(1, 4)))
        ..write(decoder.add(bytes.sublist(4)))
        ..write(decoder.flush());

      expect(out.toString(), 'é👋');
    });

    test('flush surfaces an incomplete trailing sequence', () {
      final wave = utf8.encode('👋');

      expect(decoder.add(wave.sublist(0, 2)), isEmpty);
      expect(decoder.flush(), isNotEmpty); // replacement characters
    });

    test('flush is empty when the stream ended on a boundary', () {
      decoder.add(utf8.encode('cow'));

      expect(decoder.flush(), isEmpty);
    });
  });
}
