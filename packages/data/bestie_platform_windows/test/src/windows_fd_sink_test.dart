import 'dart:convert';

import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockCrtFd fd;
  late List<List<int>> written;

  /// Everything the sink handed the descriptor, decoded.
  String text() => written.map(utf8.decode).join();

  setUp(() {
    fd = MockCrtFd();
    written = [];
    when(() => fd.write(any())).thenAnswer((invocation) {
      final bytes = invocation.positionalArguments[0] as List<int>;
      written.add(bytes);
      return CrtWriteSucceeded(bytes.length);
    });
    when(() => fd.close()).thenReturn(const CrtCloseSucceeded());
  });

  group('writes reach the descriptor', () {
    test('add passes bytes through untouched', () {
      ioSinkForCrtFd(fd).add([0x63, 0x6f, 0x77]);

      expect(written, [
        [0x63, 0x6f, 0x77],
      ]);
    });

    test('write and writeln encode as UTF-8', () {
      ioSinkForCrtFd(fd)
        ..write('cow 🐄')
        ..writeln('moo');

      expect(text(), 'cow 🐄moo\n');
    });

    test('writeAll separates only between objects', () {
      ioSinkForCrtFd(fd).writeAll([1, 2, 3], '-');

      expect(text(), '1-2-3');
    });

    test('writeCharCode writes the character', () {
      ioSinkForCrtFd(fd).writeCharCode(0x63);

      expect(text(), 'c');
    });

    test('addStream forwards every chunk', () async {
      await ioSinkForCrtFd(fd).addStream(
        Stream.fromIterable([
          [1],
          [2],
        ]),
      );

      expect(written, [
        [1],
        [2],
      ]);
    });

    test('the encoding is UTF-8 and settable', () {
      final sink = ioSinkForCrtFd(fd);

      expect(sink.encoding, utf8);
      sink.encoding = latin1;
      expect(sink.encoding, latin1);
    });

    test('flush completes without touching the descriptor', () async {
      await ioSinkForCrtFd(fd).flush();

      verifyNever(() => fd.write(any()));
    });

    test(
      'an error added by a caller is not the descriptor to report',
      () async {
        final sink = ioSinkForCrtFd(fd)..addError(StateError('ignored'));

        await expectLater(sink.close(), completes);
      },
    );
  });

  group('failures surface through done', () {
    test('a refused write completes done with the failure', () async {
      when(() => fd.write(any())).thenReturn(const CrtWriteFailed(failure));
      final sink = ioSinkForCrtFd(fd)..write('cow');

      await expectLater(
        sink.done,
        throwsA(
          isA<CrtFdSinkException>().having(
            (exception) => exception.failure,
            'failure',
            failure,
          ),
        ),
      );
    });

    test('nothing more is written after a failure', () async {
      when(() => fd.write(any())).thenReturn(const CrtWriteFailed(failure));
      final sink = ioSinkForCrtFd(fd)
        ..write('cow')
        ..write('cow');

      await expectLater(sink.done, throwsA(isA<CrtFdSinkException>()));
      verify(() => fd.write(any())).called(1);
    });

    test('the exception reads as the failure it carries', () {
      expect(const CrtFdSinkException(failure).toString(), failure.toString());
    });

    test('a refused close completes done with the failure', () async {
      when(() => fd.close()).thenReturn(const CrtCloseFailed(failure));
      final sink = ioSinkForCrtFd(fd);

      await expectLater(sink.close(), throwsA(isA<CrtFdSinkException>()));
    });

    test('closing twice keeps the first outcome', () async {
      final sink = ioSinkForCrtFd(fd);

      await sink.close();

      await expectLater(sink.close(), completes);
    });
  });
}
