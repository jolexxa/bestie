import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

final _process = Pointer<Void>.fromAddress(0x9C);

void main() {
  late MockWindowsBindings bindings;

  setUpAll(registerPointerFallbacks);

  // What the call handed ShellExecuteExW, copied out while the native
  // strings are still alive — they are freed before `run` returns.
  late Map<String, Object> asked;

  setUp(() {
    bindings = MockWindowsBindings();
    when(() => bindings.ShellExecuteExW(any())).thenAnswer((invocation) {
      final info =
          (invocation.positionalArguments[0] as Pointer<SHELLEXECUTEINFOW>).ref;
      asked = {
        'verb': info.lpVerb.cast<Utf16>().toDartString(),
        'file': info.lpFile.cast<Utf16>().toDartString(),
        'parameters': info.lpParameters.cast<Utf16>().toDartString(),
        'show': info.nShow,
        'mask': info.fMask,
      };
      info.hProcess = _process;
      return 1;
    });
    when(() => bindings.WaitForSingleObject(any(), any())).thenReturn(0);
    when(() => bindings.GetExitCodeProcess(any(), any())).thenAnswer((
      invocation,
    ) {
      (invocation.positionalArguments[1] as Pointer<UnsignedLong>).value = 3;
      return 1;
    });
    when(() => bindings.CloseHandle(any())).thenReturn(1);
    whenFormatMessage(bindings, 'nope');
  });

  ElevationOutcome run() => Elevations(
    bindings,
  ).run(executable: r'C:\bestie.exe', arguments: const ['--grant', r'C:\']);

  test(
    'runs the program with the runas verb, hidden, and reports its exit',
    () {
      final outcome = run();

      expect(outcome, isA<ElevationCompleted>());
      expect((outcome as ElevationCompleted).exitCode, 3);
      expect(asked['verb'], 'runas');
      expect(asked['file'], r'C:\bestie.exe');
      expect(asked['parameters'], r'"--grant" "C:\\"');
      expect(asked['show'], SW_HIDE);
      expect((asked['mask']! as int) & SEE_MASK_NOCLOSEPROCESS, isNonZero);
      verify(() => bindings.WaitForSingleObject(_process, INFINITE)).called(1);
      verify(() => bindings.CloseHandle(_process)).called(1);
    },
  );

  test('is declined when the user says no at the prompt', () {
    when(() => bindings.ShellExecuteExW(any())).thenReturn(0);
    when(() => bindings.GetLastError()).thenReturn(ERROR_CANCELLED);

    expect(run(), isA<ElevationDeclined>());
    verifyNever(() => bindings.WaitForSingleObject(any(), any()));
  });

  test('fails when the program cannot be started', () {
    when(() => bindings.ShellExecuteExW(any())).thenReturn(0);
    when(() => bindings.GetLastError()).thenReturn(2);

    final outcome = run();

    expect(outcome, isA<ElevationFailed>());
    expect((outcome as ElevationFailed).failure.function, 'ShellExecuteExW');
  });

  test('fails, still closing the handle, when the wait fails', () {
    when(() => bindings.WaitForSingleObject(any(), any())).thenReturn(-1);
    when(() => bindings.GetLastError()).thenReturn(6);

    final outcome = run();

    expect(outcome, isA<ElevationFailed>());
    expect(
      (outcome as ElevationFailed).failure.function,
      'WaitForSingleObject',
    );
    verify(() => bindings.CloseHandle(_process)).called(1);
  });

  test('fails when the exit code cannot be read', () {
    when(() => bindings.GetExitCodeProcess(any(), any())).thenReturn(0);
    when(() => bindings.GetLastError()).thenReturn(6);

    final outcome = run();

    expect(outcome, isA<ElevationFailed>());
    expect((outcome as ElevationFailed).failure.function, 'GetExitCodeProcess');
  });

  group('commandLineOf', () {
    test('quotes every argument', () {
      expect(Elevations.commandLineOf(['a', 'b c']), '"a" "b c"');
    });

    test('doubles backslashes before a closing quote', () {
      expect(Elevations.commandLineOf([r'C:\Users\']), r'"C:\Users\\"');
    });

    test('leaves backslashes elsewhere alone', () {
      expect(Elevations.commandLineOf([r'C:\Users\x']), r'"C:\Users\x"');
    });

    test('escapes an embedded quote and the backslashes before it', () {
      expect(Elevations.commandLineOf(['say "hi"']), r'"say \"hi\""');
      expect(Elevations.commandLineOf([r'a\"b']), r'"a\\\"b"');
    });
  });
}
