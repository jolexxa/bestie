// Test file: heavy on focused unit assertions, light on dependencies.

import 'dart:convert';
import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';
import 'package:terminal_screen/src/line_writer.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/pen_codec.dart';
import 'package:test/test.dart';

/// Stands in for the screen's grapheme table, which only ever has to answer
/// for codes the fast path did not already handle.
String _decode(int code) => String.fromCharCode(code);

/// Every run the writer left behind.
List<({int byteLen, int fg, int bg, int attrs})> _runs(LineWriter writer) {
  final found = <({int byteLen, int fg, int bg, int attrs})>[];
  readPen(
    writer.pen.view(),
    (byteLen, fg, bg, attrs) =>
        found.add((byteLen: byteLen, fg: fg, bg: bg, attrs: attrs)),
  );
  return found;
}

/// Writes [text] one ASCII cell at a time, all in one pen.
void _write(
  LineWriter writer,
  String text, {
  int fg = packedDefaultFg,
  int bg = packedDefaultBg,
  int attrs = CellAttrs.none,
}) {
  for (final code in text.codeUnits) {
    writer.add(code, _decode, fg: fg, bg: bg, attrs: attrs);
  }
}

String _text(LineWriter writer) => utf8.decode(writer.text.view());

void main() {
  final red = packColor(const IndexedColor(9));
  final bold = CellAttrs.setBold(CellAttrs.none);

  group('LineWriter', () {
    test('gathers the text it was given', () {
      final writer = LineWriter();
      _write(writer, 'hello');
      writer.end();

      expect(_text(writer), 'hello');
    });

    test('keeps no pen for a line drawn in the terminal own', () {
      // The property the whole format leans on: ordinary output pays nothing
      // at all for the ability to record colour.
      final writer = LineWriter();
      _write(writer, 'plain output');
      writer.end();

      expect(writer.pen.isEmpty, isTrue);
    });

    test('keeps a pen for a line that was drawn in one', () {
      final writer = LineWriter();
      _write(writer, 'red', fg: red);
      writer.end();

      expect(_runs(writer), [
        (byteLen: 3, fg: red, bg: packedDefaultBg, attrs: CellAttrs.none),
      ]);
    });

    test('closes a run exactly where the pen changes', () {
      final writer = LineWriter();
      _write(writer, 'ab', fg: red);
      _write(writer, 'cde');
      writer.end();

      expect(_runs(writer).map((r) => r.byteLen), [2, 3]);
      expect(_runs(writer).first.fg, red);
      expect(_runs(writer).last.fg, packedDefaultFg);
    });

    test('keeps the leading plain run of a line that turns styled', () {
      // The runs have to cover the text end to end, so a line that only goes
      // red halfway still records what came before it.
      final writer = LineWriter();
      _write(writer, 'plain');
      _write(writer, 'red', fg: red);
      writer.end();

      expect(_runs(writer).map((r) => r.byteLen), [5, 3]);
      expect(_runs(writer).first.fg, packedDefaultFg);
    });

    test('holds one run across cells drawn the same way', () {
      final writer = LineWriter();
      _write(writer, 'aaaa', attrs: bold);
      writer.end();

      expect(_runs(writer), hasLength(1));
    });

    test('separates runs that differ only in attributes', () {
      final writer = LineWriter();
      _write(writer, 'ab', attrs: bold);
      _write(writer, 'cd');
      writer.end();

      expect(_runs(writer).map((r) => r.attrs), [bold, CellAttrs.none]);
    });

    test('draws a blank cell as a space', () {
      final writer = LineWriter()
        ..add(0, _decode, fg: packedDefaultFg, bg: packedDefaultBg, attrs: 0)
        ..end();

      expect(_text(writer), ' ');
    });

    group('multi-byte text', () {
      test('is encoded as UTF-8', () {
        final writer = LineWriter()
          ..add(
            0xE9,
            _decode,
            fg: packedDefaultFg,
            bg: packedDefaultBg,
            attrs: 0,
          )
          ..end();

        expect(_text(writer), 'é');
        expect(writer.text.view(), [0xC3, 0xA9]);
      });

      test('is measured in bytes, not code units', () {
        // The run lengths index the stored bytes, so a two-byte character
        // has to count as two — otherwise replay slices in the wrong place.
        final writer = LineWriter()
          ..add(0xE9, _decode, fg: red, bg: packedDefaultBg, attrs: 0)
          ..end();

        expect(_runs(writer).single.byteLen, 2);
      });

      test('replays back to what was written', () {
        final writer = LineWriter();
        _write(writer, 'ab', fg: red);
        writer
          ..add(0x2192, _decode, fg: red, bg: packedDefaultBg, attrs: 0)
          ..end();

        expect(_text(writer), 'ab→');
        expect(_runs(writer).single.byteLen, 5);
      });
    });

    group('an empty line', () {
      test('holds no text', () {
        final writer = LineWriter()..end();

        expect(writer.text.isEmpty, isTrue);
      });

      test('holds no pen', () {
        final writer = LineWriter()..end();

        expect(writer.pen.isEmpty, isTrue);
      });
    });

    group('reset', () {
      test('drops the line', () {
        final writer = LineWriter();
        _write(writer, 'first', fg: red);
        writer
          ..end()
          ..reset();

        expect(writer.text.isEmpty, isTrue);
        expect(writer.pen.isEmpty, isTrue);
      });

      test('leaves no pen behind for the next line', () {
        // One writer serves every line of history, so a red line must not
        // colour the plain one after it.
        final writer = LineWriter();
        _write(writer, 'red', fg: red);
        writer
          ..end()
          ..reset();
        _write(writer, 'plain');
        writer.end();

        expect(_text(writer), 'plain');
        expect(writer.pen.isEmpty, isTrue);
      });

      test('starts the next line in the default pen', () {
        final writer = LineWriter();
        _write(writer, 'bold', attrs: bold);
        writer
          ..end()
          ..reset();
        _write(writer, 'ab', fg: red);
        writer.end();

        expect(_runs(writer).single.attrs, CellAttrs.none);
      });
    });
  });

  group('a written line and penToAnsi', () {
    test('round-trip through the pen the line was drawn with', () {
      final writer = LineWriter();
      _write(writer, 'no', fg: red);
      _write(writer, 'yes');
      writer.end();

      final runs = _runs(writer);

      expect(runs.map((r) => r.byteLen), [2, 3]);
      expect(
        utf8.decode(Uint8List.sublistView(writer.text.view(), 0, 2)),
        'no',
      );
    });
  });
}
