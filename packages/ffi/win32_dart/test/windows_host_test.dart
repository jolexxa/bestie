@TestOn('windows')
library;

import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:win32_dart/test_support.dart';
import 'package:win32_dart/win32_dart.dart';

/// A handle the OS will always refuse.
final _deadHandle = Win32Handle(Pointer<Void>.fromAddress(0));

void main() {
  group('the host answers queries', () {
    test('physical memory is non-zero and availability is bounded by it', () {
      final result = MemoryQuery(win32).status();

      expect(result, isA<MemoryStatusSucceeded>());
      final status = (result as MemoryStatusSucceeded).status;
      expect(status.totalBytes, greaterThan(0));
      expect(status.availableBytes, greaterThan(0));
      expect(status.availableBytes, lessThanOrEqualTo(status.totalBytes));
    });

    test('the processor count is plausible', () {
      final result = ProcessorQuery(win32).activeCount();

      expect(result, isA<ProcessorCountSucceeded>());
      expect(
        (result as ProcessorCountSucceeded).count,
        inInclusiveRange(1, 512),
      );
    });

    test('free space is reported for the volume holding a real directory', () {
      final result = DiskQuery(win32).space(Directory.systemTemp.path);

      expect(result, isA<DiskSpaceSucceeded>());
      final space = (result as DiskSpaceSucceeded).space;
      expect(space.totalBytes, greaterThan(0));
      expect(space.availableBytes, lessThanOrEqualTo(space.totalBytes));
    });

    test('a path on no volume fails rather than reporting zero', () {
      final result = DiskQuery(win32).space(r'\\?\nope\nope');

      expect(result, isA<DiskSpaceFailed>());
      expect((result as DiskSpaceFailed).failure.code, isNot(0));
    });
  });

  group('hardlinks', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('win32_hardlink_');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('a created hardlink shares the target file contents', () {
      final target = p.join(directory.path, 'coreutils.exe');
      final link = p.join(directory.path, 'ls.exe');
      File(target).writeAsStringSync('multicall');

      final result = HardLinkQuery(win32).create(
        linkPath: link,
        targetPath: target,
      );

      expect(result, isA<HardLinkSucceeded>());
      expect(File(link).readAsStringSync(), 'multicall');
    });

    test('linking onto an existing name fails rather than clobbering', () {
      final target = p.join(directory.path, 'coreutils.exe');
      final link = p.join(directory.path, 'ls.exe');
      File(target).writeAsStringSync('multicall');
      File(link).writeAsStringSync('occupied');

      final result = HardLinkQuery(win32).create(
        linkPath: link,
        targetPath: target,
      );

      expect(result, isA<HardLinkFailed>());
      expect((result as HardLinkFailed).failure.code, isNot(0));
    });
  });

  // MSDN warns that opening the clipboard with a NULL owner makes
  // SetClipboardData fail. That applies to delayed rendering, not to a real
  // block — this is what settles it on a real desktop.
  test('the clipboard accepts text from a session with no owner window', () {
    final opened = Clipboard(win32).open();
    expect(opened, isA<ClipboardOpenSucceeded>());
    final session = (opened as ClipboardOpenSucceeded).session;

    final wrote = session.writeUnicodeText('cow 🐄');
    final closed = session.close();

    expect(wrote, isA<ClipboardWriteSucceeded>());
    expect(closed, isA<ClipboardCloseSucceeded>());
  });

  test('the stderr redirect captures descriptor 2 and reverts', () {
    final directory = Directory.systemTemp.createTempSync('win32_redirect_');
    final logPath = p.join(directory.path, 'native.log');

    try {
      final redirected = StdioRedirect(win32).redirectStderr(logPath);
      expect(redirected, isA<StderrRedirectSucceeded>());
      final redirection = (redirected as StderrRedirectSucceeded).redirection;

      // The descriptor the log handle was adopted by is already closed by
      // now, so this also proves descriptor 2 holds a duplicate of its own.
      final wrote = CrtFd(2, win32).write('captured\n'.codeUnits);
      final restored = redirection.revert();

      expect(wrote, isA<CrtWriteSucceeded>());
      expect((wrote as CrtWriteSucceeded).bytesWritten, 9);
      expect(restored, isA<StderrRestoreSucceeded>());
      expect(File(logPath).readAsStringSync(), contains('captured'));
      expect(redirection.savedStderr.isClosed, isTrue);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  // Symbol resolution walks the DLLs in order and cannot be mocked. The
  // AppContainer calls live in userenv.dll, which is the newest entry in
  // that list — if it were missing, every lookup below would throw.
  group('the security surface resolves on this host', () {
    for (final symbol in const [
      'CreateAppContainerProfile',
      'DeriveAppContainerSidFromAppContainerName',
      'DeleteAppContainerProfile',
      'ConvertStringSidToSidW',
      'ConvertSidToStringSidW',
      'GetNamedSecurityInfoW',
      'SetEntriesInAclW',
      'SetNamedSecurityInfoW',
      'FreeSid',
      'LocalFree',
    ]) {
      test(symbol, () => expect(win32Provides(symbol), isTrue));
    }
  });

  // Opening a DLL cannot be mocked, so the shipped one is opened for real.
  // This is the check that catches a version bump renaming an export, or an
  // install that has lost half the pair.
  group('the console host bestie ships', () {
    test('opens and exports every entry point', () async {
      // The locator returns null unless conpty.dll and the OpenConsole.exe it
      // launches are both installed, so this covers the pair as well.
      final library = await const RepoConsoleHostLocator().locate();
      expect(
        library,
        isNotNull,
        reason:
            'Console host not installed. Run '
            '`dart tool/download_openconsole_assets.dart` from the repo root.',
      );

      final result = const ConptyLibraries().open(library!);

      expect(
        result,
        isA<ConptyOpenSucceeded>(),
        reason: result is ConptyOpenFailed ? result.reason : null,
      );
    });
  });

  // The isolate-backed helpers can only be exercised by really spawning one,
  // so this is the single place that does. A handle the OS refuses reaches
  // each loop's exit path immediately.
  group('the isolate-backed helpers reach the live surface', () {
    test('a read loop on a refused handle closes its stream', () async {
      final loop = const ReadLoops().start(_deadHandle);

      // A failed ReadFile is indistinguishable from EOF, and ends the stream
      // either way.
      expect(await loop.stream.toList(), isEmpty);
      await loop.close();
    });

    test('a read loop forwards what is written to the pipe', () async {
      final pipe = (Pipes(win32).open() as PipeOpenSucceeded).pipe;
      final loop = const ReadLoops().start(pipe.readEnd);

      pipe.write(const [104, 105]);
      final first = await loop.stream.first;
      // Unblock the isolate before killing it: a kill is only delivered
      // between messages, so one parked in ReadFile would outlive the test
      // and wedge VM shutdown.
      pipe.closeWriteEnd();

      expect(first, const [104, 105]);
      await loop.close();
      pipe.close();
    });

    test('closing before the isolate reports still completes its stream', () {
      // The refused handle keeps this off a blocking read, and spawning an
      // isolate takes long enough that close always wins the race.
      final loop = const ReadLoops().start(_deadHandle);
      final drained = loop.stream.toList();

      return loop.close().then(
        (_) => expectLater(drained, completion(isEmpty)),
      );
    });

    test('a wait on a refused handle reports no exit code', () async {
      final waiter = const ExitWaiters().start(_deadHandle);

      expect(await waiter.exitCode, isNull);
      await waiter.close();
    });
  });
}
