import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockShellRepository extends Mock implements ShellRepository {}

class _MockTerminalHost extends Mock implements TerminalHost {}

class _MockSandboxRepository extends Mock implements SandboxRepository {}

class _FakeSandbox implements Sandbox {}

/// A sandbox holding writes to `/work`, as the suspector reads it.
class _FakeConfinedSandbox implements ConfinedSandbox {
  @override
  SandboxEnforcement get enforcement => const SandboxEnforcement(
    enforced: {SandboxCapability.filesystemWrite},
    network: NetworkConfined(NetworkTier.all),
    backend: 'test',
    writableRoots: ['/work'],
  );
}

class _MockAgentTerminal extends Mock implements AgentTerminal {}

class _FakeScreen extends Fake implements Screen {}

/// A driven ephemeral shell: [session] under test, [exiting] to end its child.
class _LiveShell {
  _LiveShell(this.session, this.exiting);

  final EphemeralShell session;
  final Completer<ProcessExit> exiting;
}

/// The arguments a `bash_read` resolved to on the repository.
class _ReadArgs {
  _ReadArgs(this.path, this.length, this.at);

  final String path;
  final int length;
  final int at;
}

/// Answers one parameter, so a test can say what the config holds without
/// standing up a whole config stack.
class _StubConfig implements ConfigKeyResolver {
  _StubConfig(this.value);

  final int value;

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) => Resolved<Object?>(
    value: value,
    source: address,
  );

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) => Resolved<T>(
    value: value as T,
    source: address,
  );

  @override
  Object? resolveBase(ConfigAddressBase address) => inspectBase(address).value;

  @override
  T resolve<T>(ConfigAddress<T> address) => inspect(address).value;
}

void main() {
  const environment = ShellEnvironment(
    userland: ShellUserland(
      binDir: '/opt/bestie/bin',
      shellPath: '/opt/bestie/bin/brush',
      executables: ShellExecutables.posix,
    ),
    hostEnvironment: {'PATH': '/usr/bin'},
    homeDir: '/home/cow',
  );

  final scrollbackMb = ConfigKey<int>(
    id: 'app.shell_scrollback_mb',
    path: const ['app', 'shellScrollbackMb'],
    codec: ConfigCodecs.integers,
    defaultValue: () => 10000,
  );

  final shellConfigKeys = ShellConfigKeys(scrollbackMb: scrollbackMb);

  late _MockShellRepository repository;
  late _MockSandboxRepository sandboxes;

  /// The transcript page the repository hands back when it reaps a shell.
  late TranscriptPage stored;

  /// A real interactive shell over a pending host.
  InteractiveShell interactiveShell({String id = 'shell:0'}) =>
      InteractiveShell(
        id: id,
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
        request: _agentRequest,
      );

  setUpAll(() {
    registerFallbackValue(
      const ShellSessionRequest(
        rows: 1,
        cols: 1,
        scrollbackBytes: 0 * 4096,
        environment: <String, String>{},
      ),
    );
    registerFallbackValue(ShellLaunchMode.login);
  });

  setUp(() {
    repository = _MockShellRepository();
    sandboxes = _MockSandboxRepository();
    when(
      () => sandboxes.confine(),
    ).thenAnswer((_) async => const Unconfined());
    final shell = interactiveShell();
    when(() => repository.open(any())).thenReturn(shell);
    when(() => repository.runningEphemeralShells).thenReturn(0);
    when(() => repository.sessions).thenReturn(const []);
    when(
      () => repository.sessionsStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  ShellUseCase useCaseWith({int scrollbackMbValue = 32}) => ShellUseCase(
    repository: repository,
    environment: environment,
    config: _StubConfig(scrollbackMbValue),
    configKeys: shellConfigKeys,
    sandboxes: sandboxes,
  );

  ShellSessionRequest openedRequest() =>
      verify(() => repository.open(captureAny())).captured.single
          as ShellSessionRequest;

  /// The request the use case opened an agent shell with.
  ShellSessionRequest agentRequestUsed() =>
      verify(
            () => repository.openEphemeral(
              captureAny(),
              path: any(named: 'path'),
              endingChars: any(named: 'endingChars'),
            ),
          ).captured.single
          as ShellSessionRequest;

  /// A real ephemeral shell over a mocked host. Completing [exiting] ends it;
  /// [stored] settles its transcript page on exit or close, as the repository
  /// would.
  _LiveShell liveShell({String id = 'shell:0'}) {
    final exiting = Completer<ProcessExit>();
    final transcriptPage = Completer<TranscriptPage>();
    final terminal = _MockAgentTerminal();
    when(
      () => terminal.screenChanges,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => terminal.exit).thenAnswer((_) => exiting.future);
    when(terminal.close).thenAnswer((_) async {});
    when(() => terminal.screen).thenReturn(_FakeScreen());

    final session = EphemeralShell(
      id: id,
      host: _hostAnswering(() async => TerminalSpawnSucceeded(terminal)),
      request: _agentRequest,
      record: transcriptPage.future,
    );
    void reap() {
      if (!transcriptPage.isCompleted) transcriptPage.complete(stored);
    }

    unawaited(session.settled.then((_) => reap()));
    when(
      () => repository.openEphemeral(
        any(),
        path: any(named: 'path'),
        endingChars: any(named: 'endingChars'),
      ),
    ).thenAnswer((_) async => session);
    when(() => repository.close(id)).thenAnswer((_) async {
      reap();
      return stored;
    });
    return _LiveShell(session, exiting);
  }

  /// What the repository answers for a transcript put back on a terminal.
  void stubStored(String ansi) => when(
    () => repository.recordedShellFor(
      any(),
      rows: any(named: 'rows'),
      cols: any(named: 'cols'),
      scrollbackBytes: any(named: 'scrollbackBytes'),
    ),
  ).thenAnswer((_) async => _surfaceOf(ansi));

  void stubTranscript(TranscriptPage page) => stored = page;

  test('holds what it was built with', () {
    final useCase = useCaseWith();

    expect(useCase.repository, same(repository));
    expect(useCase.environment, same(environment));
    expect(useCase.configKeys.scrollbackMb, same(scrollbackMb));
  });

  group('openUserShell', () {
    test('opens a user shell at the size it was given', () {
      useCaseWith().openUserShell(rows: 40, cols: 120);

      final request = openedRequest();
      expect(request.rows, 40);
      expect(request.cols, 120);
      expect(request.arguments, isEmpty);
    });

    test('returns the session the repository tracked', () {
      final session = interactiveShell();
      when(() => repository.open(any())).thenReturn(session);

      expect(useCaseWith().openUserShell(rows: 1, cols: 1), same(session));
    });
  });

  group('scrollback', () {
    test('reads the configured value rather than a baked-in one', () {
      useCaseWith(scrollbackMbValue: 250).openUserShell(rows: 24, cols: 80);

      expect(openedRequest().scrollbackBytes, 250 << 20);
    });

    test('re-reads it for each session, so a change takes effect', () {
      // Changing the setting applies to shells opened afterwards, which
      // only holds if nothing cached the first answer.
      useCaseWith(scrollbackMbValue: 100).openUserShell(rows: 24, cols: 80);
      useCaseWith(scrollbackMbValue: 900).openUserShell(rows: 24, cols: 80);

      final requests = verify(
        () => repository.open(captureAny()),
      ).captured.cast<ShellSessionRequest>();
      expect(requests.map((r) => r.scrollbackBytes), [100 << 20, 900 << 20]);
    });

    test('applies to an agent shell too', () async {
      final shell = liveShell();

      await useCaseWith(scrollbackMbValue: 42).respond(_invocation());
      shell.exiting.complete(const ProcessExited(0));

      expect(agentRequestUsed().scrollbackBytes, 42 << 20);
    });
  });

  group('roster', () {
    const user = ShellSessionSummary(
      id: 'shell:0',
      title: 'brush',
      status: ShellSessionStatus.running,
      kind: ShellSessionKind.interactive,
    );
    const agent = ShellSessionSummary(
      id: 'shell:1',
      title: 'ls',
      status: ShellSessionStatus.running,
      kind: ShellSessionKind.ephemeral,
    );

    test('userShells keeps only the shells the user drives', () {
      when(() => repository.sessions).thenReturn(const [user, agent]);

      expect(useCaseWith().userShells, [user]);
    });

    test('userShellsStream filters each published roster', () {
      when(
        () => repository.sessionsStream,
      ).thenAnswer((_) => Stream.value(const [agent, user]));

      expect(useCaseWith().userShellsStream, emits([user]));
    });

    test('resolves a session through the repository', () {
      final session = interactiveShell();
      when(() => repository.sessionFor('shell:0')).thenReturn(session);

      expect(useCaseWith().sessionFor('shell:0'), same(session));
    });
  });

  test('closes through the repository', () async {
    await useCaseWith().close('shell:0');

    verify(() => repository.close('shell:0')).called(1);
  });

  group('close terminal command', () {
    const user = ShellSessionSummary(
      id: 'shell:0',
      title: 'brush',
      status: ShellSessionStatus.running,
      kind: ShellSessionKind.interactive,
    );

    Command command(ShellUseCase useCase) =>
        useCase.commands.firstWhere((c) => c.id == 'shell.closeTerminal');

    Future<Availability> firstGate(Command command) async {
      final gates = <Availability>[];
      final sub = command.availability.listen(gates.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      return gates.first;
    }

    test('is unavailable when no terminal is open', () async {
      final gate = await firstGate(command(useCaseWith()));
      expect(gate, isA<Unavailable>());
      expect((gate as Unavailable).reason, 'no open terminal');
    });

    test('offers the open user shells and closes the chosen one', () async {
      final session = interactiveShell();
      when(() => repository.sessions).thenReturn(const [user]);
      when(() => repository.sessionFor('shell:0')).thenReturn(session);
      when(() => repository.close('shell:0')).thenAnswer(
        (_) async => TranscriptPage.empty(at: 0, totalChars: 0, totalLines: 0),
      );
      final useCase = useCaseWith();
      final cmd = command(useCase);
      expect(await firstGate(cmd), isA<Available>());

      final param = cmd.next(const Answers.empty())! as ChoiceParam<String>;
      final options = await param.options.first;
      expect(options.single.value, 'shell:0');
      expect(options.single.label, 'brush');

      final answers = const Answers.empty().put(param.key, 'shell:0');
      expect(cmd.next(answers), isNull);
      expect(await cmd.invoke(answers), isA<CommandRan>());
      verify(() => repository.close('shell:0')).called(1);
    });

    test('rejects a terminal that is already gone', () async {
      when(() => repository.sessionFor('shell:0')).thenReturn(null);
      final answers = const Answers.empty().put(
        const ParamKey<String>('shellSessionId'),
        'shell:0',
      );
      expect(
        await command(useCaseWith()).invoke(answers),
        isA<CommandRejected>(),
      );
    });
  });

  /// The outcome of a call driven past the yield window and then settled,
  /// which is how a report rather than an answer comes to be composed. The
  /// shell shares the call's fake zone, so it settles on elapsed time.
  JobOutcome reportOf({ProcessExit exit = const ProcessExited(0)}) {
    JobOutcome? reported;
    fakeAsync((async) {
      final shell = liveShell();
      unawaited(
        useCaseWith().respond(_invocation()).then((job) {
          unawaited(job.settled.then((got) => reported = got));
        }),
      );
      async.elapse(agentShellYieldWindow + const Duration(seconds: 1));
      shell.exiting.complete(exit);
      async.elapse(const Duration(seconds: 1));
    });
    return reported!;
  }

  /// A use case that has run `call-1` through to its exit, which is what
  /// makes that call's output readable by id.
  Future<ShellUseCase> afterACall() async {
    final shell = liveShell();
    final useCase = useCaseWith();
    final job = await useCase.respond(_invocation());
    shell.exiting.complete(const ProcessExited(0));
    await job.settled;
    return useCase;
  }

  setUp(() {
    stored = _stored('hello');
    when(() => repository.close(any())).thenAnswer((_) async => stored);
  });

  group('bash', () {
    /// An ephemeral shell whose spawn was refused, reaped the same way a real
    /// one is once it settles into its failure.
    EphemeralShell refusedShell() {
      final transcriptPage = Completer<TranscriptPage>();
      final session = EphemeralShell(
        id: 'shell:0',
        host: _hostAnswering(
          () async => const TerminalSpawnFailed(
            SpawnFailure(function: 'posix_spawnp', message: 'boom'),
          ),
        ),
        request: _agentRequest,
        record: transcriptPage.future,
      );
      unawaited(
        session.settled.then((_) {
          if (!transcriptPage.isCompleted) transcriptPage.complete(stored);
        }),
      );
      when(
        () => repository.openEphemeral(
          any(),
          path: any(named: 'path'),
          endingChars: any(named: 'endingChars'),
        ),
      ).thenAnswer((_) async => session);
      return session;
    }

    test('replays what a finished call left on disk', () async {
      // The path outlives the session on purpose: the shell is released the
      // moment its command exits, and the file is all that is left.
      stubStored('hello');
      final shell = liveShell();
      final useCase = useCaseWith();
      final job = await useCase.respond(_invocation());
      shell.exiting.complete(const ProcessExited(0));
      await job.settled;

      final attachment = await _replayOf(useCase, 'call-1');

      expect(attachment, isA<AgentShellReplay>());
      expect(_replayText(attachment), 'hello');
      verify(
        () => repository.recordedShellFor(
          '/out/call-1',
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
          scrollbackBytes: any(named: 'scrollbackBytes'),
        ),
      ).called(1);
    });

    test('keeps every call of the conversation it is in', () async {
      // Subagents and the primary share a timeline, so a settled subagent
      // leaving the zone takes nothing away — its rows are still reachable.
      stubStored('kept');
      final first = liveShell();
      final useCase = useCaseWith();
      await useCase.respond(_invocation(agentId: 'sub-1'));
      await first.session.dispose();
      final second = liveShell(id: 'shell:1');
      await useCase.respond(_invocation(callId: 'call-2', agentId: 'primary'));
      await second.session.dispose();

      expect(await _replayOf(useCase, 'call-1'), _recorded);
      expect(await _replayOf(useCase, 'call-2'), _recorded);
    });

    test('lets go of the last conversation when a new one calls', () async {
      stubStored('kept');
      final first = liveShell();
      final useCase = useCaseWith();
      await useCase.respond(_invocation());
      await first.session.dispose();
      final second = liveShell(id: 'shell:1');

      await useCase.respond(
        _invocation(callId: 'call-2', conversationId: 'conversation-2'),
      );
      await second.session.dispose();

      expect(
        await useCase.agentShellFor('call-1').first,
        isA<AgentShellNone>(),
      );
      expect(await _replayOf(useCase, 'call-2'), _recorded);
    });

    test('never records the shells the user drives', () {
      // They are the user's own terminal, not a call with an output to
      // answer for, so there is nothing to keep about them.
      useCaseWith().openUserShell(rows: 24, cols: 80);

      verifyNever(
        () => repository.openEphemeral(
          any(),
          path: any(named: 'path'),
          endingChars: any(named: 'endingChars'),
        ),
      );
    });

    test('has nothing to replay for a call it never ran', () async {
      expect(
        await useCaseWith().agentShellFor('never').first,
        isA<AgentShellNone>(),
      );
      verifyNever(
        () => repository.recordedShellFor(
          any(),
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
          scrollbackBytes: any(named: 'scrollbackBytes'),
        ),
      );
    });

    test('replays an empty record for a call that printed nothing', () async {
      // Still a terminal, just an empty one — a call that ran and said
      // nothing is not the same as a call that never ran.
      stubStored('');
      final shell = liveShell();
      final useCase = useCaseWith();
      await useCase.respond(_invocation());
      await shell.session.dispose();
      await _settle();

      final attachment = await _replayOf(useCase, 'call-1');

      expect(_replayText(attachment), isEmpty);
    });

    test('offers the shell vocabulary and nothing else', () {
      final definitions = useCaseWith().definitions;

      expect(definitions.definitions.map((d) => d.name), [
        bashName,
        bashReadName,
      ]);
      expect(
        definitions.definitionFor(bashName),
        same(bashDefinition),
      );
      expect(
        definitions.definitionFor(bashReadName),
        same(bashReadDefinition),
      );
    });

    test('refuses a call with no command', () async {
      final job = await useCaseWith().respond(_invocation(command: '   '));

      expect(job.outcome, _failed(message: contains('non-empty')));
      verifyNever(
        () => repository.openEphemeral(
          any(),
          path: any(named: 'path'),
          endingChars: any(named: 'endingChars'),
        ),
      );
    });

    test('runs the command it was asked to run', () async {
      final shell = liveShell();

      await useCaseWith().respond(_invocation(command: 'ls -la'));

      expect(agentRequestUsed().arguments, ['-c', 'ls -la']);
      await shell.session.dispose();
    });

    test('answers with what the command printed when it exits well', () async {
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(0));

      expect(await job.settled, _succeeded('hello'));
    });

    test('records from the moment the shell opens', () async {
      // Recording starts as the shell opens, atomically — there is no window
      // in which output could arrive before the transcript is keeping it.
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(0));
      await job.settled;

      verify(
        () => repository.openEphemeral(
          any(),
          path: '/out/call-1',
          endingChars: any(named: 'endingChars'),
        ),
      ).called(1);
    });

    test('answers from a shell whose reap tore it down', () async {
      // The transcript outlives the shell: the answer is made of the page the
      // reap handed back, so tearing the session down afterward changes
      // nothing.
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(0));
      final outcome = await job.settled;
      await shell.session.dispose();

      expect(outcome, _succeeded('hello'));
    });

    test('keeps the whole allowance for the recording to draw on', () async {
      // The answer's wording is priced where it is written, so nothing is
      // held back from the recording here.
      final shell = liveShell();
      final job = await useCaseWith().respond(
        _invocation(maxOutputChars: 5000),
      );

      shell.exiting.complete(const ProcessExited(0));
      await job.settled;

      final endingChars =
          verify(
                () => repository.openEphemeral(
                  any(),
                  path: any(named: 'path'),
                  endingChars: captureAny(named: 'endingChars'),
                ),
              ).captured.single
              as int;
      expect(endingChars, 5000);
    });

    // The message and the output go into the conversation as one answer, and
    // the message is written here rather than measured anywhere else.
    test('fits the output under the message it is told with', () async {
      stubTranscript(_stored('x' * 400));
      final shell = liveShell();
      final job = await useCaseWith().respond(
        _invocation(maxOutputChars: 300),
      );

      shell.exiting.complete(const ProcessExited(2));
      final failed = await job.settled as JobFailed;

      expect(failed.content, isNotEmpty);
      expect(
        failed.message.length + '\n\n'.length + failed.content.length,
        lessThanOrEqualTo(300),
      );
    });

    test('reports a non-zero exit as a failure, output and all', () async {
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(2));

      expect(
        await job.settled,
        _failed(message: contains('code 2'), content: 'hello'),
      );
    });

    test('reports the signal that killed the command', () async {
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessSignaled(9));

      expect(await job.settled, _failed(message: contains('signal 9')));
    });

    test('reports a shell that ended without saying how', () async {
      final shell = liveShell();
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessSupervisorLost());

      expect(
        await job.settled,
        _failed(message: contains('without reporting')),
      );
    });

    test('reports a refused spawn rather than waiting on it', () async {
      refusedShell();

      final job = await useCaseWith().respond(_invocation());

      expect(
        await job.settled,
        _failed(message: allOf(contains('posix_spawnp'), contains('boom'))),
      );
    });

    test('settles from a session that came to rest before it looked', () async {
      final shell = liveShell();
      shell.exiting.complete(const ProcessExited(0));
      await _settle();
      expect(shell.session.state.exited, isTrue);

      final job = await useCaseWith().respond(_invocation());

      expect(await job.settled, isA<JobSucceeded>());
    });

    test('says so plainly when nothing was printed', () async {
      final shell = liveShell();
      stubTranscript(_stored(''));
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(0));

      expect(await job.settled, _succeeded('[no output]'));
    });

    test('says how much it left out when the output did not fit', () async {
      final shell = liveShell();
      stubTranscript(
        TranscriptPage(
          body: Excerpt.chars('the end', start: 3993, total: 4000),
          totalLines: 300,
        ),
      );
      final job = await useCaseWith().respond(_invocation());

      shell.exiting.complete(const ProcessExited(0));

      expect(
        await job.settled,
        _succeeded(
          allOf(
            startsWith('the end'),
            contains('300 lines, 4000 chars in all'),
            contains('the last 7 chars shown'),
          ),
        ),
      );
    });

    test('refuses once as many as it may are already running', () async {
      when(() => repository.runningEphemeralShells).thenReturn(maxAgentShells);

      final job = await useCaseWith().respond(
        _invocation(callId: 'one-too-many'),
      );

      expect(job.outcome, _failed(message: contains('as many as')));
    });

    test('runs another while there is room for one', () async {
      final shell = liveShell();

      final next = await useCaseWith().respond(_invocation(callId: 'call-2'));

      expect(next.outcome, isNull);
      await shell.session.dispose();
    });

    group('confinement', () {
      test('runs the command inside what the plan confines to', () async {
        final confinement = _FakeSandbox();
        when(
          () => sandboxes.confine(),
        ).thenAnswer((_) async => Confined(confinement));
        final shell = liveShell();

        await useCaseWith().respond(_invocation());

        expect(agentRequestUsed().sandbox, same(confinement));
        await shell.session.dispose();
      });

      test('points a blocked write at the write-access tool', () async {
        when(
          () => sandboxes.confine(),
        ).thenAnswer((_) async => Confined(_FakeConfinedSandbox()));
        stubTranscript(
          _stored(
            'building\n'
            'mkdir: cannot create directory /srv/out: Permission denied\n',
          ),
        );
        final shell = liveShell();
        final job = await useCaseWith().respond(_invocation());

        shell.exiting.complete(const ProcessExited(1));

        expect(
          await job.settled,
          _failed(
            message: allOf(
              startsWith('Exited with code 1.'),
              contains('may have blocked a write'),
              contains('/srv/out: Permission denied'),
              contains('Writable: /work.'),
              contains('request_write_access'),
            ),
            content: contains('Permission denied'),
          ),
        );
      });

      test(
        'says nothing of the sandbox when the output blames nothing',
        () async {
          when(
            () => sandboxes.confine(),
          ).thenAnswer((_) async => Confined(_FakeConfinedSandbox()));
          stubTranscript(_stored('tests failed'));
          final shell = liveShell();
          final job = await useCaseWith().respond(_invocation());

          shell.exiting.complete(const ProcessExited(1));

          expect(
            await job.settled,
            _failed(message: 'Exited with code 1.', content: 'tests failed'),
          );
        },
      );

      test('refuses the command when confinement is refused', () async {
        when(
          () => sandboxes.confine(),
        ).thenAnswer((_) async => const ConfinementRefused('no seatbelt'));

        final job = await useCaseWith().respond(_invocation());

        expect(
          job.outcome,
          _failed(message: allOf(contains('confine'), contains('no seatbelt'))),
        );
        verifyNever(
          () => repository.openEphemeral(
            any(),
            path: any(named: 'path'),
            endingChars: any(named: 'endingChars'),
          ),
        );
      });
    });

    test('hands the call back when the command outlives the window', () {
      fakeAsync((async) {
        final shell = liveShell();
        stubTranscript(_stored('working'));
        stubStored('working');
        final useCase = useCaseWith();
        final held = <AgentShellAttachment>[];
        final watching = useCase.agentShellFor('call-1').listen(held.add);

        Job? job;
        String? handoff;
        unawaited(
          useCase.respond(_invocation()).then((made) {
            job = made;
            unawaited(made.inBackground.then((text) => handoff = text));
          }),
        );
        async.elapse(agentShellYieldWindow + const Duration(seconds: 1));

        expect(handoff, contains('call-1'));
        expect(job!.outcome, isNull, reason: 'the command is still running');

        expect(held.last, _liveOn(shell.session));

        shell.exiting.complete(const ProcessExited(0));
        async.elapse(const Duration(seconds: 1));

        expect(job!.outcome, isA<JobSucceeded>());
        expect(held.last, _recorded, reason: 'the call let its shell go');
        unawaited(watching.cancel());
      });
    });

    test('hands a command back under the call it can be read back by', () {
      // A reader cannot ask for the session a command went to; naming the
      // call is what lets the transcript be read back later.
      fakeAsync((async) {
        liveShell();
        stubTranscript(_stored('working'));
        String? handoff;
        unawaited(
          useCaseWith().respond(_invocation()).then((job) {
            unawaited(job.inBackground.then((text) => handoff = text));
          }),
        );
        async.elapse(agentShellYieldWindow + const Duration(seconds: 1));

        expect(
          handoff,
          'Still running as call-1. You will be told how it finished.',
        );
      });
    });

    test('handing a command back does not reap it', () {
      // Reaping the shell here would lose everything the still-printing
      // command goes on to say.
      fakeAsync((async) {
        liveShell();
        unawaited(useCaseWith().respond(_invocation()));
        async.elapse(agentShellYieldWindow + const Duration(seconds: 1));

        verifyNever(() => repository.close(any()));
      });
    });

    test('reports a backgrounded command without carrying its output', () {
      // The report arrives long after the allowance that measured this call,
      // so it says how much there is and carries none of it.
      stubTranscript(
        TranscriptPage(
          body: Excerpt.chars('the end', start: 8993, total: 9000),
          totalLines: 900,
        ),
      );

      expect(
        reportOf(),
        _succeeded(
          'Exited with code 0. 900 lines, '
          '9000 chars.',
        ),
      );
    });

    test('reports how a backgrounded command failed, output still kept', () {
      expect(
        reportOf(exit: const ProcessExited(2)),
        _failed(
          message: contains('code 2'),
          content: allOf(contains('5 chars.'), isNot(contains('hello'))),
        ),
      );
    });

    test('reports a backgrounded command that printed nothing', () {
      stubTranscript(_stored(''));

      expect(reportOf(), _succeeded('Exited with code 0. [no output]'));
    });

    test('keeps a command that finishes inside the window', () {
      fakeAsync((async) {
        final shell = liveShell();
        var handedOff = false;
        JobOutcome? outcome;

        unawaited(
          useCaseWith().respond(_invocation()).then((job) {
            unawaited(job.inBackground.then((_) => handedOff = true));
            unawaited(job.settled.then((got) => outcome = got));
          }),
        );
        async.elapse(agentShellYieldWindow - const Duration(seconds: 1));

        expect(handedOff, isFalse);

        shell.exiting.complete(const ProcessExited(0));
        async.elapse(const Duration(seconds: 1));

        expect(handedOff, isFalse, reason: 'it finished inside the window');
        expect(outcome, isA<JobSucceeded>());
      });
    });

    test('stopping it keeps what was printed and releases the shell', () async {
      liveShell();
      stubTranscript(_stored('half done'));

      final job = await useCaseWith().respond(_invocation());
      job.stop();

      expect(await job.settled, _canceled('half done'));
      verify(() => repository.close('shell:0')).called(1);
    });

    test('publishes a shell as it is taken up and released', () async {
      stubStored('hello');
      final shell = liveShell();
      final useCase = useCaseWith();
      final seen = <AgentShellAttachment>[];
      final sub = useCase.agentShellFor('call-1').listen(seen.add);
      await _settle();

      // Nothing held yet, so a watcher that arrives first is told so rather
      // than left waiting.
      expect(seen, [isA<AgentShellNone>()]);

      final job = await useCase.respond(_invocation());
      await _settle();
      expect(seen.last, _liveOn(shell.session));

      shell.exiting.complete(const ProcessExited(0));
      await job.settled;
      await _settle();

      // The shell going away is not the end of what there is to show: the
      // transcript it left takes over from it.
      expect(seen, [
        isA<AgentShellNone>(),
        _liveOn(shell.session),
        isA<AgentShellLoading>(),
        isA<AgentShellReplay>(),
      ]);
      expect(_replayText(seen.last), 'hello');

      await sub.cancel();
    });

    test('tells a late watcher what the call already holds', () async {
      final shell = liveShell();
      final useCase = useCaseWith();
      await useCase.respond(_invocation());

      final seen = <AgentShellAttachment>[];
      final sub = useCase.agentShellFor('call-1').listen(seen.add);
      await _settle();

      expect(seen, [_liveOn(shell.session)]);
      await sub.cancel();
    });

    test('knows nothing of a call that never opened a shell', () async {
      await expectLater(
        useCaseWith().agentShellFor('call-9').first,
        completion(isA<AgentShellNone>()),
      );
    });

    test('lets go of every shell it was holding when disposed', () async {
      final useCase = useCaseWith();
      final watching = useCase.agentShellFor('call-1');

      await useCase.dispose();

      await expectLater(
        watching,
        emitsInOrder([isA<AgentShellNone>(), emitsDone]),
      );
    });
  });

  group('bash_read', () {
    /// What the repository answers for any page asked of it.
    void stubPage(TranscriptPage page) => when(
      () => repository.readTranscript(
        any(),
        length: any(named: 'length'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async => page);

    /// The arguments the read was actually made with.
    _ReadArgs readAs() {
      final captured = verify(
        () => repository.readTranscript(
          captureAny(),
          length: captureAny(named: 'length'),
          at: captureAny(named: 'at'),
        ),
      ).captured;
      return _ReadArgs(
        captured[0] as String,
        captured[1] as int,
        captured[2] as int,
      );
    }

    setUp(() {
      stubPage(
        TranscriptPage(
          body: Excerpt.chars('one\ntwo\n', total: 8),
          totalLines: 2,
        ),
      );
    });

    test('answers with the lines it read and nothing else', () async {
      final useCase = await afterACall();

      final job = await useCase.respond(_reading());

      expect(job.outcome, _succeeded('one\ntwo\n'));
    });

    test('resolves the call id to where that call wrote', () async {
      // Addressed by call id, not path: the transcript is a binary format
      // nothing outside this can read, and the id is what a report names.
      final useCase = await afterACall();

      await useCase.respond(_reading());

      expect(readAs().path, '/out/call-1');
    });

    test('refuses an id no call of this conversation answers to', () async {
      final useCase = await afterACall();

      final job = await useCase.respond(_reading(id: 'call-9'));

      expect(
        job.outcome,
        _failed(message: contains('No bash call "call-9"')),
      );
      verifyNever(
        () => repository.readTranscript(any(), length: any(named: 'length')),
      );
    });

    test('refuses a call with no id to read', () async {
      final job = await useCaseWith().respond(_reading(id: '   '));

      expect(job.outcome, _failed(message: contains('non-empty')));
      verifyNever(
        () => repository.readTranscript(any(), length: any(named: 'length')),
      );
    });

    test('never opens a shell to answer one', () async {
      final useCase = await afterACall();
      clearInteractions(repository);

      await useCase.respond(_reading());

      verifyNever(() => repository.open(any()));
    });

    test('starts where it was asked to', () async {
      final useCase = await afterACall();

      await useCase.respond(_reading(arguments: {'offset': 40}));

      expect(readAs().at, 40);
    });

    test(
      'starts at the beginning when asked for no page in particular',
      () async {
        final useCase = await afterACall();

        await useCase.respond(_reading());

        expect(readAs().at, 0);
      },
    );

    test('takes a place the model wrote as text', () async {
      // Models routinely answer an integer parameter with "40".
      final useCase = await afterACall();

      await useCase.respond(_reading(arguments: {'offset': '40'}));

      expect(readAs().at, 40);
    });

    test('takes a place that arrived as a whole double', () async {
      final useCase = await afterACall();

      await useCase.respond(_reading(arguments: {'offset': 40.0}));

      expect(readAs().at, 40);
    });

    test(
      'reads from the beginning rather than refusing a bad offset',
      () async {
        // Nothing about "banana" says which page was wanted, and the first one
        // is a better answer than a failure the model has to recover from.
        final useCase = await afterACall();

        await useCase.respond(_reading(arguments: {'offset': 'banana'}));

        expect(readAs().at, 0);
      },
    );

    test('asks for the whole allowance and fits the page to it', () async {
      final useCase = await afterACall();

      await useCase.respond(_reading(maxOutputChars: 5000));

      expect(readAs().length, 5000);
    });

    test('says how much it showed and where to carry on from', () async {
      // A page stops wherever the allowance ran out, which the reader had no
      // way of knowing in advance, so what came back is worth saying outright.
      stubPage(
        TranscriptPage(
          body: Excerpt.chars('first page', total: 300),
          totalLines: 30,
        ),
      );
      final useCase = await afterACall();

      final job = await useCase.respond(_reading());

      expect(
        job.outcome,
        _succeeded(
          allOf(
            startsWith('first page'),
            contains('chars 0 to 10 of 300'),
            contains('290 to go'),
            contains('bash_read(id: "call-1", offset: 10)'),
          ),
        ),
      );
    });

    test('leaves the last page to speak for itself', () async {
      stubPage(
        TranscriptPage(
          body: Excerpt.chars('the end', start: 293, total: 300),
          totalLines: 30,
        ),
      );
      final useCase = await afterACall();

      final job = await useCase.respond(_reading());

      expect(job.outcome, _succeeded('the end'));
    });

    test('says plainly that the command printed nothing', () async {
      stubPage(
        TranscriptPage.empty(at: 0, totalChars: 0, totalLines: 0),
      );
      final useCase = await afterACall();

      final job = await useCase.respond(_reading());

      expect(job.outcome, _succeeded('[no output]'));
    });

    test('says how far the record goes when asked past its end', () async {
      // Told the extent, the model can ask again for somewhere that exists
      // instead of reading an empty answer as "the output is gone".
      stubPage(
        TranscriptPage.empty(at: 900, totalChars: 300, totalLines: 30),
      );

      final useCase = await afterACall();

      final job = await useCase.respond(_reading(arguments: {'offset': 900}));

      expect(
        job.outcome,
        _succeeded(
          allOf(contains('nothing at 900'), contains('300 chars in all')),
        ),
      );
    });
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

_MockTerminalHost _hostAnswering(
  Future<TerminalSpawnResult> Function() answer,
) {
  final host = _MockTerminalHost();
  when(
    () => host.spawn(
      executable: any(named: 'executable'),
      arguments: any(named: 'arguments'),
      environment: any(named: 'environment'),
      launchMode: any(named: 'launchMode'),
      rows: any(named: 'rows'),
      cols: any(named: 'cols'),
      scrollbackBytes: any(named: 'scrollbackBytes'),
      forwardHostResize: any(named: 'forwardHostResize'),
      sandbox: any(named: 'sandbox'),
    ),
  ).thenAnswer((_) => answer());
  return host;
}

final _agentRequest = ShellSessionRequest.agentShell(
  command: 'ls',
  rows: 24,
  cols: 120,
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
);

ToolCallInvocation _invocation({
  String command = 'ls',
  String callId = 'call-1',
  String agentId = 'agent-1',
  String conversationId = 'conversation-1',
  int maxOutputChars = 4000,
}) => ToolCallInvocation(
  conversationId: conversationId,
  agentId: agentId,
  callId: callId,
  toolName: bashName,
  outputPath: '/out/$callId',
  maxOutputChars: maxOutputChars,
  arguments: <String, Object?>{'command': command},
);

ToolCallInvocation _reading({
  String id = 'call-1',
  Map<String, Object?> arguments = const {},
  int maxOutputChars = 4000,
}) => ToolCallInvocation(
  conversationId: 'conversation-1',
  agentId: 'agent-1',
  callId: 'call-2',
  toolName: bashReadName,
  outputPath: '/out/call-2',
  maxOutputChars: maxOutputChars,
  arguments: <String, Object?>{'id': id, ...arguments},
);

/// A success whose content matches [content].
Matcher _succeeded(Object content) => isA<JobSucceeded>().having(
  (outcome) => outcome.content,
  'content',
  content,
);

/// A failure whose message and content match what they were given.
Matcher _failed({Object? message, Object? content}) {
  var matcher = isA<JobFailed>();
  if (message != null) {
    matcher = matcher.having((outcome) => outcome.message, 'message', message);
  }
  if (content != null) {
    matcher = matcher.having((outcome) => outcome.content, 'content', content);
  }
  return matcher;
}

/// A deliberate stop holding [content].
Matcher _canceled(Object content) =>
    isA<JobCanceled>().having((outcome) => outcome.content, 'content', content);

/// The whole of a recording holding [text], which is what a command whose
/// output fitted its allowance ends with.
TranscriptPage _stored(String text) => TranscriptPage(
  body: Excerpt.chars(text, total: text.length),
  totalLines: text.isEmpty ? 0 : text.split('\n').length,
);

/// A recorded transcript, parsed and ready to draw.
final Matcher _recorded = isA<AgentShellReplay>();

/// A real recorded surface holding [ansi], parsed on the spot — the mock hands
/// this back in place of the off-isolate parse the domain would do.
TerminalSurface _surfaceOf(String ansi) {
  final bytes = Uint8List.fromList(utf8.encode(ansi));
  return RecordedShell(
    screen: Screen.fromAnsi(
      bytes,
      rows: 24,
      cols: 80,
      scrollbackBytes: defaultReplayScrollbackBytes,
    ),
  );
}

/// The replay a settled call ends on, past the [AgentShellLoading] it opens
/// the read with.
Future<AgentShellAttachment> _replayOf(ShellUseCase useCase, String callId) =>
    useCase.agentShellFor(callId).firstWhere((a) => a is AgentShellReplay);

/// The visible text of a replay's screen, trimmed of the blank grid around it.
String _replayText(AgentShellAttachment attachment) =>
    (attachment as AgentShellReplay).surface.screen!.snapshot().text.trim();

/// The live shell [session], and that one specifically.
Matcher _liveOn(TerminalSurface session) =>
    isA<AgentShellLive>().having((a) => a.session, 'session', same(session));
