import 'dart:async';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

class _MockTerminalHost extends Mock implements TerminalHost {}

class _MockAgentTerminal extends Mock implements AgentTerminal {}

class _FakeSandbox implements Sandbox {}

class _FakeScreen extends Fake implements Screen {
  @override
  String? title;
}

/// Stubs the one call `ShellSessionStarting` makes, for [request]. Stubbing
/// the exact arguments rather than `any` means a change to how a shell is
/// launched surfaces here instead of passing silently.
_MockTerminalHost _hostAnswering(
  Future<TerminalSpawnResult> Function() answer, {
  ShellSessionRequest? request,
}) {
  final spawned = request ?? _loginShell;
  final host = _MockTerminalHost();
  when(
    () => host.spawn(
      executable: spawned.executable,
      arguments: spawned.arguments,
      environment: spawned.environment,
      launchMode: spawned.launchMode,
      rows: spawned.rows,
      cols: spawned.cols,
      scrollbackBytes: spawned.scrollbackBytes,
      forwardHostResize: spawned.forwardHostResize,
      sandbox: spawned.sandbox,
    ),
  ).thenAnswer((_) => answer());
  return host;
}

/// A terminal whose exit never resolves, so the session stays running.
_MockAgentTerminal _liveTerminal({
  Screen? screen,
  Stream<void>? screenChanges,
  Completer<ProcessExit>? exiting,
}) {
  final terminal = _MockAgentTerminal();
  when(
    () => terminal.screenChanges,
  ).thenAnswer((_) => screenChanges ?? const Stream<void>.empty());
  when(
    () => terminal.exit,
  ).thenAnswer((_) => (exiting ?? Completer<ProcessExit>()).future);
  when(terminal.close).thenAnswer((_) async {});
  when(() => terminal.screen).thenReturn(screen ?? _FakeScreen());
  return terminal;
}

/// Lets pending microtasks (the async spawn / exit plumbing) settle.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// The bundled shell every session names.
final _loginShell = ShellSessionRequest.userShell(
  rows: 24,
  cols: 80,
  scrollbackBytes: 10000 * 4096,
  environment: const ShellEnvironment(
    userland: ShellUserland(
      binDir: '/opt/bestie/bin',
      shellPath: '/opt/bestie/bin/brush',
      executables: ShellExecutables.posix,
    ),
    hostEnvironment: {},
    homeDir: '/home/cow',
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, String>{});
    registerFallbackValue(ShellLaunchMode.login);
  });

  InteractiveShell pendingSession() => InteractiveShell(
    id: 'test',
    host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
    request: _loginShell,
  );

  Future<InteractiveShell> runningSession(_MockAgentTerminal terminal) async {
    final session = InteractiveShell(
      id: 'test',
      host: _hostAnswering(() async => TerminalSpawnSucceeded(terminal)),
      request: _loginShell,
    );
    await settle();
    return session;
  }

  group('startup', () {
    test('a new session is already starting its shell', () async {
      final session = pendingSession();

      expect(session.state, isA<ShellSessionStarting>());
      expect(session.state.starting, isTrue);
      expect(session.state.terminal, isNull);
      expect(session.screen, isNull);

      await session.dispose();
    });

    test('spawns the request it was given', () async {
      const request = ShellSessionRequest(
        executable: 'brush',
        arguments: ['-l', '-c', 'echo hi'],
        environment: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 120,
        scrollbackBytes: 5 * 4096,
        forwardHostResize: false,
      );
      final host = _hostAnswering(
        () => Completer<TerminalSpawnResult>().future,
        request: request,
      );

      final session = InteractiveShell(
        id: 'test',
        host: host,
        request: request,
      );

      verify(
        () => host.spawn(
          executable: 'brush',
          arguments: ['-l', '-c', 'echo hi'],
          environment: {'TERM': 'xterm-256color'},
          launchMode: ShellLaunchMode.login,
          rows: 24,
          cols: 120,
          scrollbackBytes: 5 * 4096,
          forwardHostResize: false,
        ),
      ).called(1);

      await session.dispose();
    });

    test("confines the shell with its request's sandbox", () async {
      final sandbox = _FakeSandbox();
      final request = ShellSessionRequest.agentShell(
        command: 'echo hi',
        rows: 24,
        cols: 80,
        scrollbackBytes: 4096,
        environment: const ShellEnvironment(
          userland: ShellUserland(
            binDir: '/opt/bestie/bin',
            shellPath: '/opt/bestie/bin/brush',
            executables: ShellExecutables.posix,
          ),
          hostEnvironment: {},
          homeDir: '/home/cow',
        ),
        sandbox: sandbox,
      );
      final host = _hostAnswering(
        () => Completer<TerminalSpawnResult>().future,
        request: request,
      );

      final session = InteractiveShell(
        id: 'test',
        host: host,
        request: request,
      );

      verify(
        () => host.spawn(
          executable: any(named: 'executable'),
          arguments: any(named: 'arguments'),
          environment: any(named: 'environment'),
          launchMode: any(named: 'launchMode'),
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
          scrollbackBytes: any(named: 'scrollbackBytes'),
          forwardHostResize: any(named: 'forwardHostResize'),
          sandbox: sandbox,
        ),
      ).called(1);

      await session.dispose();
    });
  });

  group('state flags', () {
    /// Every state answers all four flags, and exactly one is true — so a
    /// consumer can switch on them without a state ever claiming to be two
    /// things at once, or none.
    void expectOnly(ShellSessionState state, String active) {
      final flags = <String, bool>{
        'notStarted': state.notStarted,
        'starting': state.starting,
        'running': state.running,
        'exited': state.exited,
      };
      expect(
        flags.entries.where((e) => e.value).map((e) => e.key),
        [active],
        reason: 'expected only $active to be true, got $flags',
      );
    }

    test('exactly one flag is true in each state', () async {
      expectOnly(ShellSessionNotStarted(), 'notStarted');
      expectOnly(ShellSessionStarting(), 'starting');
      expectOnly(ShellSessionRunning(), 'running');
      expectOnly(ShellSessionExited(), 'exited');
    });
  });

  group('spawn settles', () {
    test('a succeeded spawn runs and exposes the screen', () async {
      final screen = _FakeScreen();
      final session = await runningSession(_liveTerminal(screen: screen));

      expect(session.state, isA<ShellSessionRunning>());
      expect(session.state.running, isTrue);
      expect(session.screen, same(screen));

      await session.dispose();
    });

    test('a refused spawn falls back with the failure', () async {
      const failure = SpawnFailure(function: 'posix_spawnp', message: 'boom');
      final session = InteractiveShell(
        id: 'test',
        host: _hostAnswering(() async => const TerminalSpawnFailed(failure)),
        request: _loginShell,
      );
      await settle();

      expect(session.state, isA<ShellSessionNotStarted>());
      expect(session.state.notStarted, isTrue);
      expect(session.state.failure, same(failure));

      await session.dispose();
    });

    test(
      'an unexpected throw below TerminalHost is surfaced, not lost',
      () async {
        final session = InteractiveShell(
          id: 'test',
          host: _hostAnswering(
            () => Future<TerminalSpawnResult>.error(StateError('nope')),
          ),
          request: _loginShell,
        );
        await settle();

        expect(session.state, isA<ShellSessionNotStarted>());
        expect(session.state.failure?.function, 'TerminalHost.spawn');
        expect(session.state.failure?.message, contains('nope'));

        await session.dispose();
      },
    );
  });

  group('exit', () {
    test('an exiting child moves the session to exited', () async {
      final exiting = Completer<ProcessExit>();
      final terminal = _liveTerminal(exiting: exiting);

      final session = await runningSession(terminal);
      exiting.complete(const ProcessExited(3));
      await settle();

      expect(session.state, isA<ShellSessionExited>());
      expect(session.state.exited, isTrue);
      expect(session.state.exitStatus, const ProcessExited(3));
      // The transcript outlives the child.
      expect(session.screen, isNotNull);

      await session.dispose();
    });
  });

  group('stream', () {
    test('emits on each state change', () async {
      final terminal = _liveTerminal();
      final session = InteractiveShell(
        id: 'test',
        host: _hostAnswering(() async => TerminalSpawnSucceeded(terminal)),
        request: _loginShell,
      );
      final seen = <ShellSessionState>[];
      final sub = session.stream.listen(seen.add);

      await settle();

      expect(seen, [isA<ShellSessionRunning>()]);
      await sub.cancel();
      await session.dispose();
    });
  });

  group('screen changes', () {
    test('forwards the child writing to the screen', () async {
      final writes = StreamController<void>.broadcast();
      final session = await runningSession(
        _liveTerminal(screenChanges: writes.stream),
      );
      final seen = <void>[];
      final sub = session.screenChanges.listen(seen.add);

      writes.add(null);
      await settle();

      expect(seen, hasLength(1));

      await sub.cancel();
      await session.dispose();
      await writes.close();
    });

    test('reports one event per chunk applied', () async {
      final writes = StreamController<void>.broadcast();
      final session = await runningSession(
        _liveTerminal(screenChanges: writes.stream),
      );
      final seen = <void>[];
      final sub = session.screenChanges.listen(seen.add);

      writes
        ..add(null)
        ..add(null)
        ..add(null);
      await settle();

      expect(seen, hasLength(3));

      await sub.cancel();
      await session.dispose();
      await writes.close();
    });

    test('stops after dispose', () async {
      final writes = StreamController<void>.broadcast();
      final session = await runningSession(
        _liveTerminal(screenChanges: writes.stream),
      );
      final seen = <void>[];
      final sub = session.screenChanges.listen(seen.add);

      await session.dispose();
      writes.add(null);
      await settle();

      expect(seen, isEmpty);

      await sub.cancel();
      await writes.close();
    });
  });

  group('title changes', () {
    test('emits only when output actually retitles', () async {
      final writes = StreamController<void>.broadcast();
      final screen = _FakeScreen();
      final session = await runningSession(
        _liveTerminal(screen: screen, screenChanges: writes.stream),
      );
      final titles = <String>[];
      final sub = session.titleChanges.listen(titles.add);

      writes.add(null);
      await settle();
      expect(titles.isEmpty, isTrue);

      screen.title = 'vim';
      writes
        ..add(null)
        ..add(null);
      await settle();

      expect(titles, ['vim']);

      await sub.cancel();
      await session.dispose();
      await writes.close();
    });
  });

  group('write', () {
    test('accepts bytes while running', () async {
      final terminal = _liveTerminal();
      when(() => terminal.writeBytes(any())).thenReturn(null);
      final session = await runningSession(terminal);

      expect(session.write(const [0x1B]), isA<ShellWriteAccepted>());
      verify(() => terminal.writeBytes(const [0x1B])).called(1);

      await session.dispose();
    });

    test('refuses bytes when no shell is live', () async {
      final session = pendingSession();

      final result = session.write(const [0x1B]);

      expect(result, isA<ShellWriteRefused>());
      expect((result as ShellWriteRefused).reason, contains('no live shell'));

      await session.dispose();
    });
  });

  group('resize', () {
    test('forwards to the terminal while running', () async {
      final terminal = _liveTerminal();
      when(
        () => terminal.resize(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
        ),
      ).thenReturn(null);
      final session = await runningSession(terminal);

      session.resize(rows: 40, cols: 100);

      verify(() => terminal.resize(rows: 40, cols: 100)).called(1);
      await session.dispose();
    });

    test('is a no-op with no terminal', () async {
      final session = pendingSession();

      expect(() => session.resize(rows: 40, cols: 100), returnsNormally);

      await session.dispose();
    });
  });

  group('restart', () {
    test('closes the old terminal and spawns again', () async {
      final exiting = Completer<ProcessExit>();
      final first = _liveTerminal(exiting: exiting);

      final session = await runningSession(first);
      exiting.complete(const ProcessExited(0));
      await settle();
      expect(session.state, isA<ShellSessionExited>());

      session.restart();

      expect(session.state, isA<ShellSessionStarting>());
      expect(session.state.exitStatus, isNull);
      verify(first.close).called(1);

      await session.dispose();
    });
  });

  group('dispose', () {
    test('closes the terminal and the stream', () async {
      final terminal = _liveTerminal();
      final session = await runningSession(terminal);

      await session.dispose();

      verify(terminal.close).called(1);
      expect(session.stream.isBroadcast, isTrue);
    });

    test('is idempotent', () async {
      final session = await runningSession(_liveTerminal());

      await session.dispose();

      expect(session.dispose(), completes);
    });
  });

  group('coming to rest', () {
    test('a running shell is not at rest', () async {
      final session = await runningSession(_liveTerminal());

      expect(session.atRest, isFalse);

      await session.dispose();
    });

    test('waits for a shell that is still going', () async {
      final exiting = Completer<ProcessExit>();
      final session = await runningSession(_liveTerminal(exiting: exiting));

      final settled = session.settled;
      exiting.complete(const ProcessExited(0));
      final state = await settled;

      expect(state?.exited, isTrue);
      expect(state?.exitStatus, const ProcessExited(0));
      expect(session.atRest, isTrue);

      await session.dispose();
    });

    test('answers at once for a shell that is already over', () async {
      // A session starts itself, so a short command can be finished before
      // anyone thinks to ask — and the stream does not replay.
      final exiting = Completer<ProcessExit>()
        ..complete(const ProcessExited(3));
      final session = await runningSession(_liveTerminal(exiting: exiting));
      await settle();
      expect(session.atRest, isTrue);

      expect((await session.settled)?.exitStatus, const ProcessExited(3));

      await session.dispose();
    });

    test('counts a refused spawn as at rest, rather than waiting', () async {
      // Nothing will ever exit, so anything waiting on an exit alone would
      // wait for good.
      const failure = SpawnFailure(function: 'posix_spawnp', message: 'boom');
      final session = InteractiveShell(
        id: 'test',
        host: _hostAnswering(() async => const TerminalSpawnFailed(failure)),
        request: _loginShell,
      );

      final state = await session.settled;

      expect(state?.failure, same(failure));
      expect(session.atRest, isTrue);

      await session.dispose();
    });

    test('a session not started yet is not at rest', () async {
      final session = pendingSession();

      expect(session.atRest, isFalse);

      await session.dispose();
    });

    test('answers with nothing when the session is released first', () async {
      final session = await runningSession(_liveTerminal());

      final settled = session.settled;
      await session.dispose();

      expect(await settled, isNull);
    });
  });
}
