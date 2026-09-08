import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late CrtFd fd;

  setUp(() {
    bindings = MockWindowsBindings();
    fd = CrtFd(7, bindings);
    whenGetErrno(bindings, 9);
    whenStrerror(bindings, 'Bad file descriptor');
  });

  group('CrtFd.write', () {
    test('hands the bytes to _write and reports the count', () {
      late List<int> written;
      when(() => bindings.write(any(), any(), any())).thenAnswer((invocation) {
        final buffer = invocation.positionalArguments[1] as Pointer<Void>;
        final length = invocation.positionalArguments[2] as int;
        written = buffer.cast<Uint8>().asTypedList(length).toList();
        return length;
      });

      final result = fd.write(const [104, 105]);

      expect(result, isA<CrtWriteSucceeded>());
      expect((result as CrtWriteSucceeded).bytesWritten, 2);
      expect(written, const [104, 105]);
      verify(() => bindings.write(7, any(), 2)).called(1);
    });

    test('reports a short write honestly', () {
      when(() => bindings.write(any(), any(), any())).thenReturn(1);

      final result = fd.write(const [104, 105]);

      expect((result as CrtWriteSucceeded).bytesWritten, 1);
    });

    test('surfaces a negative return as the CRT errno', () {
      when(() => bindings.write(any(), any(), any())).thenReturn(-1);

      final result = fd.write(const [104]);

      expect(result, isA<CrtWriteFailed>());
      final failure = (result as CrtWriteFailed).failure;
      expect(failure.channel, Win32ErrorChannel.crtErrno);
      expect(failure.code, 9);
    });

    test('short-circuits an empty write without touching the CRT', () {
      final result = fd.write(const []);

      expect((result as CrtWriteSucceeded).bytesWritten, 0);
      verifyNever(() => bindings.write(any(), any(), any()));
    });

    test('refuses to write to a closed descriptor', () {
      when(() => bindings.close(any())).thenReturn(0);
      fd.close();

      final result = fd.write(const [104]);

      expect(result, isA<CrtWriteFailed>());
      expect(
        (result as CrtWriteFailed).failure.channel,
        Win32ErrorChannel.none,
      );
      verifyNever(() => bindings.write(any(), any(), any()));
    });
  });

  group('CrtFd.close', () {
    test('closes the descriptor', () {
      when(() => bindings.close(any())).thenReturn(0);

      expect(fd.close(), isA<CrtCloseSucceeded>());
      expect(fd.isClosed, isTrue);
      verify(() => bindings.close(7)).called(1);
    });

    test('closing twice does not close the descriptor twice', () {
      when(() => bindings.close(any())).thenReturn(0);

      fd.close();
      expect(fd.close(), isA<CrtCloseSucceeded>());

      verify(() => bindings.close(7)).called(1);
    });

    test('surfaces a non-zero return as the CRT errno', () {
      when(() => bindings.close(any())).thenReturn(-1);

      final result = fd.close();

      expect(result, isA<CrtCloseFailed>());
      expect((result as CrtCloseFailed).failure.code, 9);
      expect(fd.isClosed, isFalse);
    });
  });
}
