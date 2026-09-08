import 'dart:convert';
import 'dart:typed_data';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

Screen _screen({int rows = 6, int cols = 20, int scrollbackBytes = 20000}) =>
    Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);

/// SGR: the 256-colour palette entry [index] as a foreground.
String _fg(int index) => '\x1b[38;5;${index}m';

/// SGR: the 256-colour palette entry [index] as a background.
String _bg(int index) => '\x1b[48;5;${index}m';

const String _bold = '\x1b[1m';
const String _plain = '\x1b[0m';

int _indexed(int index) => packColor(IndexedColor(index));

String _text(LineBytes line) => utf8.decode(line.text);

typedef _Run = ({int bytes, int fg, int bg, int attrs});

List<_Run> _runs(Uint8List pen) {
  final runs = <_Run>[];
  readPen(
    pen,
    (bytes, fg, bg, attrs) =>
        runs.add((bytes: bytes, fg: fg, bg: bg, attrs: attrs)),
  );
  return runs;
}

void main() {
  group('recordedLines', () {
    test('leaves a line drawn in the default pen with no pen at all', () {
      final screen = _screen();

      _feed(screen, 'hello');

      final line = screen.recordedLines().single;
      expect(_text(line), 'hello');
      expect(line.pen, isEmpty);
    });

    test('covers the text end to end with runs', () {
      final screen = _screen();

      _feed(screen, 'ab${_fg(9)}cd${_plain}ef');

      final line = screen.recordedLines().single;
      expect(_text(line), 'abcdef');
      expect(
        [for (final run in _runs(line.pen)) run.bytes],
        [2, 2, 2],
        reason: 'the runs partition the text',
      );
    });

    test('keeps the colour a run was drawn in', () {
      final screen = _screen();

      _feed(screen, '${_fg(9)}red$_plain plain');

      final runs = _runs(screen.recordedLines().single.pen);
      expect(runs.first.fg, _indexed(9));
      expect(runs.first.bg, packedDefaultBg);
      expect(runs.last.fg, packedDefaultFg);
    });

    test('keeps a background apart from a foreground', () {
      final screen = _screen();

      _feed(screen, '${_bg(4)}onblue');

      final run = _runs(screen.recordedLines().single.pen).single;
      expect(run.bg, _indexed(4));
      expect(run.fg, packedDefaultFg);
    });

    test('keeps the attributes a run was drawn with', () {
      final screen = _screen();

      _feed(screen, '${_bold}loud${_plain}quiet');

      final runs = _runs(screen.recordedLines().single.pen);
      expect(CellAttrs.isBold(runs.first.attrs), isTrue);
      expect(runs.first.bytes, 4);
      expect(CellAttrs.isBold(runs.last.attrs), isFalse);
    });

    test('joins neighbours that share a pen into one run', () {
      final screen = _screen();

      // The pen is re-declared mid-word without changing.
      _feed(screen, '${_fg(9)}ab${_fg(9)}cd');

      expect(_runs(screen.recordedLines().single.pen), hasLength(1));
    });

    test('runs follow a wrapped line across the rows it broke into', () {
      final screen = _screen(cols: 8);

      _feed(screen, '${_fg(9)}${'a' * 12}$_plain${'b' * 4}');

      final line = screen.recordedLines().single;
      expect(_text(line), '${'a' * 12}${'b' * 4}');
      expect([for (final run in _runs(line.pen)) run.bytes], [12, 4]);
    });

    test('measures a run in the bytes of the text it covers', () {
      final screen = _screen();

      // An astral emoji is one cell, two UTF-16 units and four UTF-8 bytes.
      // A reader slicing bytes needs the last of the three.
      _feed(screen, '${_fg(9)}\u{1F600}${_plain}x');

      final line = screen.recordedLines().single;
      final first = _runs(line.pen).first.bytes;
      expect(first, utf8.encode('\u{1F600}').length);
      expect(utf8.decode(line.text.sublist(0, first)), '\u{1F600}');
    });

    test('counts a line in the code units everything above it measures in', () {
      final screen = _screen();

      _feed(screen, '\u{1F600}ok');

      expect(screen.recordedLines().single.units, '\u{1F600}ok'.length);
    });

    test('holds one entry per logical line, in order', () {
      final screen = _screen();

      _feed(screen, 'one\r\n${_fg(9)}two$_plain\r\nthree');

      final lines = screen.recordedLines();
      expect([for (final line in lines) _text(line)], ['one', 'two', 'three']);
      expect(lines[0].pen, isEmpty);
      expect(lines[1].pen, isNotEmpty);
    });

    test('holds the history even while an alt screen is in front of it', () {
      // A recorder is after what the session printed. A child taking the alt
      // screen has covered that up, not unprinted it.
      final screen = _screen();

      _feed(screen, 'one\r\ntwo\r\nthree');
      _feed(screen, '\x1b[?1049h');
      _feed(screen, 'a child repainting');

      expect(
        [
          for (final line in screen.recordedLines()) _text(line),
        ],
        ['one', 'two', 'three'],
      );
    });

    test('reads the same text the plain projection does', () {
      final screen = _screen(cols: 12);

      _feed(
        screen,
        '${_fg(9)}${'a' * 30}$_plain\r\nplain\r\n${_bold}bold$_plain',
      );

      expect([
        for (final line in screen.recordedLines()) _text(line),
      ], screen.selectionLines());
    });
  });

  group('evicted lines', () {
    /// The first line dropped after [first] is pushed out of history, which
    /// leaves through a walk of its own rather than the general one.
    LineBytes dropping(String first) {
      final screen = _screen(rows: 4, scrollbackBytes: 2400);
      final dropped = <LineBytes>[];
      screen.onEvicted = (text, pen, units) => dropped.add(
        LineBytes(
          text: Uint8List.fromList(text),
          pen: Uint8List.fromList(pen),
          units: units,
        ),
      );

      _feed(screen, first);
      _feed(screen, [for (var i = 2; i <= 30; i++) '\r\nline $i'].join());

      return dropped.first;
    }

    test('carry the pen of the line that was dropped', () {
      final line = dropping('${_fg(9)}line 1$_plain');

      expect(_text(line), 'line 1');
      expect(_runs(line.pen).single.fg, _indexed(9));
    });

    test('close a run where the pen changed part way along', () {
      final line = dropping('ab${_fg(9)}cd${_plain}ef');

      expect(_text(line), 'abcdef');
      expect([for (final run in _runs(line.pen)) run.bytes], [2, 2, 2]);
    });

    test('count a wide character once, as the one cell it reads as', () {
      // The cell after a double-width glyph is its continuation and holds no
      // character of its own; counting it would pad the text with a space.
      final line = dropping('${_fg(9)}中文');

      expect(_text(line), '中文');
      expect(_runs(line.pen).single.bytes, utf8.encode('中文').length);
      expect(line.units, 2);
    });

    test('measure a run in the bytes of the text it covers', () {
      final line = dropping('${_fg(9)}\u{1F600}${_plain}x');

      final first = _runs(line.pen).first.bytes;
      expect(first, utf8.encode('\u{1F600}').length);
      expect(utf8.decode(line.text.sublist(0, first)), '\u{1F600}');
    });

    test('leave a blank line with nothing to redraw', () {
      final line = dropping('');

      expect(line.text, isEmpty);
      expect(line.pen, isEmpty);
    });

    test('read the same as the general walk would have', () {
      final screen = _screen(rows: 4, scrollbackBytes: 2400);
      final dropped = <LineBytes>[];
      screen.onEvicted = (text, pen, units) => dropped.add(
        LineBytes(
          text: Uint8List.fromList(text),
          pen: Uint8List.fromList(pen),
          units: units,
        ),
      );
      final source = '${_bold}bold$_plain ${_fg(9)}red$_plain plain';

      _feed(screen, source);
      _feed(screen, [for (var i = 2; i <= 30; i++) '\r\nline $i'].join());

      final reference = _screen();
      _feed(reference, source);

      final expected = reference.recordedLines().single;
      expect(dropped.first.text, expected.text);
      expect(dropped.first.pen, expected.pen);
      expect(dropped.first.units, expected.units);
    });

    test('hands over buffers it means to reuse for the next line', () {
      // The whole point of the sink taking bytes rather than an object: a
      // recorder copies them straight into its own buffer, and nothing is
      // allocated for a line on its way into a record.
      final screen = _screen(rows: 4, scrollbackBytes: 2400);
      final seen = <Uint8List>[];
      screen.onEvicted = (text, pen, units) => seen.add(text);

      // Every line the same length and none of them alike, so what the first
      // view reads as afterwards says which line's bytes are under it.
      _feed(
        screen,
        [
          for (var i = 0; i < 30; i++) String.fromCharCode(0x61 + i % 26) * 8,
        ].join('\r\n'),
      );

      expect(seen.length, greaterThan(1));
      expect(
        utf8.decode(seen.first),
        utf8.decode(seen.last),
        reason:
            'the view handed over first now reads as the line handed over '
            'last, because there was only ever one buffer',
      );
    });
  });
}
