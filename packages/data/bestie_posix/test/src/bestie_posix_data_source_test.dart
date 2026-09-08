import 'dart:io';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_posix/bestie_posix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

class _MockPosixFd extends Mock implements PosixFd {}

class _MockTermiosControl extends Mock implements TermiosControl {}

class _MockStdout extends Mock implements Stdout {}

class _MockStdin extends Mock implements Stdin {}

class _FakeSnapshot extends Fake implements TermiosSnapshot {}

class _FakePlatform extends Fake implements OSPlatform {}

/// `redirectStderr` has three failure branches, each with its own
/// cleanup, and none of them can be reached with real file descriptors —
/// `dup(2)` of stderr does not fail on demand. They were unreachable
/// while `PosixFd` was a class of statics over a global.
///
/// These run on any host: no libc symbol is resolved.
void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSnapshot());
  });

  late _MockPosixFd fd;
  late _MockTermiosControl termios;
  late _MockStdout out;
  late _MockStdin input;
  late BestiePosixDataSource dataSource;

  setUp(() {
    fd = _MockPosixFd();
    termios = _MockTermiosControl();
    out = _MockStdout();
    input = _MockStdin();
    when(() => out.hasTerminal).thenReturn(true);
    when(() => out.write(any())).thenReturn(null);
    when(() => input.hasTerminal).thenReturn(true);
    dataSource = BestiePosixDataSource(
      platform: _FakePlatform(),
      fdApi: fd,
      termios: termios,
      stdoutSink: out,
      stdinStream: input,
    );
  });

  group('redirectStderr', () {
    test('returns null and leaks nothing when dup fails', () {
      when(() => fd.dup(any())).thenReturn(
        FdDupFailed(PosixFailure.withoutErrno('dup', 'boom')),
      );

      expect(dataSource.redirectStderr(targetPath: '/tmp/x'), isNull);
      verifyNever(() => fd.close(any()));
    });

    test('closes the saved descriptor when opening the target fails', () {
      when(() => fd.dup(any())).thenReturn(const FdDupSucceeded(9));
      when(() => fd.open(any(), any())).thenReturn(
        FdOpenFailed(PosixFailure.withoutErrno('open', 'boom')),
      );
      when(() => fd.close(any())).thenReturn(const FdCloseSucceeded());

      expect(dataSource.redirectStderr(targetPath: '/tmp/x'), isNull);
      verify(() => fd.close(9)).called(1);
    });

    test('closes both descriptors when dup2 fails', () {
      when(() => fd.dup(any())).thenReturn(const FdDupSucceeded(9));
      when(() => fd.open(any(), any())).thenReturn(const FdOpenSucceeded(4));
      when(() => fd.dup2(any(), any())).thenReturn(
        FdDup2Failed(PosixFailure.withoutErrno('dup2', 'boom')),
      );
      when(() => fd.close(any())).thenReturn(const FdCloseSucceeded());

      expect(dataSource.redirectStderr(targetPath: '/tmp/x'), isNull);
      verify(() => fd.close(4)).called(1);
      verify(() => fd.close(9)).called(1);
    });

    test('on success closes the target fd and keeps the saved one open', () {
      when(() => fd.dup(any())).thenReturn(const FdDupSucceeded(9));
      when(() => fd.open(any(), any())).thenReturn(const FdOpenSucceeded(4));
      when(() => fd.dup2(any(), any())).thenReturn(const FdDup2Succeeded(2));
      when(() => fd.close(any())).thenReturn(const FdCloseSucceeded());

      final override = dataSource.redirectStderr(targetPath: '/tmp/x');

      expect(override, isNotNull);
      expect(override!.originalSink, isNotNull);
      verify(() => fd.close(4)).called(1);
      verifyNever(() => fd.close(9));
    });

    test('reverting restores fd 2 and releases the saved descriptor', () async {
      when(() => fd.dup(any())).thenReturn(const FdDupSucceeded(9));
      when(() => fd.open(any(), any())).thenReturn(const FdOpenSucceeded(4));
      when(() => fd.dup2(any(), any())).thenReturn(const FdDup2Succeeded(2));
      when(() => fd.close(any())).thenReturn(const FdCloseSucceeded());

      final override = dataSource.redirectStderr(targetPath: '/tmp/x')!;
      await override.revert();

      verify(() => fd.dup2(9, 2)).called(1);
      verify(() => fd.close(9)).called(1);
    });
  });

  group('setWindowTitle', () {
    test('does nothing when stdout is not a terminal', () {
      when(() => out.hasTerminal).thenReturn(false);

      expect(dataSource.setWindowTitle('cow'), isNull);
      verifyNever(() => out.write(any()));
    });

    test('pushes the title onto the terminal stack', () {
      expect(dataSource.setWindowTitle('cow'), isNotNull);

      verify(() => out.write('\x1b[22;0t\x1b]0;cow\x07')).called(1);
    });

    test('reverting pops the title it pushed', () async {
      final override = dataSource.setWindowTitle('cow')!;

      await override.revert();

      verify(() => out.write('\x1b[23;0t')).called(1);
    });
  });

  group('captureInput', () {
    /// The mapping is asserted through the failure return so no
    /// `TermiosSnapshot` has to be conjured — it is an opaque handle
    /// over a live termios struct and has no test-constructible form.
    void expectMasks({
      required Set<InputCapture> groups,
      required int iflag,
      required int lflag,
    }) {
      when(
        () => termios.clearFlags(
          any(),
          iflagMask: any(named: 'iflagMask'),
          lflagMask: any(named: 'lflagMask'),
        ),
      ).thenReturn(
        TermiosClearFlagsFailed(
          PosixFailure.withoutErrno('tcsetattr', 'boom'),
        ),
      );

      expect(dataSource.captureInput(groups), isNull);
      verify(
        () => termios.clearFlags(0, iflagMask: iflag, lflagMask: lflag),
      ).called(1);
    }

    test('returns null when asked to capture nothing', () {
      expect(dataSource.captureInput({}), isNull);
      verifyNever(
        () => termios.clearFlags(
          any(),
          iflagMask: any(named: 'iflagMask'),
          lflagMask: any(named: 'lflagMask'),
        ),
      );
    });

    test('does nothing when stdin is not a terminal', () {
      when(() => input.hasTerminal).thenReturn(false);

      expect(dataSource.captureInput({InputCapture.controlKeys}), isNull);
      verifyNever(
        () => termios.clearFlags(
          any(),
          iflagMask: any(named: 'iflagMask'),
          lflagMask: any(named: 'lflagMask'),
        ),
      );
    });

    test('controlKeys clears ISIG', () {
      expectMasks(
        groups: {InputCapture.controlKeys},
        iflag: 0,
        lflag: isigBit,
      );
    });

    test('editingKeys clears IEXTEN', () {
      expectMasks(
        groups: {InputCapture.editingKeys},
        iflag: 0,
        lflag: iextenBit,
      );
    });

    test('flowControl clears IXON, an input flag rather than a local one', () {
      expectMasks(
        groups: {InputCapture.flowControl},
        iflag: ixonBit,
        lflag: 0,
      );
    });

    test('every group at once accumulates into both masks', () {
      expectMasks(
        groups: InputCapture.values.toSet(),
        iflag: ixonBit,
        lflag: isigBit | iextenBit,
      );
    });

    test('returns an override carrying the pre-capture snapshot', () {
      final snapshot = _FakeSnapshot();
      when(
        () => termios.clearFlags(
          any(),
          iflagMask: any(named: 'iflagMask'),
          lflagMask: any(named: 'lflagMask'),
        ),
      ).thenReturn(TermiosClearFlagsSucceeded(snapshot));

      expect(dataSource.captureInput({InputCapture.controlKeys}), isNotNull);
    });

    test('reverting restores the terminal and releases the snapshot', () async {
      final snapshot = _FakeSnapshot();
      when(
        () => termios.clearFlags(
          any(),
          iflagMask: any(named: 'iflagMask'),
          lflagMask: any(named: 'lflagMask'),
        ),
      ).thenReturn(TermiosClearFlagsSucceeded(snapshot));
      when(() => termios.restore(any(), any())).thenReturn(
        const TermiosRestoreSucceeded(),
      );
      when(() => termios.freeSnapshot(any())).thenReturn(null);

      final override = dataSource.captureInput({InputCapture.controlKeys})!;
      await override.revert();

      // Freeing before restoring would hand libc a released struct.
      verifyInOrder([
        () => termios.restore(0, snapshot),
        () => termios.freeSnapshot(snapshot),
      ]);
    });
  });
}
