import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockStdout extends Mock implements Stdout {}

void main() {
  group('currentHostWinsize', () {
    test('returns the value provided by the reader', () {
      final size = currentHostWinsize(
        reader: () => (rows: 42, cols: 120),
      );
      expect(size.rows, 42);
      expect(size.cols, 120);
    });

    test('falls back when the reader returns null', () {
      final size = currentHostWinsize(
        reader: () => null,
        fallbackRows: 30,
        fallbackCols: 100,
      );
      expect(size.rows, 30);
      expect(size.cols, 100);
    });

    test('default fallback is 24x80', () {
      final size = currentHostWinsize(reader: () => null);
      expect(size.rows, 24);
      expect(size.cols, 80);
    });
  });

  group('winsizeOf', () {
    test('reports the attached terminal dimensions', () {
      final out = _MockStdout();
      when(() => out.hasTerminal).thenReturn(true);
      when(() => out.terminalLines).thenReturn(50);
      when(() => out.terminalColumns).thenReturn(200);

      expect(winsizeOf(out), (rows: 50, cols: 200));
    });

    test('reports null when the stream is not a terminal', () {
      final out = _MockStdout();
      when(() => out.hasTerminal).thenReturn(false);

      expect(winsizeOf(out), isNull);
      verifyNever(() => out.terminalLines);
    });
  });

  group('defaultWinsizeReader', () {
    test('does not throw whether or not a terminal is attached', () {
      expect(defaultWinsizeReader, returnsNormally);
    });
  });
}
