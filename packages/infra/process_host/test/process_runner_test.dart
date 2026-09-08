import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockProcessHost extends Mock implements ProcessHost {}

class _MockRunningProcess extends Mock implements RunningProcess {}

class _MockSandbox extends Mock implements Sandbox {}

const _failure = SpawnFailure(
  function: 'posix_spawnp',
  message: 'No such file or directory',
  code: 2,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  late _MockProcessHost host;
  late _MockRunningProcess process;
  late ProcessRunner runner;

  setUp(() {
    host = _MockProcessHost();
    process = _MockRunningProcess();
    runner = ProcessRunner(host: host, environment: const {'DISPLAY': ':0'});

    when(() => process.stdout).thenAnswer((_) => const Stream.empty());
    when(() => process.stderr).thenAnswer((_) => const Stream.empty());
    when(() => process.exit).thenAnswer((_) async => const ProcessExited(0));
    when(() => process.writeBytes(any())).thenReturn(null);
    when(process.closeStdin).thenAnswer((_) async {});
    when(process.close).thenAnswer((_) async {});
    when(() => process.sandbox).thenReturn(null);
  });

  void whenPipedReturns(ProcessSpawnResult result) {
    when(
      () => host.piped(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
        sandbox: any(named: 'sandbox'),
      ),
    ).thenReturn(result);
  }

  group('when the child starts', () {
    setUp(() => whenPipedReturns(ProcessSpawnSucceeded(process)));

    test('reports the exit status', () async {
      when(() => process.exit).thenAnswer((_) async => const ProcessExited(3));

      final result = await runner.run('pbcopy');

      expect(
        result,
        isA<ProcessRunCompleted>().having(
          (r) => r.exit,
          'exit',
          const ProcessExited(3),
        ),
      );
    });

    test('forwards stdin, then closes it so the child sees EOF', () async {
      await runner.run('pbcopy', stdin: const [1, 2, 3]);

      verifyInOrder([
        () => process.writeBytes(const [1, 2, 3]),
        process.closeStdin,
      ]);
    });

    test('skips the write when there is no stdin to send', () async {
      await runner.run('pbcopy');

      verifyNever(() => process.writeBytes(any()));
      verify(process.closeStdin).called(1);
    });

    test('releases the process once the child has finished', () async {
      await runner.run('pbcopy');

      verify(process.close).called(1);
    });

    test('drains stdout and stderr so a chatty child cannot wedge', () async {
      final stdout = StreamController<List<int>>();
      final stderr = StreamController<List<int>>();
      final exit = Completer<ProcessExit>();
      when(() => process.stdout).thenAnswer((_) => stdout.stream);
      when(() => process.stderr).thenAnswer((_) => stderr.stream);
      when(() => process.exit).thenAnswer((_) => exit.future);

      final pending = runner.run('pbcopy');

      // A child that writes to both pipes must not block the runner.
      stdout.add(const [1]);
      stderr.add(const [2]);
      await Future<void>.delayed(Duration.zero);
      exit.complete(const ProcessExited(0));
      await stdout.close();
      await stderr.close();

      expect(await pending, isA<ProcessRunCompleted>());
    });

    test('passes the caller arguments through to the host', () async {
      await runner.run('xclip', arguments: const ['-selection', 'clipboard']);

      verify(
        () => host.piped(
          executable: 'xclip',
          arguments: const ['-selection', 'clipboard'],
          environment: const {'DISPLAY': ':0'},
        ),
      ).called(1);
    });

    test('confines the child in the sandbox it was given', () async {
      final sandbox = _MockSandbox();

      await runner.run('rm', sandbox: sandbox);

      verify(
        () => host.piped(
          executable: 'rm',
          arguments: const [],
          environment: const {'DISPLAY': ':0'},
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('reports the confinement the child actually ran under', () async {
      final sandbox = _MockSandbox();
      when(() => process.sandbox).thenReturn(sandbox);

      final result = await runner.run('rm', sandbox: sandbox);

      expect(
        result,
        isA<ProcessRunCompleted>().having((r) => r.sandbox, 'sandbox', sandbox),
      );
    });
  });

  group('when the child never starts', () {
    setUp(() => whenPipedReturns(const ProcessSpawnFailed(_failure)));

    test('reports the failure instead of an exit status', () async {
      final result = await runner.run('pbcopy');

      expect(
        result,
        isA<ProcessRunNotStarted>().having(
          (r) => r.failure,
          'failure',
          _failure,
        ),
      );
    });

    test('touches no process, since there is nothing to tear down', () async {
      await runner.run('pbcopy', stdin: const [1, 2, 3]);

      verifyZeroInteractions(process);
    });
  });

  group('runCaptured', () {
    test('collects stdout and stderr alongside the exit status', () async {
      whenPipedReturns(ProcessSpawnSucceeded(process));
      when(
        () => process.stdout,
      ).thenAnswer(
        (_) => Stream.fromIterable([
          const [104, 105],
          const [33],
        ]),
      );
      when(
        () => process.stderr,
      ).thenAnswer((_) => Stream.value(const [98, 121, 101]));
      when(() => process.exit).thenAnswer((_) async => const ProcessExited(0));

      final result = await runner.runCaptured(
        'coreutils',
        arguments: const [
          '--list',
        ],
      );

      expect(
        result,
        isA<ProcessCaptureCompleted>()
            .having((r) => r.exit, 'exit', const ProcessExited(0))
            .having((r) => r.stdout, 'stdout', const [104, 105, 33])
            .having((r) => r.stderr, 'stderr', const [98, 121, 101]),
      );
      verify(process.close).called(1);
    });

    test('forwards stdin, then closes it so the child sees EOF', () async {
      whenPipedReturns(ProcessSpawnSucceeded(process));

      await runner.runCaptured('cat', stdin: const [1, 2, 3]);

      verifyInOrder([
        () => process.writeBytes(const [1, 2, 3]),
        process.closeStdin,
      ]);
    });

    test('reports the confinement the child actually ran under', () async {
      final sandbox = _MockSandbox();
      whenPipedReturns(ProcessSpawnSucceeded(process));
      when(() => process.sandbox).thenReturn(sandbox);

      final result = await runner.runCaptured('rg', sandbox: sandbox);

      expect(
        result,
        isA<ProcessCaptureCompleted>().having(
          (r) => r.sandbox,
          'sandbox',
          sandbox,
        ),
      );
    });

    test('reports the failure when the child never starts', () async {
      whenPipedReturns(const ProcessSpawnFailed(_failure));

      final result = await runner.runCaptured('coreutils');

      expect(
        result,
        isA<ProcessCaptureNotStarted>().having(
          (r) => r.failure,
          'failure',
          _failure,
        ),
      );
    });
  });
}
