// Resizing must never cost history. Under a row-denominated cap, narrow
// reflow inflates the row count past capacity and evicts from the front
// even when the buffer was nowhere near full at its original width; the
// byte-capped logical-line store makes that impossible.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

void main() {
  test(
    'an extreme resize round-trip retains every line of history',
    () {
      final screen = Screen(rows: 10, cols: 100, scrollbackBytes: 100 * 4096);
      _feed(
        screen,
        List.generate(
          60,
          (i) => 'line ${i.toString().padLeft(2, '0')}: ${'x' * 80}',
        ).join('\r\n'),
      );
      final before = screen.selectionText().text;

      screen
        ..resize(rows: 10, cols: 25)
        ..resize(rows: 10, cols: 100);

      expect(screen.selectionText().text, before);
    },
  );
}
