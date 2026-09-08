import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

class _MockChildProcess extends Mock implements ChildProcess {}

class _MockPseudoConsole extends Mock implements PseudoConsole {}

class _MockPipe extends Mock implements Pipe {}

class _MockReadLoop extends Mock implements WindowsReadLoop {}

class _MockExitWaiter extends Mock implements ProcessExitWaiter {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  late _MockChildProcess child;
  late _MockPseudoConsole console;
  late _MockPipe stdinPipe;
  late _MockPipe stdoutPipe;
  late _MockPipe stderrPipe;
  late _MockReadLoop stdoutLoop;
  late _MockReadLoop stderrLoop;
  late _MockExitWaiter waiter;

  setUp(() {
    child = _MockChildProcess();
    console = _MockPseudoConsole();
    stdinPipe = _MockPipe();
    stdoutPipe = _MockPipe();
    stderrPipe = _MockPipe();
    stdoutLoop = _MockReadLoop();
    stderrLoop = _MockReadLoop();
    waiter = _MockExitWaiter();

    when(() => child.pid).thenReturn(4321);
    when(
      () => child.terminate(exitCode: any(named: 'exitCode')),
    ).thenReturn(const ChildTerminateSucceeded());

    when(
      () => console.resize(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(const PseudoConsoleResizeSucceeded());

    for (final pipe in [stdinPipe, stdoutPipe, stderrPipe]) {
      when(() => pipe.write(any())).thenReturn(const PipeWriteSucceeded(0));
    }

    for (final loop in [stdoutLoop, stderrLoop]) {
      when(
        () => loop.stream,
      ).thenAnswer((_) => const Stream<List<int>>.empty());
      when(loop.close).thenAnswer((_) async {});
    }

    // Never completes unless a test says otherwise — the exit future is wired
    // up in the constructor, so every construction needs this.
    when(() => waiter.exitCode).thenAnswer((_) => Completer<int?>().future);
    when(waiter.close).thenAnswer((_) async {});
  });

  WindowsRunningProcess terminalProcess({Stream<Winsize>? hostResize}) =>
      WindowsRunningProcess.terminal(
        child: child,
        console: console,
        inputPipe: stdinPipe,
        outputPipe: stdoutPipe,
        outputLoop: stdoutLoop,
        exitWaiter: waiter,
        hostResizeStream: hostResize,
      );

  WindowsRunningProcess pipedProcess() => WindowsRunningProcess.piped(
    child: child,
    stdinPipe: stdinPipe,
    stdoutPipe: stdoutPipe,
    stderrPipe: stderrPipe,
    stdoutLoop: stdoutLoop,
    stderrLoop: stderrLoop,
    exitWaiter: waiter,
  );

  group('exit status', () {
    test('reports the code the waiter observed', () async {
      when(() => waiter.exitCode).thenAnswer((_) async => 42);

      expect(await terminalProcess().exit, const ProcessExited(42));
    });

    test('a failed wait is not mistaken for a clean exit', () async {
      when(() => waiter.exitCode).thenAnswer((_) async => null);

      expect(await terminalProcess().exit, const ProcessSupervisorLost());
    });

    test('a terminated child still reports a code, never a signal', () async {
      // Windows has no signals, so `kill` shows up as an ordinary exit.
      when(() => waiter.exitCode).thenAnswer((_) async => 1);

      expect(await pipedProcess().exit, isA<ProcessExited>());
    });
  });

  group('stdin', () {
    test('writes bytes through to the stdin pipe', () {
      terminalProcess().writeBytes(const [1, 2, 3]);

      verify(() => stdinPipe.write(const [1, 2, 3])).called(1);
    });

    test('encodes strings as UTF-8', () {
      terminalProcess().writeString('hi 🐮');

      verify(() => stdinPipe.write(utf8.encode('hi 🐮'))).called(1);
    });

    test('rejects writes once stdin is closed', () async {
      final process = pipedProcess();
      await process.closeStdin();

      expect(() => process.writeBytes(const [1]), throwsStateError);
      expect(() => process.writeString('x'), throwsStateError);
      verifyNever(() => stdinPipe.write(any()));
    });

    test('closing stdin gives a piped child EOF', () async {
      await pipedProcess().closeStdin();

      verify(stdinPipe.closeWriteEnd).called(1);
    });

    test('a pty keeps its input end open, since it is also the tty', () async {
      // Closing it would take the terminal's only input channel with it; EOT
      // goes through [writeBytes] instead.
      await terminalProcess().closeStdin();

      verifyNever(stdinPipe.closeWriteEnd);
    });
  });

  group('resize', () {
    test('forwards the new grid to the pseudoconsole', () {
      terminalProcess().resize(rows: 40, cols: 120);

      verify(() => console.resize(rows: 40, cols: 120)).called(1);
    });

    test('is a no-op for a piped child, which has no terminal', () {
      pipedProcess().resize(rows: 40, cols: 120);

      verifyNever(
        () => console.resize(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
        ),
      );
    });

    test('a pseudoconsole reprints its viewport on resize', () {
      expect(terminalProcess().childRepaintsOnResize, isTrue);
    });

    test('a piped child has nothing to reprint', () {
      expect(pipedProcess().childRepaintsOnResize, isFalse);
    });
  });

  group('host resize forwarding', () {
    test('is off unless a resize stream is supplied', () async {
      terminalProcess();
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => console.resize(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
        ),
      );
    });

    test('pushes host size changes down to the pseudoconsole', () async {
      final host = StreamController<Winsize>();
      terminalProcess(hostResize: host.stream);

      host.add((rows: 30, cols: 100));
      await Future<void>.delayed(Duration.zero);

      verify(() => console.resize(rows: 30, cols: 100)).called(1);
      await host.close();
    });

    test(
      'stops forwarding after close, so a closed pty is never poked',
      () async {
        final host = StreamController<Winsize>();
        final process = terminalProcess(hostResize: host.stream);

        await process.close();
        host.add((rows: 30, cols: 100));
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => console.resize(
            rows: any(named: 'rows'),
            cols: any(named: 'cols'),
          ),
        );
        await host.close();
      },
    );
  });

  group('kill', () {
    test('terminates the child', () async {
      expect(await terminalProcess().kill(), isTrue);

      verify(() => child.terminate(exitCode: any(named: 'exitCode'))).called(1);
    });

    test('force adds nothing, because Windows only terminates', () async {
      // There is no polite stop to ask for, so both paths take the same one.
      expect(await terminalProcess().kill(force: true), isTrue);

      verify(() => child.terminate(exitCode: any(named: 'exitCode'))).called(1);
    });

    test('reports false when there was no live target', () async {
      when(() => child.terminate(exitCode: any(named: 'exitCode'))).thenReturn(
        const ChildTerminateFailed(
          Win32Failure.withoutCode('TerminateProcess', 'no such process'),
        ),
      );

      expect(await terminalProcess().kill(), isFalse);
    });
  });

  group('output', () {
    test('exposes the child pid', () async {
      expect(await terminalProcess().pid, 4321);
    });

    test('serves stdout from the read loop', () async {
      when(
        () => stdoutLoop.stream,
      ).thenAnswer((_) => Stream.value(const [104, 105]));

      expect(await terminalProcess().stdout.toList(), [
        const [104, 105],
      ]);
    });

    test('a pty merges stderr onto stdout, so stderr is empty', () async {
      expect(await terminalProcess().stderr.toList(), isEmpty);
    });

    test('a piped child keeps stderr separate', () async {
      when(
        () => stderrLoop.stream,
      ).thenAnswer((_) => Stream.value(const [101, 114]));

      expect(await pipedProcess().stderr.toList(), [
        const [101, 114],
      ]);
    });
  });

  group('close', () {
    test(
      'kills the waiter before the handle it blocks on is released',
      () async {
        await terminalProcess().close();

        verifyInOrder([waiter.close, child.close]);
      },
    );

    test(
      'drains the console through teardown before closing the read loop',
      () async {
        // ClosePseudoConsole emits a final frame to the output pipe, so a reader
        // that left early would deadlock it.
        await terminalProcess().close();

        verifyInOrder([console.close, stdoutLoop.close]);
      },
    );

    test('releases every pipe it was handed', () async {
      await pipedProcess().close();

      verify(stdinPipe.close).called(1);
      verify(stdoutPipe.close).called(1);
      verify(stderrPipe.close).called(1);
      verify(stderrLoop.close).called(1);
    });

    test('is idempotent, so a double teardown frees nothing twice', () async {
      final process = pipedProcess();

      await process.close();
      await process.close();

      verify(child.close).called(1);
      verify(waiter.close).called(1);
      verify(stdoutLoop.close).called(1);
    });
  });
}
