@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PosixFd', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('posix_fd_test_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('open + write + close round-trips a small file', () {
      final path = p.join(tmpDir.path, 'roundtrip.txt');
      final opened = posixFd.open(path, oWronly | oCreat | oTrunc);
      expect(opened, isA<FdOpenSucceeded>());
      final fd = (opened as FdOpenSucceeded).fd;

      final wrote = posixFd.write(fd, 'hello\n'.codeUnits);
      expect(wrote, isA<FdWriteSucceeded>());
      expect((wrote as FdWriteSucceeded).bytesWritten, 6);

      final closed = posixFd.close(fd);
      expect(closed, isA<FdCloseSucceeded>());

      expect(File(path).readAsStringSync(), 'hello\n');
    });

    test('write of empty bytes succeeds with zero bytesWritten', () {
      final path = p.join(tmpDir.path, 'empty.txt');
      final fd =
          (posixFd.open(path, oWronly | oCreat | oTrunc) as FdOpenSucceeded).fd;
      addTearDown(() => posixFd.close(fd));

      final wrote = posixFd.write(fd, const []);
      expect(wrote, isA<FdWriteSucceeded>());
      expect((wrote as FdWriteSucceeded).bytesWritten, 0);
    });

    test('open on a non-creatable path returns FdOpenFailed', () {
      // Read-only flags on a path that doesn't exist — open(2) fails
      // with ENOENT.
      final missing = p.join(tmpDir.path, 'definitely_missing');
      final result = posixFd.open(missing, oRdonly);
      expect(result, isA<FdOpenFailed>());
      expect((result as FdOpenFailed).failure.function, 'open');
    });

    test('close on a bogus fd returns FdCloseFailed', () {
      final result = posixFd.close(-1);
      expect(result, isA<FdCloseFailed>());
      expect((result as FdCloseFailed).failure.function, 'close');
    });

    test('dup duplicates a real fd', () {
      final path = p.join(tmpDir.path, 'dup_src.txt');
      final srcFd =
          (posixFd.open(path, oWronly | oCreat | oTrunc) as FdOpenSucceeded).fd;
      addTearDown(() => posixFd.close(srcFd));

      final duped = posixFd.dup(srcFd);
      expect(duped, isA<FdDupSucceeded>());
      final newFd = (duped as FdDupSucceeded).fd;
      expect(newFd, isNot(srcFd));
      addTearDown(() => posixFd.close(newFd));
    });

    test('dup on a bogus fd returns FdDupFailed', () {
      final result = posixFd.dup(-1);
      expect(result, isA<FdDupFailed>());
      expect((result as FdDupFailed).failure.function, 'dup');
    });

    test('read returns the file bytes then EOF', () {
      final path = p.join(tmpDir.path, 'read_src.txt');
      File(path).writeAsBytesSync('hi\n'.codeUnits);
      final fd = (posixFd.open(path, oRdonly) as FdOpenSucceeded).fd;
      addTearDown(() => posixFd.close(fd));

      final first = posixFd.read(fd, 16);
      expect(first, isA<FdReadSucceeded>());
      expect((first as FdReadSucceeded).bytes, 'hi\n'.codeUnits);

      // Second read at EOF yields an empty (but successful) result.
      final atEof = posixFd.read(fd, 16);
      expect(atEof, isA<FdReadSucceeded>());
      expect((atEof as FdReadSucceeded).bytes, isEmpty);
    });

    test('read with non-positive maxBytes succeeds with no bytes', () {
      final path = p.join(tmpDir.path, 'read_zero.txt');
      File(path).writeAsBytesSync('data'.codeUnits);
      final fd = (posixFd.open(path, oRdonly) as FdOpenSucceeded).fd;
      addTearDown(() => posixFd.close(fd));

      final result = posixFd.read(fd, 0);
      expect(result, isA<FdReadSucceeded>());
      expect((result as FdReadSucceeded).bytes, isEmpty);
    });

    test('read on a bogus fd returns FdReadFailed', () {
      final result = posixFd.read(-1, 16);
      expect(result, isA<FdReadFailed>());
      expect((result as FdReadFailed).failure.function, 'read');
    });

    test('dup2 redirects one fd onto another', () {
      final srcPath = p.join(tmpDir.path, 'dup2_src.txt');
      final dstPath = p.join(tmpDir.path, 'dup2_dst.txt');
      final srcFd =
          (posixFd.open(srcPath, oWronly | oCreat | oTrunc) as FdOpenSucceeded)
              .fd;
      final dstFd =
          (posixFd.open(dstPath, oWronly | oCreat | oTrunc) as FdOpenSucceeded)
              .fd;
      addTearDown(() => posixFd.close(srcFd));

      final result = posixFd.dup2(srcFd, dstFd);
      expect(result, isA<FdDup2Succeeded>());
      expect((result as FdDup2Succeeded).fd, dstFd);

      // Writes to dstFd now land in the src file.
      posixFd
        ..write(dstFd, 'via-dup2'.codeUnits)
        ..close(dstFd);
      expect(File(srcPath).readAsStringSync(), 'via-dup2');
    });

    test('dup2 on a bogus source returns FdDup2Failed', () {
      final result = posixFd.dup2(-1, 1);
      expect(result, isA<FdDup2Failed>());
      expect((result as FdDup2Failed).failure.function, 'dup2');
    });

    test('write on a bogus fd returns FdWriteFailed', () {
      final result = posixFd.write(-1, 'x'.codeUnits);
      expect(result, isA<FdWriteFailed>());
      expect((result as FdWriteFailed).failure.function, 'write');
    });
  });
}
