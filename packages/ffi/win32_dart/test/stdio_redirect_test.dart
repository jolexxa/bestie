import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

const _savedFd = 3;
const _logFd = 4;
final _fileHandle = Pointer<Void>.fromAddress(0x250);
final _duplicatedHandle = Pointer<Void>.fromAddress(0x260);
final _originalStdError = Pointer<Void>.fromAddress(0x1a0);

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late StdioRedirect redirect;

  setUp(() {
    bindings = MockWindowsBindings();
    redirect = StdioRedirect(bindings);

    when(() => bindings.dup(any())).thenReturn(_savedFd);
    when(
      () => bindings.CreateFileW(
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenReturn(_fileHandle);
    when(() => bindings.open_osfhandle(any(), any())).thenReturn(_logFd);
    when(() => bindings.dup2(any(), any())).thenReturn(0);
    when(() => bindings.close(any())).thenReturn(0);
    when(
      () => bindings.get_osfhandle(any()),
    ).thenReturn(_duplicatedHandle.address);
    when(() => bindings.GetStdHandle(any())).thenReturn(_originalStdError);
    when(() => bindings.SetStdHandle(any(), any())).thenReturn(1);
    when(() => bindings.CloseHandle(any())).thenReturn(1);

    when(() => bindings.GetLastError()).thenReturn(5);
    whenFormatMessage(bindings, 'Access is denied.');
    whenGetErrno(bindings, 9);
    whenStrerror(bindings, 'Bad file descriptor');
  });

  group('StdioRedirect.redirectStderr', () {
    test('redirects both layers and hands back the saved stderr', () {
      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect(result, isA<StderrRedirectSucceeded>());
      final redirection = (result as StderrRedirectSucceeded).redirection;
      expect(redirection.savedStderr.descriptor, _savedFd);
      verify(() => bindings.dup(2)).called(1);
      verify(() => bindings.dup2(_logFd, 2)).called(1);
      verify(() => bindings.close(_logFd)).called(1);
    });

    test('truncates the log and opens it for writing', () {
      late String path;
      when(
        () => bindings.CreateFileW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((invocation) {
        path = readWideString(
          invocation.positionalArguments[0] as Pointer<WChar>,
        );
        expect(invocation.positionalArguments[1], GENERIC_WRITE);
        expect(invocation.positionalArguments[4], CREATE_ALWAYS);
        return _fileHandle;
      });

      redirect.redirectStderr(r'C:\cow\native.log');

      expect(path, r'C:\cow\native.log');
    });

    test('publishes the handle descriptor 2 owns, not the one it adopted', () {
      redirect.redirectStderr(r'C:\cow\native.log');

      verify(() => bindings.get_osfhandle(2)).called(1);
      verify(
        () => bindings.SetStdHandle(STD_ERROR_HANDLE, _duplicatedHandle),
      ).called(1);
      verifyNever(
        () => bindings.SetStdHandle(STD_ERROR_HANDLE, _fileHandle),
      );
    });

    test('fails when the original stderr cannot be saved', () {
      when(() => bindings.dup(any())).thenReturn(-1);

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect((result as StderrRedirectFailed).failure.function, '_dup');
      verifyNever(
        () => bindings.CreateFileW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      );
    });

    test('releases the saved stderr when the log cannot be opened', () {
      when(
        () => bindings.CreateFileW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(Pointer<Void>.fromAddress(-1));

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect((result as StderrRedirectFailed).failure.function, 'CreateFileW');
      verify(() => bindings.close(_savedFd)).called(1);
    });

    test('closes the handle itself when no descriptor adopted it', () {
      when(() => bindings.open_osfhandle(any(), any())).thenReturn(-1);

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect(
        (result as StderrRedirectFailed).failure.function,
        '_open_osfhandle',
      );
      verify(() => bindings.CloseHandle(_fileHandle)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
    });

    test('releases both descriptors when stderr cannot be replaced', () {
      when(() => bindings.dup2(any(), any())).thenReturn(-1);

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect((result as StderrRedirectFailed).failure.function, '_dup2');
      verify(() => bindings.close(_logFd)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
      verifyNever(() => bindings.CloseHandle(any()));
    });

    test('restores stderr when the redirected handle cannot be read', () {
      when(() => bindings.get_osfhandle(any())).thenReturn(-2);

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect(
        (result as StderrRedirectFailed).failure.function,
        '_get_osfhandle',
      );
      verify(() => bindings.dup2(_savedFd, 2)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
    });

    test('restores stderr when the standard handle cannot be replaced', () {
      when(() => bindings.SetStdHandle(any(), any())).thenReturn(0);

      final result = redirect.redirectStderr(r'C:\cow\native.log');

      expect((result as StderrRedirectFailed).failure.function, 'SetStdHandle');
      verify(() => bindings.dup2(_savedFd, 2)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
    });
  });

  group('StderrRedirection.revert', () {
    late StderrRedirection redirection;

    setUp(() {
      final result =
          redirect.redirectStderr(r'C:\cow\native.log')
              as StderrRedirectSucceeded;
      redirection = result.redirection;
    });

    test('restores both layers and releases the saved stderr', () {
      final result = redirection.revert();

      expect(result, isA<StderrRestoreSucceeded>());
      verify(
        () => bindings.SetStdHandle(STD_ERROR_HANDLE, _originalStdError),
      ).called(1);
      verify(() => bindings.dup2(_savedFd, 2)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
      expect(redirection.savedStderr.isClosed, isTrue);
    });

    test('restores the remaining layers even after one fails', () {
      when(() => bindings.SetStdHandle(any(), any())).thenReturn(0);

      final result = redirection.revert();

      expect((result as StderrRestoreFailed).failure.function, 'SetStdHandle');
      verify(() => bindings.dup2(_savedFd, 2)).called(1);
      verify(() => bindings.close(_savedFd)).called(1);
    });

    test('reports a descriptor that cannot be restored', () {
      when(() => bindings.dup2(any(), any())).thenReturn(-1);

      final result = redirection.revert();

      expect((result as StderrRestoreFailed).failure.function, '_dup2');
    });

    test('reports a saved descriptor that cannot be released', () {
      when(() => bindings.close(any())).thenReturn(-1);

      final result = redirection.revert();

      expect((result as StderrRestoreFailed).failure.function, '_close');
    });
  });
}
