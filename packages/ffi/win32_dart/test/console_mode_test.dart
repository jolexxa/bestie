import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

/// A change that reported [mode] as the mode it found.
Matcher changedFrom(int mode) => isA<ConsoleModeChangeSucceeded>().having(
  (result) => result.originalMode,
  'originalMode',
  mode,
);

/// A change [function] refused.
Matcher changeRefusedBy(String function) =>
    isA<ConsoleModeChangeFailed>().having(
      (result) => result.failure.function,
      'failure.function',
      function,
    );

/// A restore [function] refused.
Matcher restoreRefusedBy(String function) =>
    isA<ConsoleModeRestoreFailed>().having(
      (result) => result.failure.function,
      'failure.function',
      function,
    );

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late ConsoleMode console;

  setUp(() {
    bindings = MockWindowsBindings();
    console = ConsoleMode(bindings);
    when(
      () => bindings.GetStdHandle(any()),
    ).thenReturn(Pointer<Void>.fromAddress(0x1a0));
    when(() => bindings.GetLastError()).thenReturn(6);
    whenFormatMessage(bindings, 'The handle is invalid.');
  });

  group('ConsoleMode.clearBits', () {
    test('clears only the requested bits and reports the mode as it was', () {
      whenConsoleMode(bindings, ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT);
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(1);

      final result = console.clearBits(
        STD_INPUT_HANDLE,
        ENABLE_PROCESSED_INPUT,
      );

      expect(
        result,
        changedFrom(ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT),
      );
      verify(
        () => bindings.SetConsoleMode(any(), ENABLE_LINE_INPUT),
      ).called(1);
    });

    test('fails when there is no console handle', () {
      when(
        () => bindings.GetStdHandle(any()),
      ).thenReturn(Pointer<Void>.fromAddress(-1));

      final result = console.clearBits(STD_INPUT_HANDLE, 1);

      expect(result, changeRefusedBy('GetStdHandle'));
      verifyNever(() => bindings.GetConsoleMode(any(), any()));
    });

    test('fails when the mode cannot be read', () {
      when(() => bindings.GetConsoleMode(any(), any())).thenReturn(0);

      final result = console.clearBits(STD_INPUT_HANDLE, 1);

      expect(result, changeRefusedBy('GetConsoleMode'));
      verifyNever(() => bindings.SetConsoleMode(any(), any()));
    });

    test('fails when the mode cannot be written', () {
      whenConsoleMode(bindings, ENABLE_PROCESSED_INPUT);
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(0);

      expect(
        console.clearBits(STD_INPUT_HANDLE, 1),
        changeRefusedBy('SetConsoleMode'),
      );
    });
  });

  group('ConsoleMode.setBits', () {
    test('adds the requested bits and reports the mode as it was', () {
      whenConsoleMode(bindings, ENABLE_PROCESSED_INPUT);
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(1);

      final result = console.setBits(
        STD_OUTPUT_HANDLE,
        ENABLE_VIRTUAL_TERMINAL_PROCESSING,
      );

      expect(result, changedFrom(ENABLE_PROCESSED_INPUT));
      verify(
        () => bindings.SetConsoleMode(
          any(),
          ENABLE_PROCESSED_INPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING,
        ),
      ).called(1);
    });

    test('leaves a mode that already has the bits alone', () {
      whenConsoleMode(bindings, ENABLE_VIRTUAL_TERMINAL_PROCESSING);
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(1);

      console.setBits(STD_OUTPUT_HANDLE, ENABLE_VIRTUAL_TERMINAL_PROCESSING);

      verify(
        () => bindings.SetConsoleMode(
          any(),
          ENABLE_VIRTUAL_TERMINAL_PROCESSING,
        ),
      ).called(1);
    });

    test('fails when the mode cannot be written', () {
      whenConsoleMode(bindings, 0);
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(0);

      expect(
        console.setBits(STD_OUTPUT_HANDLE, 1),
        changeRefusedBy('SetConsoleMode'),
      );
    });
  });

  group('ConsoleMode.restore', () {
    test('writes the mode back', () {
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(1);

      final result = console.restore(STD_INPUT_HANDLE, ENABLE_LINE_INPUT);

      expect(result, isA<ConsoleModeRestoreSucceeded>());
      verify(
        () => bindings.SetConsoleMode(any(), ENABLE_LINE_INPUT),
      ).called(1);
    });

    test('fails when there is no console handle', () {
      when(
        () => bindings.GetStdHandle(any()),
      ).thenReturn(Pointer<Void>.fromAddress(0));

      expect(
        console.restore(STD_INPUT_HANDLE, 0),
        restoreRefusedBy('GetStdHandle'),
      );
    });

    test('fails when the mode cannot be written', () {
      when(() => bindings.SetConsoleMode(any(), any())).thenReturn(0);

      expect(
        console.restore(STD_INPUT_HANDLE, 0),
        restoreRefusedBy('SetConsoleMode'),
      );
    });
  });
}
