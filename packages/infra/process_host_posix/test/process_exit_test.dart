@TestOn('vm')
library;

import 'package:posix_dart/posix_dart.dart' show PosixFailure;
import 'package:posix_spawner/posix_spawner.dart'
    show PosixSupervisorExited, PosixSupervisorLost;
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:test/test.dart';

void main() {
  group('decodeWaitStatus', () {
    test('normal exit, code 0', () {
      expect(decodeWaitStatus(0), const ProcessExited(0));
    });

    test('normal exit, code 42', () {
      expect(decodeWaitStatus(42 << 8), const ProcessExited(42));
    });

    test('normal exit, code 255', () {
      expect(decodeWaitStatus(255 << 8), const ProcessExited(255));
    });

    test('signaled by SIGTERM (15)', () {
      expect(decodeWaitStatus(15), const ProcessSignaled(15));
    });

    test('signaled by SIGKILL (9)', () {
      expect(decodeWaitStatus(9), const ProcessSignaled(9));
    });

    test('stopped status (0x7f) decodes as unknown', () {
      expect(decodeWaitStatus(0x7f), const ProcessUnknown());
    });
  });

  group('processExitFromOutcome', () {
    test('decodes a reported exit status', () {
      final exit = processExitFromOutcome(
        const PosixSupervisorExited(targetPid: 1234, rawStatus: 7 << 8),
      );
      expect(exit, const ProcessExited(7));
    });

    test('decodes a reported signal status', () {
      final exit = processExitFromOutcome(
        const PosixSupervisorExited(targetPid: 1234, rawStatus: 9),
      );
      expect(exit, const ProcessSignaled(9));
    });

    test('maps a lost supervisor to ProcessSupervisorLost', () {
      final exit = processExitFromOutcome(const PosixSupervisorLost());
      expect(exit, const ProcessSupervisorLost());
    });
  });

  group('spawnFailureFrom', () {
    test('carries the libc function, errno and message across', () {
      final failure = spawnFailureFrom(
        PosixFailure.fromErrno('posix_spawnp', 2, 'No such file or directory'),
      );

      expect(
        failure,
        const SpawnFailure(
          function: 'posix_spawnp',
          message: 'No such file or directory',
          code: 2,
        ),
      );
    });

    test('a failure with no errno maps to code 0', () {
      final failure = spawnFailureFrom(
        PosixFailure.withoutErrno('openpty', 'returned NULL'),
      );

      expect(failure.code, 0);
      expect(failure.function, 'openpty');
      expect(failure.message, 'returned NULL');
    });
  });
}
