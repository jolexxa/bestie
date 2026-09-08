import 'dart:async';

import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockSandboxRepository extends Mock implements SandboxRepository {}

class _FakeSandbox implements Sandbox {}

const _enforcement = SandboxEnforcement(
  enforced: {},
  network: NetworkConfined(NetworkTier.none),
  backend: 'test',
);

const _grantsKey = 'app.sandbox_write_grants';

void main() {
  setUpAll(() {
    registerFallbackValue(const SandboxSpec(workspaceRoot: '/'));
    registerFallbackValue(const SandboxOff());
  });

  late _MockSandboxRepository sandboxes;
  late FakeConfigRepository config;

  setUp(() {
    sandboxes = _MockSandboxRepository();
    config = FakeConfigRepository();
    when(() => sandboxes.adopt(any())).thenReturn(null);
    when(() => sandboxes.plan).thenReturn(const SandboxOff());
    when(() => sandboxes.readiness).thenReturn(const SandboxReady());
    when(
      () => sandboxes.readinessStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  SandboxUseCase useCaseWith({
    bool enabled = true,
    bool failClosed = true,
    NetworkTier networkTier = NetworkTier.all,
    SandboxPlatformModel sandboxModel = SandboxPlatformModel.posix,
    List<String> grants = const [],
  }) {
    config.setAll({
      'app.sandbox_agent_shell': enabled,
      'app.sandbox_fail_closed': failClosed,
      'app.sandbox_network_tier': networkTier,
      _grantsKey: grants,
    });
    return SandboxUseCase(
      sandboxes: sandboxes,
      config: config,
      configKeys: SandboxConfigKeys.defaults(),
      sandboxModel: sandboxModel,
      paths: p.posix,
    );
  }

  SandboxPlan setup(SandboxUseCase useCase) {
    final plan = useCase.setupSandbox(
      workspaceRoot: '/work',
      homeDir: '/home/cow',
      tempDir: '/var/folders/cow/T',
      programRoots: const ['/opt/bestie/bin', '/opt/bestie/editor'],
    );
    when(() => sandboxes.plan).thenReturn(plan);
    return plan;
  }

  test('plans no sandbox when the toggle is off, adopting nothing', () {
    final plan = setup(useCaseWith(enabled: false));

    expect(plan, isA<SandboxOff>());
    verifyNever(() => sandboxes.adopt(any()));
  });

  test('carries the fail-closed toggle on the plan', () {
    expect(
      (setup(useCaseWith()) as SandboxPlanned).failClosed,
      isTrue,
    );
    expect(
      (setup(useCaseWith(failClosed: false)) as SandboxPlanned).failClosed,
      isFalse,
    );
  });

  test('adopts the planned spec at once', () {
    final plan = setup(useCaseWith());

    verify(() => sandboxes.adopt(plan)).called(1);
  });

  test('grants the saved directories for write, and so for read', () {
    final plan =
        setup(useCaseWith(grants: const ['/home/cow/.pub-cache']))
            as SandboxPlanned;

    expect(plan.spec.writableRoots, contains('/home/cow/.pub-cache'));
    expect(plan.spec.readableRoots, contains('/home/cow/.pub-cache'));
  });

  test("initialize and reset are the repository's", () async {
    when(() => sandboxes.initialize()).thenAnswer((_) async {});
    when(() => sandboxes.reset()).thenAnswer((_) async {});
    final useCase = useCaseWith();

    await useCase.initialize();
    await useCase.reset();

    verify(() => sandboxes.initialize()).called(1);
    verify(() => sandboxes.reset()).called(1);
  });

  test('offers the write-access tool', () {
    expect(
      useCaseWith().definitions.definitionFor(requestWriteAccessName),
      isNotNull,
    );
  });

  group('requesting write access', () {
    ToolCallInvocation invocation(
      String path, {
      String reason = 'dart pub get keeps packages there',
      String agentId = 'primary',
    }) => ToolCallInvocation(
      conversationId: 'c',
      agentId: agentId,
      callId: 'call-1',
      toolName: requestWriteAccessName,
      outputPath: '/tmp/out',
      maxOutputChars: 4000,
      arguments: {'path': path, 'reason': reason},
    );

    /// Runs the ask, answers it as the user with [allow] once it shows, and
    /// hands back how the call settled.
    Future<JobOutcome> ask(
      SandboxUseCase useCase,
      String path, {
      required bool allow,
    }) async {
      final pending = useCase.respond(invocation(path));
      await pumpEventQueue();
      final request = useCase.pendingWriteAccess!;
      expect(request.reason, 'dart pub get keeps packages there');
      useCase.answerWriteAccess(request.id, allow: allow);
      return (await pending).settled;
    }

    void whenReplan(SandboxAcquisition acquisition) => when(
      () => sandboxes.replan(any()),
    ).thenAnswer((_) async => acquisition);

    test('fails a call with no path', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final job = await useCase.respond(
        const ToolCallInvocation(
          conversationId: 'c',
          agentId: 'primary',
          callId: 'call-1',
          toolName: requestWriteAccessName,
          outputPath: '/tmp/out',
          maxOutputChars: 4000,
          arguments: {'reason': 'because'},
        ),
      );

      expect(await job.settled, isA<JobFailed>());
    });

    test('has nothing to ask while the sandbox is off', () async {
      final useCase = useCaseWith(enabled: false);
      setup(useCase);

      final job = await useCase.respond(invocation('~/.pub-cache'));

      expect(
        await job.settled,
        isA<JobSucceeded>().having(
          (o) => o.content,
          'content',
          contains('already allowed'),
        ),
      );
      expect(useCase.pendingWriteAccess, isNull);
    });

    test('has nothing to ask for a directory already writable', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final job = await useCase.respond(invocation('/work/build'));

      expect(await job.settled, isA<JobSucceeded>());
      expect(useCase.pendingWriteAccess, isNull);
    });

    test('puts the normalized directory to the user', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final pending = useCase.respond(invocation('~/.pub-cache/'));
      await pumpEventQueue();

      expect(useCase.pendingWriteAccess?.path, '/home/cow/.pub-cache');
      expect(useCase.pendingWriteAccess?.shownPath, '~/.pub-cache');
      expect(useCase.pendingWriteAccess?.agentId, 'primary');
      useCase.answerWriteAccess(useCase.pendingWriteAccess!.id, allow: false);
      await pending;
    });

    test('takes a relative directory from the workspace', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final pending = useCase.respond(invocation('../shared/cache'));
      await pumpEventQueue();

      expect(useCase.pendingWriteAccess?.path, '/shared/cache');
      expect(useCase.pendingWriteAccess?.shownPath, '/shared/cache');
      useCase.answerWriteAccess(useCase.pendingWriteAccess!.id, allow: false);
      await pending;
    });

    test('refuses the filesystem, the home directory, and secrets', () async {
      final useCase = useCaseWith();
      setup(useCase);

      for (final path in ['/', '~', '~/.ssh', '/home/cow/.aws/cli']) {
        final job = await useCase.respond(invocation(path));
        expect(
          await job.settled,
          isA<JobFailed>().having(
            (o) => o.message,
            'message',
            contains('cannot be requested'),
          ),
          reason: path,
        );
      }
      expect(useCase.pendingWriteAccess, isNull);
    });

    test(
      'a yes saves the directory, rebuilds the sandbox, and says so',
      () async {
        final useCase = useCaseWith();
        final plan = setup(useCase) as SandboxPlanned;
        whenReplan(SandboxAcquired(_FakeSandbox(), _enforcement));

        final outcome = await ask(useCase, '~/.pub-cache', allow: true);

        expect(config[_grantsKey], ['/home/cow/.pub-cache']);
        final widened =
            verify(() => sandboxes.replan(captureAny())).captured.single
                as SandboxSpec;
        expect(widened.writableRoots, [
          ...plan.spec.writableRoots,
          '/home/cow/.pub-cache',
        ]);
        expect(widened.readableRoots, contains('/home/cow/.pub-cache'));
        expect(
          outcome,
          isA<JobSucceeded>().having(
            (o) => o.content,
            'content',
            contains('/home/cow/.pub-cache'),
          ),
        );
        expect(useCase.pendingWriteAccess, isNull);
      },
    );

    test('a yes adds to the directories already saved', () async {
      final useCase = useCaseWith(grants: const ['/home/cow/.cargo']);
      setup(useCase);
      whenReplan(SandboxAcquired(_FakeSandbox(), _enforcement));

      await ask(useCase, '~/.pub-cache', allow: true);

      expect(config[_grantsKey], ['/home/cow/.cargo', '/home/cow/.pub-cache']);
    });

    test('a yes the sandbox cannot be rebuilt around is still saved', () async {
      final useCase = useCaseWith();
      setup(useCase);
      whenReplan(
        const SandboxProvisioningFailed(operation: 'acl', reason: 'denied'),
      );

      final outcome = await ask(useCase, '~/.pub-cache', allow: true);

      expect(config[_grantsKey], ['/home/cow/.pub-cache']);
      expect(
        outcome,
        isA<JobFailed>().having(
          (o) => o.message,
          'message',
          allOf(contains('next launch'), contains('acl: denied')),
        ),
      );
    });

    test('a no fails the call and is remembered for the session', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final first = await ask(useCase, '~/.pub-cache', allow: false);
      final again = await useCase.respond(invocation('~/.pub-cache'));

      expect(
        first,
        isA<JobFailed>().having(
          (o) => o.message,
          'message',
          contains('declined'),
        ),
      );
      expect(await again.settled, isA<JobFailed>());
      expect(useCase.pendingWriteAccess, isNull);
      expect(config[_grantsKey], isEmpty);
      verifyNever(() => sandboxes.replan(any()));
    });

    test('stopping the call withdraws the ask without a no', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final job = await useCase.respond(invocation('~/.pub-cache'));
      job.stop();
      await pumpEventQueue();

      expect(job.outcome, isA<JobCanceled>());
      expect(useCase.pendingWriteAccess, isNull);

      final again = useCase.respond(invocation('~/.pub-cache'));
      await pumpEventQueue();
      expect(useCase.pendingWriteAccess, isNotNull);
      useCase.answerWriteAccess(useCase.pendingWriteAccess!.id, allow: false);
      await again;
    });

    test('puts asks to the user one at a time, in order', () async {
      final useCase = useCaseWith();
      setup(useCase);
      whenReplan(SandboxAcquired(_FakeSandbox(), _enforcement));
      final seen = <String?>[];
      final sub = useCase.pendingWriteAccessStream
          .map((request) => request?.path)
          .listen(seen.add);

      final first = useCase.respond(invocation('~/.pub-cache'));
      final second = useCase.respond(invocation('~/.cargo'));
      await pumpEventQueue();
      useCase.answerWriteAccess(useCase.pendingWriteAccess!.id, allow: true);
      await pumpEventQueue();
      useCase.answerWriteAccess(useCase.pendingWriteAccess!.id, allow: true);
      await Future.wait([first, second]);
      await pumpEventQueue();

      expect(seen, [null, '/home/cow/.pub-cache', '/home/cow/.cargo', null]);
      await sub.cancel();
    });
  });

  group('the sandbox commands', () {
    late StreamController<SandboxReadiness> readiness;

    setUp(() {
      readiness = StreamController<SandboxReadiness>.broadcast();
      when(() => sandboxes.readiness).thenReturn(const SandboxReady());
      when(
        () => sandboxes.readinessStream,
      ).thenAnswer((_) => readiness.stream);
      when(() => sandboxes.reset()).thenAnswer((_) async {});
      when(
        () => sandboxes.replan(any()),
      ).thenAnswer((_) async => SandboxAcquired(_FakeSandbox(), _enforcement));
    });

    tearDown(() => readiness.close());

    Command command(SandboxUseCase useCase, String id) =>
        useCase.commands.singleWhere((c) => c.id == id);

    Command resetCommand(SandboxUseCase useCase) =>
        command(useCase, 'sandbox.reset');

    Command forgetCommand(SandboxUseCase useCase) =>
        command(useCase, 'sandbox.forgetWriteGrants');

    test('are offered only once a sandbox is planned', () {
      final off = useCaseWith(enabled: false);
      setup(off);
      expect(off.commands, isEmpty);

      final on = useCaseWith();
      setup(on);
      expect(resetCommand(on).group, 'Sandbox');
      expect(forgetCommand(on).group, 'Sandbox');
    });

    test('reset warns about the wait on Windows, where the walk is long', () {
      final windows = useCaseWith(sandboxModel: SandboxPlatformModel.windows);
      setup(windows);
      expect(
        resetCommand(windows).running,
        'Resetting the Windows sandbox. This can take a while. Please be '
        'patient.',
      );

      final posix = useCaseWith();
      setup(posix);
      expect(resetCommand(posix).running, 'Resetting the sandbox…');
    });

    test('are available when ready or failed, not mid-initialization', () {
      final useCase = useCaseWith();
      setup(useCase);

      for (final command in [resetCommand(useCase), forgetCommand(useCase)]) {
        expect(
          command.availability,
          emitsInOrder([
            isA<Available>(),
            isA<Unavailable>(),
            isA<Unavailable>(),
            isA<Unavailable>(),
            isA<Available>(),
          ]),
        );
      }

      readiness
        ..add(const SandboxAwaitingInitialization())
        ..add(const SandboxPreparingHost())
        ..add(const SandboxProvisioning())
        ..add(const SandboxInitializationFailed('no'));
    });

    test('reset resets when invoked while available', () async {
      final useCase = useCaseWith();
      setup(useCase);

      final result = await resetCommand(useCase).invoke(const Answers.empty());

      expect(result, isA<CommandRan>());
      verify(() => sandboxes.reset()).called(1);
    });

    test('reset is rejected when invoked mid-initialization', () async {
      when(
        () => sandboxes.readiness,
      ).thenReturn(const SandboxProvisioning());
      final useCase = useCaseWith();
      setup(useCase);

      final result = await resetCommand(useCase).invoke(const Answers.empty());

      expect(
        result,
        isA<CommandRejected>().having(
          (r) => r.reason,
          'reason',
          contains('initializing'),
        ),
      );
      verifyNever(() => sandboxes.reset());
    });

    test(
      'forget clears the saved directories, forgets the noes, and rebuilds '
      'the sandbox on the startup policy',
      () async {
        final useCase = useCaseWith(grants: const ['/home/cow/.pub-cache']);
        final plan = setup(useCase) as SandboxPlanned;
        final told = <WriteGrantsForgotten>[];
        final sub = useCase.writeGrantsForgotten.listen(told.add);

        final result = await forgetCommand(
          useCase,
        ).invoke(const Answers.empty());

        expect(result, isA<CommandRan>());
        expect(config[_grantsKey], isNull);
        await pumpEventQueue();
        expect(told, [
          const WriteGrantsForgotten(directories: ['/home/cow/.pub-cache']),
        ]);
        await sub.cancel();
        final base =
            verify(() => sandboxes.replan(captureAny())).captured.single
                as SandboxSpec;
        expect(base.writableRoots, isNot(contains('/home/cow/.pub-cache')));
        expect(base.workspaceRoot, plan.spec.workspaceRoot);
      },
    );

    test('forget is rejected when invoked mid-initialization', () async {
      when(
        () => sandboxes.readiness,
      ).thenReturn(const SandboxProvisioning());
      final useCase = useCaseWith();
      setup(useCase);

      final result = await forgetCommand(useCase).invoke(const Answers.empty());

      expect(result, isA<CommandRejected>());
      verifyNever(() => sandboxes.replan(any()));
    });
  });
}
