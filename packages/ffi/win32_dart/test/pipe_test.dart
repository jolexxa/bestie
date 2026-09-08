import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;

  /// Stubs `CreatePipe` to hand back [read] / [write] as the two ends.
  void whenCreatePipe({int read = 0x10, int write = 0x20}) {
    when(() => bindings.CreatePipe(any(), any(), any(), any())).thenAnswer((
      invocation,
    ) {
      (invocation.positionalArguments[0] as Pointer<HANDLE>).value =
          Pointer<Void>.fromAddress(read);
      (invocation.positionalArguments[1] as Pointer<HANDLE>).value =
          Pointer<Void>.fromAddress(write);
      return 1;
    });
  }

  setUp(() {
    bindings = MockWindowsBindings();
    whenCreatePipe();
    when(() => bindings.CloseHandle(any())).thenReturn(1);
    when(() => bindings.GetLastError()).thenReturn(5);
    whenFormatMessage(bindings, 'Access is denied.');
  });

  Pipe openPipe() => (Pipes(bindings).open() as PipeOpenSucceeded).pipe;

  group('Pipe.open', () {
    test('creates a private pipe and exposes both ends', () {
      final result = Pipes(bindings).open();

      expect(result, isA<PipeOpenSucceeded>());
      final pipe = (result as PipeOpenSucceeded).pipe;
      expect(pipe.readEnd.address, 0x10);
      expect(pipe.writeEnd.address, 0x20);
      // A ConPTY pipe travels via the attribute list, so it stays private.
      verify(() => bindings.CreatePipe(any(), any(), nullptr, 0)).called(1);
    });

    test('creates inheritable ends when asked', () {
      // `Pipes.open` frees the SECURITY_ATTRIBUTES it allocates before
      // returning, so bInheritHandle must be read from the mock's
      // thenAnswer while the pointer is still live, not from a captured
      // pointer afterward.
      int? capturedInheritHandle;
      when(() => bindings.CreatePipe(any(), any(), any(), any())).thenAnswer((
        invocation,
      ) {
        (invocation.positionalArguments[0] as Pointer<HANDLE>).value =
            Pointer<Void>.fromAddress(0x10);
        (invocation.positionalArguments[1] as Pointer<HANDLE>).value =
            Pointer<Void>.fromAddress(0x20);
        final security =
            invocation.positionalArguments[2] as Pointer<SECURITY_ATTRIBUTES>;
        expect(security, isNot(nullptr));
        capturedInheritHandle = security.ref.bInheritHandle;
        return 1;
      });

      Pipes(bindings).open(inheritable: true);

      expect(capturedInheritHandle, 1);
    });

    test('fails when the pipe cannot be created', () {
      when(() => bindings.CreatePipe(any(), any(), any(), any())).thenReturn(0);

      final result = Pipes(bindings).open();

      expect((result as PipeOpenFailed).failure.function, 'CreatePipe');
    });
  });

  group('Pipe.write', () {
    /// Stubs `WriteFile` to report [written] bytes.
    void whenWriteFile(int written) {
      when(
        () => bindings.WriteFile(any(), any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        (invocation.positionalArguments[3] as Pointer<UnsignedLong>).value =
            written;
        return 1;
      });
    }

    test('writes bytes to the write end', () {
      whenWriteFile(3);

      final result = openPipe().write([1, 2, 3]);

      expect((result as PipeWriteSucceeded).bytesWritten, 3);
      verify(
        () => bindings.WriteFile(any(), any(), 3, any(), nullptr),
      ).called(1);
    });

    test('writes nothing for empty input', () {
      final result = openPipe().write(const []);

      expect((result as PipeWriteSucceeded).bytesWritten, 0);
      verifyNever(() => bindings.WriteFile(any(), any(), any(), any(), any()));
    });

    test('fails when the write is refused', () {
      when(
        () => bindings.WriteFile(any(), any(), any(), any(), any()),
      ).thenReturn(0);

      final result = openPipe().write([1]);

      expect((result as PipeWriteFailed).failure.function, 'WriteFile');
    });

    test('refuses once the write end is closed', () {
      final pipe = openPipe()..closeWriteEnd();

      final result = pipe.write([1]);

      final failure = (result as PipeWriteFailed).failure;
      expect(failure.channel, Win32ErrorChannel.none);
      expect(failure.message, 'pipe write end is closed');
      verifyNever(() => bindings.WriteFile(any(), any(), any(), any(), any()));
    });
  });

  group('Pipe.close', () {
    test('closes the read end exactly once', () {
      openPipe()
        ..closeReadEnd()
        ..closeReadEnd();

      verify(
        () => bindings.CloseHandle(
          any(that: predicate<HANDLE>((h) => h.address == 0x10)),
        ),
      ).called(1);
    });

    test('closes the write end exactly once', () {
      openPipe()
        ..closeWriteEnd()
        ..closeWriteEnd();

      verify(
        () => bindings.CloseHandle(
          any(that: predicate<HANDLE>((h) => h.address == 0x20)),
        ),
      ).called(1);
    });

    test('closes whichever ends remain open', () {
      openPipe().close();

      verify(() => bindings.CloseHandle(any())).called(2);
    });

    test('leaves an already-closed end alone', () {
      openPipe()
        ..closeReadEnd()
        ..close();

      verify(() => bindings.CloseHandle(any())).called(2);
    });
  });
}
