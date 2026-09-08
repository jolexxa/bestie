import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

class _MockFdBindings extends Mock implements FdBindings {}

void main() {
  late _MockFdBindings bindings;
  late PosixFd fd;

  setUp(() {
    bindings = _MockFdBindings();
    fd = PosixFd(bindings: bindings);
    registerFallbackValue(Pointer<Void>.fromAddress(0));
  });

  group('PosixFd surfaces failures as sealed results', () {
    test('dup returns FdDupFailed on a negative return', () {
      when(() => bindings.dup(any())).thenReturn(-1);

      expect(fd.dup(3), isA<FdDupFailed>());
    });

    test('dup2 returns FdDup2Failed on a negative return', () {
      when(() => bindings.dup2(any(), any())).thenReturn(-1);

      expect(fd.dup2(3, 4), isA<FdDup2Failed>());
    });

    test('close returns FdCloseFailed on a negative return', () {
      when(() => bindings.close(any())).thenReturn(-1);

      expect(fd.close(3), isA<FdCloseFailed>());
    });

    test('open returns FdOpenFailed on a negative return', () {
      when(() => bindings.openMode(any(), any(), any())).thenReturn(-1);

      expect(fd.open('/nope', 0), isA<FdOpenFailed>());
    });

    test('write returns FdWriteFailed on a negative return', () {
      when(
        () => bindings.write(any(), any(), any()),
      ).thenReturn(-1);

      expect(fd.write(3, [1, 2, 3]), isA<FdWriteFailed>());
    });

    test('read returns FdReadFailed on a negative return', () {
      when(() => bindings.read(any(), any(), any())).thenReturn(-1);

      expect(fd.read(3, 16), isA<FdReadFailed>());
    });
  });

  group('PosixFd short-circuits without touching libc', () {
    test('write of an empty list reports zero bytes written', () {
      final result = fd.write(3, const []);

      expect(result, isA<FdWriteSucceeded>());
      expect((result as FdWriteSucceeded).bytesWritten, 0);
      verifyNever(() => bindings.write(any(), any(), any()));
    });

    test('read of a non-positive length reports EOF', () {
      final result = fd.read(3, 0);

      expect(result, isA<FdReadSucceeded>());
      expect((result as FdReadSucceeded).bytes, isEmpty);
      verifyNever(() => bindings.read(any(), any(), any()));
    });
  });

  test('a successful dup reports the new descriptor', () {
    when(() => bindings.dup(3)).thenReturn(7);

    final result = fd.dup(3);

    expect(result, isA<FdDupSucceeded>());
    expect((result as FdDupSucceeded).fd, 7);
  });
}
