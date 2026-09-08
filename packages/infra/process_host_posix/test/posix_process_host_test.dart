@TestOn('vm && !windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:test/test.dart';

/// A winsize source with no real terminal behind it, so tests never
/// depend on the shape of the window running them and never install a
/// `SIGWINCH` handler.
class _FakeWinsizeSource implements HostWinsizeSource {
  _FakeWinsizeSource(this.current);

  @override
  final Winsize current;

  final changesController = StreamController<Winsize>.broadcast();

  @override
  Stream<Winsize> get changes => changesController.stream;
}

Future<void> main() async {
  final spawner = await const RepoSpawnerLocator().locate();
  final skip = spawner == null ? 'spawner binary not built' : null;

  late _FakeWinsizeSource winsize;

  setUp(() {
    winsize = _FakeWinsizeSource((rows: 30, cols: 100));
  });

  RunningProcess expectSpawned(ProcessSpawnResult result) => switch (result) {
    ProcessSpawnSucceeded(:final process) => process,
    ProcessSpawnFailed(:final failure) => fail('spawn failed: $failure'),
  };

  group('terminal', () {
    test('sizes the pty from the host when the caller does not', () async {
      final host = PosixProcessHost(
        spawnerBinaryPath: spawner ?? '',
        winsizeSource: winsize,
      );

      final process = expectSpawned(
        host.terminal(
          environment: Platform.environment,
          executable: '/bin/sh',
          arguments: const ['-c', 'stty size; exit 0'],
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
        ),
      );
      final output = await process.stdout
          .expand((b) => b)
          .toList()
          .then(String.fromCharCodes);
      await process.exit.timeout(const Duration(seconds: 10));
      await process.close();

      expect(output, contains('30 100'));
    }, skip: skip);

    test('honours an explicit size over the host size', () async {
      final host = PosixProcessHost(
        spawnerBinaryPath: spawner ?? '',
        winsizeSource: winsize,
      );

      final process = expectSpawned(
        host.terminal(
          environment: Platform.environment,
          executable: '/bin/sh',
          arguments: const ['-c', 'stty size; exit 0'],
          launchMode: ShellLaunchMode.raw,
          initialRows: 50,
          initialCols: 132,
          forwardHostResize: false,
        ),
      );
      final output = await process.stdout
          .expand((b) => b)
          .toList()
          .then(String.fromCharCodes);
      await process.exit.timeout(const Duration(seconds: 10));
      await process.close();

      expect(output, contains('50 132'));
    }, skip: skip);

    test('forwards host resizes down to the child when asked', () async {
      final host = PosixProcessHost(
        spawnerBinaryPath: spawner ?? '',
        winsizeSource: winsize,
      );

      final process = expectSpawned(
        host.terminal(
          environment: Platform.environment,
          executable: '/bin/sh',
          arguments: const ['-c', 'read _; stty size; exit 0'],
          launchMode: ShellLaunchMode.raw,
        ),
      );
      winsize.changesController.add((rows: 44, cols: 111));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      process.writeString('go\n');

      final output = await process.stdout
          .expand((b) => b)
          .toList()
          .then(String.fromCharCodes);
      await process.exit.timeout(const Duration(seconds: 10));
      await process.close();

      expect(output, contains('44 111'));
    }, skip: skip);

    test('refuses to guess a shell when no executable is given', () {
      // bestie runs the shell it ships, so there is nothing to fall back to —
      // the host's $SHELL names a shell bestie does not drive.
      final host = PosixProcessHost(
        spawnerBinaryPath: spawner ?? '',
        winsizeSource: winsize,
      );

      final result = host.terminal(
        environment: Platform.environment,
        arguments: const ['-c', 'exit 0'],
        launchMode: ShellLaunchMode.raw,
        forwardHostResize: false,
      );

      expect(
        (result as ProcessSpawnFailed).failure.message,
        contains('No executable'),
      );
    });

    test('reports a failure rather than throwing', () {
      const host = PosixProcessHost(
        spawnerBinaryPath: '/definitely/not/a/real/spawner',
      );

      final result = host.terminal(
        environment: Platform.environment,
        executable: '/bin/sh',
        launchMode: ShellLaunchMode.raw,
        forwardHostResize: false,
      );

      expect(
        result,
        isA<ProcessSpawnFailed>().having(
          (r) => r.failure.code,
          'errno',
          isNonZero,
        ),
      );
    });
  });

  group('piped', () {
    test('refuses to guess a shell when no executable is given', () {
      const host = PosixProcessHost(spawnerBinaryPath: '');

      expect(
        host.piped(environment: Platform.environment),
        isA<ProcessSpawnFailed>(),
      );
    });

    test('reports a failure rather than throwing', () {
      const host = PosixProcessHost(
        spawnerBinaryPath: '/definitely/not/a/real/spawner',
      );

      final result = host.piped(
        executable: '/bin/sh',
        environment: Platform.environment,
      );

      expect(
        result,
        isA<ProcessSpawnFailed>().having(
          (r) => r.failure.function,
          'function',
          isNotEmpty,
        ),
      );
    });
  });

  group('shell launch modes', () {
    test('login passes -l, interactive adds -i, raw passes neither', () async {
      final host = PosixProcessHost(
        spawnerBinaryPath: spawner ?? '',
        winsizeSource: winsize,
      );

      Future<String> argvOf(ShellLaunchMode mode) async {
        final process = expectSpawned(
          host.piped(
            environment: Platform.environment,
            executable: '/bin/sh',
            arguments: const ['-c', r'printf "ARGS=%s\n" "$-"'],
            launchMode: mode,
          ),
        );
        final output = await process.stdout
            .expand((b) => b)
            .toList()
            .then(String.fromCharCodes);
        await process.exit.timeout(const Duration(seconds: 10));
        await process.close();
        return output;
      }

      // `$-` lists the shell's active option flags; `i` appears only for
      // an interactive shell.
      expect(await argvOf(ShellLaunchMode.raw), isNot(contains('i')));
      expect(await argvOf(ShellLaunchMode.login), isNot(contains('i')));
      expect(await argvOf(ShellLaunchMode.interactiveLogin), contains('i'));
    }, skip: skip);
  });
}
