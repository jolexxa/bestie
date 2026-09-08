import 'dart:convert';

import 'package:bestie_posix/src/native_fd_sink.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

class _MockPosixFd extends Mock implements PosixFd {}

const _failure = PosixFailure(
  function: 'write',
  errno: 9,
  message: 'Bad file descriptor',
);

/// The fd-backed sink exists so bestie can keep writing to a descriptor
/// after the original has been redirected. Its failure paths cannot be
/// provoked with real descriptors — `write(2)` to a live fd does not
/// fail on demand — so they are driven through a mocked [PosixFd].
///
/// These run on any host: no libc symbol is resolved.
void main() {
  late _MockPosixFd fd;

  setUp(() {
    fd = _MockPosixFd();
    when(() => fd.write(any(), any())).thenReturn(const FdWriteSucceeded(1));
    when(() => fd.close(any())).thenReturn(const FdCloseSucceeded());
  });

  List<int> captureWrite() =>
      verify(() => fd.write(7, captureAny())).captured.single as List<int>;

  group('writing', () {
    test('add forwards raw bytes to the descriptor untouched', () {
      ioSinkForFd(fd: 7, fdApi: fd).add([1, 2, 3]);

      expect(captureWrite(), [1, 2, 3]);
    });

    test('write encodes the object as utf8', () {
      ioSinkForFd(fd: 7, fdApi: fd).write('héllo');

      expect(captureWrite(), utf8.encode('héllo'));
    });

    test('writeln appends a newline', () {
      ioSinkForFd(fd: 7, fdApi: fd).writeln('done');

      expect(captureWrite(), utf8.encode('done\n'));
    });

    test('writeln with no argument writes just a newline', () {
      ioSinkForFd(fd: 7, fdApi: fd).writeln();

      expect(captureWrite(), utf8.encode('\n'));
    });

    test('writeCharCode writes the character, not the number', () {
      ioSinkForFd(fd: 7, fdApi: fd).writeCharCode(65);

      expect(captureWrite(), utf8.encode('A'));
    });

    test('writeAll separates only between objects', () {
      ioSinkForFd(fd: 7, fdApi: fd).writeAll([1, 2, 3], ', ');

      final written = verify(
        () => fd.write(7, captureAny()),
      ).captured.cast<List<int>>().expand((bytes) => bytes).toList();
      expect(utf8.decode(written), '1, 2, 3');
    });

    test('writeAll defaults to no separator', () {
      ioSinkForFd(fd: 7, fdApi: fd).writeAll(['a', 'b']);

      final written = verify(
        () => fd.write(7, captureAny()),
      ).captured.cast<List<int>>().expand((bytes) => bytes).toList();
      expect(utf8.decode(written), 'ab');
    });

    test('addStream forwards every chunk', () async {
      final sink = ioSinkForFd(fd: 7, fdApi: fd);

      await sink.addStream(
        Stream.fromIterable([
          [1],
          [2],
        ]),
      );

      final written = verify(
        () => fd.write(7, captureAny()),
      ).captured.cast<List<int>>();
      expect(written, [
        [1],
        [2],
      ]);
    });
  });

  group('write failure', () {
    test('surfaces the libc failure through done', () {
      when(() => fd.write(any(), any())).thenReturn(
        const FdWriteFailed(_failure),
      );
      final sink = ioSinkForFd(fd: 7, fdApi: fd)..add([1]);

      expect(
        sink.done,
        throwsA(
          isA<FdSinkException>().having((e) => e.failure, 'failure', _failure),
        ),
      );
    });

    test('stops writing once it has failed', () {
      when(() => fd.write(any(), any())).thenReturn(
        const FdWriteFailed(_failure),
      );
      final sink = ioSinkForFd(fd: 7, fdApi: fd)
        ..add([1])
        ..add([2])
        ..add([3]);

      // Only the first write reaches libc; a descriptor that has failed
      // is not written to again.
      verify(() => fd.write(7, any())).called(1);
      expect(sink.done, throwsA(isA<FdSinkException>()));
    });

    test('reports the first failure only, not each subsequent write', () {
      when(() => fd.write(any(), any())).thenReturn(
        const FdWriteFailed(_failure),
      );
      final sink = ioSinkForFd(fd: 7, fdApi: fd)
        ..add([1])
        ..add([2]);

      // Completing an already-completed completer would throw.
      expect(sink.done, throwsA(isA<FdSinkException>()));
    });
  });

  group('closing', () {
    test('closes the descriptor and completes done', () async {
      final sink = ioSinkForFd(fd: 7, fdApi: fd);

      await sink.close();

      verify(() => fd.close(7)).called(1);
    });

    test('surfaces a close failure through done', () {
      when(() => fd.close(any())).thenReturn(const FdCloseFailed(_failure));
      final sink = ioSinkForFd(fd: 7, fdApi: fd);

      expect(sink.close(), throwsA(isA<FdSinkException>()));
      expect(sink.done, throwsA(isA<FdSinkException>()));
    });

    test('keeps an earlier write failure when closing afterwards', () {
      when(() => fd.write(any(), any())).thenReturn(
        const FdWriteFailed(_failure),
      );
      final sink = ioSinkForFd(fd: 7, fdApi: fd)..add([1]);

      expect(sink.close(), throwsA(isA<FdSinkException>()));
    });

    test('closing twice does not complete done twice', () async {
      final sink = ioSinkForFd(fd: 7, fdApi: fd);

      await sink.close();
      await sink.close();

      verify(() => fd.close(7)).called(2);
    });
  });

  group('IOSink surface', () {
    test('flush resolves without touching the descriptor', () async {
      final sink = ioSinkForFd(fd: 7, fdApi: fd);

      await sink.flush();

      verifyNever(() => fd.write(any(), any()));
    });

    test('addError is swallowed rather than failing the sink', () async {
      final sink = ioSinkForFd(fd: 7, fdApi: fd)
        ..addError(Exception('ignored'));

      await sink.close();
    });

    test('encoding defaults to utf8 and is settable', () {
      final sink = ioSinkForFd(fd: 7, fdApi: fd);
      expect(sink.encoding, utf8);

      sink.encoding = latin1;

      expect(sink.encoding, latin1);
    });
  });

  test('FdSinkException reports the underlying libc failure', () {
    expect(
      const FdSinkException(_failure).toString(),
      contains('Bad file descriptor'),
    );
  });
}
