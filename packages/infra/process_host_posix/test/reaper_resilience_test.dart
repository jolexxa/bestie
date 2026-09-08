// Proves the headline property of the supervised-spawn design: exit
// status is delivered over a status pipe (bytes), not `waitpid` (a
// zombie you race for). So even running *directly* under `dart test` —
// whose `test` package installs a process-wide SIGCHLD handler that
// reaps children out from under naive `waitpid` — we still report the
// true exit code.
@TestOn('vm && !windows')
library;

import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final spawner = await const RepoSpawnerLocator().locate();
  final skip = spawner == null ? 'spawner binary not built' : null;
  final host = PosixProcessHost(spawnerBinaryPath: spawner ?? '');

  RunningProcess run(List<String> arguments) => switch (host.piped(
    executable: '/bin/sh',
    environment: const {},
    arguments: arguments,
  )) {
    ProcessSpawnSucceeded(:final process) => process,
    ProcessSpawnFailed(:final failure) => fail('spawn failed: $failure'),
  };

  group('reaper resilience (in-process, under the test SIGCHLD handler)', () {
    test('reports a true exit code', () async {
      final proc = run(const ['-c', 'echo hi; exit 42']);
      final exit = await proc.exit.timeout(const Duration(seconds: 10));
      expect(exit, const ProcessExited(42));
      await proc.close();
    }, skip: skip);

    test('reports signal death', () async {
      final proc = run(const ['-c', 'sleep 30']);
      await proc.pid;
      await proc.kill(force: true);
      final exit = await proc.exit.timeout(const Duration(seconds: 10));
      expect(exit, const ProcessSignaled(9));
      await proc.close();
    }, skip: skip);

    test('splits stdout and stderr', () async {
      final proc = run(const ['-c', 'echo out; echo err 1>&2; exit 0']);
      final out = await proc.stdout
          .expand((b) => b)
          .toList()
          .then((b) => String.fromCharCodes(b).trim());
      final err = await proc.stderr
          .expand((b) => b)
          .toList()
          .then((b) => String.fromCharCodes(b).trim());
      final exit = await proc.exit.timeout(const Duration(seconds: 10));
      expect(out, 'out');
      expect(err, 'err');
      expect(exit, const ProcessExited(0));
      await proc.close();
    }, skip: skip);
  });
}
