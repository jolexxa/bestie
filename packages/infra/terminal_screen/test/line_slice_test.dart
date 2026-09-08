// Slicing a stored line must break exactly where a stored re-wrap
// would: one break algorithm, two callers, zero drift. The reference
// is a real ReflowWriter pass over the same content.

import 'dart:math';
import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:test/test.dart';

import 'reflow_fakes.dart';

/// Builds a stored line from [content] in the fake-grid alphabet
/// (`[`/`]` a wide pair, anything else a single-width glyph).
LogicalLine _line(String content) {
  final line = LogicalLine(seq: 0);
  final chars = Uint32List(content.length);
  final fg = Uint32List(content.length)
    ..fillRange(0, content.length, packedDefaultFg);
  final bg = Uint32List(content.length)
    ..fillRange(0, content.length, packedDefaultBg);
  final style = Uint16List(content.length);
  for (var i = 0; i < content.length; i++) {
    chars[i] = content.codeUnitAt(i);
    style[i] = switch (content[i]) {
      '[' => packStyle(attrs: CellAttrs.none, width: CellWidth.wide),
      ']' => packStyle(attrs: CellAttrs.none, width: CellWidth.continuation),
      _ => blankStyle,
    };
  }
  line
    ..append(
      chars: chars,
      fg: fg,
      bg: bg,
      style: style,
      base: 0,
      count: content.length,
    )
    ..close();
  return line;
}

/// Display row [row] of [line] at [cols], rendered back into the fake
/// alphabet with padding blanks and a synthesized spacer head.
String _derivedRow(LogicalLine line, int cols, int row) {
  final start = line.rowStartsAt(cols)[row];
  final length = line.rowLengthAt(cols, row);
  final cells = List<String>.filled(cols, ' ');
  for (var i = 0; i < length; i++) {
    cells[i] = String.fromCharCode(line.charCodeAt(start + i));
  }
  if (length < cols && row < line.rowsAt(cols) - 1) cells[length] = '^';
  return cells.join();
}

/// Reference: [content] re-wrapped to [cols] by the real writer.
List<String> _reflowedRows(String content, int cols) {
  final source = FakeReflowSource([content]);
  final sink = FakeRowSink(source, cols: cols);
  ReflowWriter(source: source, sink: sink).run();
  return sink.rows;
}

void _expectSliceMatchesReflow(String content, int cols) {
  final line = _line(content);
  final expected = _reflowedRows(content, cols);
  expect(
    line.rowsAt(cols),
    expected.length,
    reason: '"$content" at $cols: row count',
  );
  for (var r = 0; r < expected.length; r++) {
    expect(
      _derivedRow(line, cols, r),
      expected[r],
      reason: '"$content" at $cols: row $r',
    );
  }
}

void main() {
  group('derived slices match a stored re-wrap', () {
    test('plain content at assorted widths', () {
      for (final cols in [2, 3, 5, 8, 40]) {
        _expectSliceMatchesReflow('abcdefghij', cols);
      }
    });

    test('wide clusters that land on break boundaries', () {
      for (final cols in [2, 3, 4, 5, 7]) {
        _expectSliceMatchesReflow('a[]b[]c[]', cols);
        _expectSliceMatchesReflow('[][][]', cols);
        _expectSliceMatchesReflow('abc[]de[]', cols);
      }
    });

    test('content shorter than the width is one row', () {
      final line = _line('ab');
      expect(line.rowsAt(10), 1);
      expect(_derivedRow(line, 10, 0), 'ab        ');
    });

    test('randomized content and widths never drift', () {
      final random = Random(42);
      const glyphs = ['a', 'b', 'c', 'd', '[]'];
      for (var trial = 0; trial < 200; trial++) {
        final content = StringBuffer();
        final pieces = random.nextInt(20) + 1;
        for (var i = 0; i < pieces; i++) {
          content.write(glyphs[random.nextInt(glyphs.length)]);
        }
        final cols = random.nextInt(11) + 2;
        _expectSliceMatchesReflow(content.toString(), cols);
      }
    });
  });
}
