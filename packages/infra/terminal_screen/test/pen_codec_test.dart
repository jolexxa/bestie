// Test file: heavy on focused unit assertions, light on dependencies.

import 'dart:convert';
import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/pen_codec.dart';
import 'package:test/test.dart';

/// One run, as bytes.
Uint8List _run({
  required int byteLen,
  int fg = packedDefaultFg,
  int bg = packedDefaultBg,
  int attrs = CellAttrs.none,
}) {
  final pen = ByteWriter();
  writePenRun(pen, byteLen: byteLen, fg: fg, bg: bg, attrs: attrs);
  return pen.take();
}

/// Everything [readPen] finds in [pen].
List<({int byteLen, int fg, int bg, int attrs})> _runsOf(Uint8List pen) {
  final found = <({int byteLen, int fg, int bg, int attrs})>[];
  readPen(
    pen,
    (byteLen, fg, bg, attrs) =>
        found.add((byteLen: byteLen, fg: fg, bg: bg, attrs: attrs)),
  );
  return found;
}

String _ansi(String text, Uint8List pen) {
  final out = ByteWriter();
  penToAnsi(Uint8List.fromList(utf8.encode(text)), pen, out);
  return utf8.decode(out.view());
}

void main() {
  final red = packColor(const IndexedColor(9));
  final blue = packColor(const RgbColor(0, 0, 255));

  group('writePenRun', () {
    test('spends two bytes on the terminal own pen', () {
      // The common run by a wide margin, so it is the one worth measuring.
      expect(_run(byteLen: 12), hasLength(2));
    });

    test('spends a byte on an indexed colour', () {
      expect(_run(byteLen: 4, fg: red), hasLength(3));
    });

    test('spends three bytes on a truecolor', () {
      expect(_run(byteLen: 4, fg: blue), hasLength(5));
    });

    test('leaves attributes off when there are none', () {
      final plain = _run(byteLen: 4);
      final bold = _run(byteLen: 4, attrs: CellAttrs.setBold(CellAttrs.none));

      expect(bold.length, plain.length + 1);
    });

    test('grows the length field only as the run grows', () {
      expect(_run(byteLen: 127), hasLength(2));
      expect(_run(byteLen: 128), hasLength(3));
    });
  });

  group('readPen', () {
    test('finds nothing in an empty pen', () {
      expect(_runsOf(Uint8List(0)), isEmpty);
    });

    test('round-trips the default pen', () {
      expect(_runsOf(_run(byteLen: 7)), [
        (
          byteLen: 7,
          fg: packedDefaultFg,
          bg: packedDefaultBg,
          attrs: CellAttrs.none,
        ),
      ]);
    });

    test('round-trips an indexed colour', () {
      expect(_runsOf(_run(byteLen: 3, fg: red)).single.fg, red);
    });

    test('round-trips a truecolor, channel for channel', () {
      final colour = packColor(const RgbColor(12, 34, 56));

      expect(_runsOf(_run(byteLen: 3, bg: colour)).single.bg, colour);
    });

    test('round-trips every palette index', () {
      for (var index = 0; index < 256; index++) {
        final colour = packColor(IndexedColor(index));
        expect(
          _runsOf(_run(byteLen: 1, fg: colour)).single.fg,
          colour,
          reason: 'palette index $index',
        );
      }
    });

    test('round-trips attributes', () {
      // Underline lives in bits 7..9, so this is also the case that pushes
      // the attribute varint past a single group.
      final attrs = CellAttrs.setUnderlineStyle(
        CellAttrs.setBold(CellAttrs.none),
        UnderlineStyle.curly.index,
      );

      expect(_runsOf(_run(byteLen: 3, attrs: attrs)).single.attrs, attrs);
    });

    test('reads runs back in the order they were written', () {
      final pen = ByteWriter();
      writePenRun(
        pen,
        byteLen: 2,
        fg: red,
        bg: packedDefaultBg,
        attrs: CellAttrs.none,
      );
      writePenRun(
        pen,
        byteLen: 5,
        fg: packedDefaultFg,
        bg: blue,
        attrs: CellAttrs.none,
      );

      final runs = _runsOf(pen.take());

      expect(runs.map((r) => r.byteLen), [2, 5]);
      expect(runs.first.fg, red);
      expect(runs.last.bg, blue);
    });
  });

  group('penToAnsi', () {
    test('draws an unrecorded line in the terminal own pen', () {
      // A reset already says default-on-default, so it names neither.
      expect(_ansi('hello', Uint8List(0)), '\x1b[0mhello');
    });

    test('declares the pen before the text it covers', () {
      final drawn = _ansi('hi', _run(byteLen: 2, fg: red));

      expect(drawn, endsWith('hi'));
      expect(drawn, contains('38;5;9'));
    });

    test('declares every run in full rather than as a difference', () {
      // A line has to be replayable on its own, without the ones above it.
      final pen = ByteWriter();
      writePenRun(
        pen,
        byteLen: 2,
        fg: red,
        bg: packedDefaultBg,
        attrs: CellAttrs.none,
      );
      writePenRun(
        pen,
        byteLen: 2,
        fg: packedDefaultFg,
        bg: packedDefaultBg,
        attrs: CellAttrs.none,
      );

      final drawn = _ansi('abcd', pen.take());

      // Both runs open from a reset rather than the second assuming the
      // first — that is what makes a line replayable on its own.
      expect('\x1b[0'.allMatches(drawn), hasLength(2));
    });

    test('leaves every byte on screen when the runs fall short', () {
      final drawn = _ansi('abcdef', _run(byteLen: 2, fg: red));

      expect(drawn, endsWith('cdef'));
    });

    test('stops at the text when the runs overrun it', () {
      final drawn = _ansi('ab', _run(byteLen: 50, fg: red));

      expect(drawn, endsWith('ab'));
    });

    test('keeps multi-byte text whole', () {
      expect(_ansi('héllo →', Uint8List(0)), endsWith('héllo →'));
    });
  });
}
