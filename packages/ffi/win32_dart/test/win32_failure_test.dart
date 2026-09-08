import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

void main() {
  setUpAll(registerPointerFallbacks);

  group('Win32Failure.fromLastError', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
      when(() => bindings.GetLastError()).thenReturn(3);
    });

    test('names the code with FormatMessageW', () {
      whenFormatMessage(bindings, 'The system cannot find the path.\r\n');

      final failure = Win32Failure.fromLastError(bindings, 'CreateFileW');

      expect(failure.function, 'CreateFileW');
      expect(failure.code, 3);
      expect(failure.channel, Win32ErrorChannel.lastError);
      expect(failure.message, 'The system cannot find the path.');
    });

    test('falls back to the bare code when FormatMessageW writes nothing', () {
      when(
        () => bindings.FormatMessageW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(0);

      final failure = Win32Failure.fromLastError(bindings, 'CreateFileW');

      expect(failure.message, 'error 3');
    });

    test('toString reports the channel as a Win32 error', () {
      whenFormatMessage(bindings, 'Access is denied.');

      expect(
        Win32Failure.fromLastError(bindings, 'CreateFileW').toString(),
        'Win32Failure(CreateFileW, error=3): Access is denied.',
      );
    });
  });

  group('Win32Failure.fromCrtErrno', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
    });

    test('names the errno with strerror_s', () {
      whenGetErrno(bindings, 9);
      whenStrerror(bindings, 'Bad file descriptor');

      final failure = Win32Failure.fromCrtErrno(bindings, '_dup2');

      expect(failure.code, 9);
      expect(failure.channel, Win32ErrorChannel.crtErrno);
      expect(failure.message, 'Bad file descriptor');
    });

    test('reports no code when _get_errno itself fails', () {
      when(() => bindings.get_errno(any())).thenReturn(22);
      whenStrerror(bindings, 'No error');

      expect(Win32Failure.fromCrtErrno(bindings, '_dup2').code, 0);
    });

    test('falls back to the bare errno when strerror_s fails', () {
      whenGetErrno(bindings, 9);
      when(
        () => bindings.strerror_s(any(), any(), any()),
      ).thenReturn(22);

      expect(
        Win32Failure.fromCrtErrno(bindings, '_dup2').message,
        'errno 9',
      );
    });

    test('toString reports the channel as an errno', () {
      whenGetErrno(bindings, 9);
      whenStrerror(bindings, 'Bad file descriptor');

      expect(
        Win32Failure.fromCrtErrno(bindings, '_dup2').toString(),
        'Win32Failure(_dup2, errno=9): Bad file descriptor',
      );
    });
  });

  test('Win32Failure.withoutCode omits any code from toString', () {
    const failure = Win32Failure.withoutCode('_write', 'descriptor is closed');

    expect(failure.code, 0);
    expect(failure.channel, Win32ErrorChannel.none);
    expect(failure.toString(), 'Win32Failure(_write): descriptor is closed');
  });
}
