import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

class _MockSandboxBackend extends Mock implements SandboxBackend {}

class _FakeSandbox implements Sandbox {}

/// A host that may need one-time work: whether it is already [prepared],
/// and what [preparation] answers.
class _HostPreparingRepository extends SandboxRepository {
  _HostPreparingRepository(
    super.guard, {
    required this.prepared,
    required this.preparation,
  }) : super(preparesHost: true);

  bool prepared;
  Future<HostPreparation> preparation;
  Future<void> checking = Future.value();
  bool reclaimed = false;
  int resets = 0;

  @override
  Future<bool> hostPrepared(SandboxSpec spec) async {
    await checking;
    return prepared;
  }

  @override
  Future<HostPreparation> prepareHost(SandboxSpec spec) => preparation;

  @override
  Future<void> reclaimHost() async => reclaimed = true;

  @override
  Future<void> resetHost() async {
    resets++;
    prepared = false;
  }
}

/// A host whose grants are never found in place, though there is nothing to
/// put there: it gates, and initializing walks straight through.
class _GatedRepository extends SandboxRepository {
  _GatedRepository(super.guard) : super(preparesHost: true);

  @override
  Future<bool> hostPrepared(SandboxSpec spec) async => false;
}

const _enforcement = SandboxEnforcement(
  enforced: {},
  network: NetworkConfined(NetworkTier.none),
  backend: 'test',
);

SandboxSpec _spec(String workspace) => SandboxSpec(workspaceRoot: workspace);

SandboxPlanned _planned(String workspace) =>
    SandboxPlanned(spec: _spec(workspace), failClosed: true);

void main() {
  setUpAll(() {
    registerFallbackValue(_spec('/'));
    registerFallbackValue(_FakeSandbox());
  });

  late _MockSandboxBackend guard;
  late SandboxRepository repository;

  setUp(() {
    guard = _MockSandboxBackend();
    repository = SandboxRepository(guard);
    when(() => guard.release(any())).thenAnswer((_) async {
      return;
    });
    when(() => guard.dispose()).thenAnswer((_) async {
      return;
    });
  });

  SandboxAcquired acquired([Sandbox? sandbox]) =>
      SandboxAcquired(sandbox ?? _FakeSandbox(), _enforcement);

  void whenAcquire(List<SandboxAcquisition> results) {
    when(
      () => guard.acquire(any()),
    ).thenAnswer((_) async => results.removeAt(0));
  }

  _HostPreparingRepository unprepared({
    Future<HostPreparation>? preparation,
  }) => _HostPreparingRepository(
    guard,
    prepared: false,
    preparation: preparation ?? Future.value(const HostPrepared()),
  );

  group('acquire', () {
    test('provisions once and reuses one confinement for one policy', () async {
      whenAcquire([acquired(), acquired()]);

      final first = await repository.acquire(_spec('/ws'));
      final second = await repository.acquire(_spec('/ws'));

      expect(first, same(second));
      verify(() => guard.acquire(any())).called(1);
    });

    test(
      'a changed policy releases the old confinement and provisions anew',
      () async {
        final old = _FakeSandbox();
        final fresh = _FakeSandbox();
        whenAcquire([acquired(old), acquired(fresh)]);

        await repository.acquire(_spec('/a'));
        await repository.acquire(_spec('/b'));
        await pumpEventQueue();

        verify(() => guard.acquire(any())).called(2);
        verify(() => guard.release(old)).called(1);
        verifyNever(() => guard.release(fresh));
      },
    );

    test(
      'a changed policy finishes the old release before provisioning anew, '
      'since both may name the same machine state',
      () async {
        final old = _FakeSandbox();
        final order = <String>[];
        final acquisitions = [acquired(old), acquired()];
        when(() => guard.acquire(any())).thenAnswer((_) async {
          order.add('acquire');
          return acquisitions.removeAt(0);
        });
        when(() => guard.release(any())).thenAnswer((_) async {
          order.add('release-started');
          await pumpEventQueue();
          order.add('release-finished');
          return;
        });

        await repository.acquire(_spec('/a'));
        await repository.acquire(_spec('/b'));

        expect(order, [
          'acquire',
          'release-started',
          'release-finished',
          'acquire',
        ]);
      },
    );

    test(
      'a failed acquisition is not cached, so the next command retries',
      () async {
        whenAcquire([const SandboxUnavailable('off'), acquired()]);

        final failed = await repository.acquire(_spec('/ws'));
        await pumpEventQueue();
        final retried = await repository.acquire(_spec('/ws'));

        expect(failed, isA<SandboxUnavailable>());
        expect(retried, isA<SandboxAcquired>());
        verify(() => guard.acquire(any())).called(2);
        verifyNever(() => guard.release(any()));
      },
    );
  });

  group('adopt on a prepared host', () {
    test(
      'provisions ahead so the first acquire does not re-provision',
      () async {
        whenAcquire([acquired()]);

        repository.adopt(_planned('/ws'));
        await pumpEventQueue();
        await repository.acquire(_spec('/ws'));

        verify(() => guard.acquire(any())).called(1);
      },
    );

    test(
      'reads ready throughout, since nothing on the way needs the user',
      () async {
        whenAcquire([acquired()]);
        final seen = <SandboxReadiness>[];
        final sub = repository.readinessStream.listen(seen.add);

        repository.adopt(_planned('/ws'));
        await pumpEventQueue();

        expect(seen, [const SandboxReady()]);
        await sub.cancel();
      },
    );

    test('settles ready even when provisioning fails', () async {
      whenAcquire([const SandboxUnavailable('off')]);

      repository.adopt(_planned('/ws'));
      await pumpEventQueue();

      expect(repository.readiness, isA<SandboxReady>());
    });

    test('refuses to acquire while the host is being checked', () async {
      final checking = Completer<void>();
      final repository = _HostPreparingRepository(
        guard,
        prepared: true,
        preparation: Future.value(const HostPrepared()),
      )..checking = checking.future;
      whenAcquire([acquired()]);

      repository.adopt(_planned('/ws'));
      await pumpEventQueue();
      expect(repository.readiness, isA<SandboxPreparingHost>());
      expect(
        await repository.acquire(_spec('/ws')),
        isA<SandboxInitializing>(),
      );

      checking.complete();
      await pumpEventQueue();
      expect(repository.readiness, isA<SandboxReady>());
      expect(await repository.acquire(_spec('/ws')), isA<SandboxAcquired>());
      expect(repository.reclaimed, isTrue);
    });
  });

  group('adopt on a host awaiting its one-time grants', () {
    test('stops at the gate, provisioning nothing', () async {
      final repository = unprepared();
      whenAcquire([acquired()]);

      repository.adopt(_planned('/ws'));
      await pumpEventQueue();

      expect(repository.readiness, isA<SandboxAwaitingInitialization>());
      verifyNever(() => guard.acquire(any()));
      expect(
        await repository.acquire(_spec('/ws')),
        isA<SandboxInitializing>(),
      );
    });

    test('refuses a program with directions to the gate', () async {
      final repository = unprepared()..adopt(_planned('/ws'));
      await pumpEventQueue();

      final decision = await repository.confine();

      expect(
        decision,
        isA<ConfinementRefused>().having(
          (d) => d.reason,
          'reason',
          allOf(contains('press Enter'), contains('administrator')),
        ),
      );
    });

    test('initialize prepares, provisions, reclaims, and is ready', () async {
      final repository = unprepared();
      whenAcquire([acquired()]);
      repository.adopt(_planned('/ws'));
      await pumpEventQueue();
      expect(
        repository.readinessStream,
        emitsInOrder([
          isA<SandboxAwaitingInitialization>(),
          isA<SandboxPreparingHost>(),
          isA<SandboxProvisioning>(),
          isA<SandboxReady>(),
        ]),
      );

      await repository.initialize();

      expect(repository.readiness, isA<SandboxReady>());
      expect(repository.reclaimed, isTrue);
      expect(await repository.acquire(_spec('/ws')), isA<SandboxAcquired>());
      verify(() => guard.acquire(any())).called(1);
    });

    test('a declined preparation fails without provisioning', () async {
      final repository = unprepared(
        preparation: Future.value(const HostPreparationDeclined()),
      )..adopt(_planned('/ws'));
      await pumpEventQueue();

      await repository.initialize();

      expect(
        repository.readiness,
        isA<SandboxInitializationFailed>().having(
          (r) => r.reason,
          'reason',
          contains('declined'),
        ),
      );
      verifyNever(() => guard.acquire(any()));
      expect(repository.reclaimed, isFalse);
    });

    test('a failed preparation carries its reason to the gate', () async {
      final repository = unprepared(
        preparation: Future.value(const HostPreparationFailed('no acl')),
      )..adopt(_planned('/ws'));
      await pumpEventQueue();

      await repository.initialize();

      expect(
        repository.readiness,
        const SandboxInitializationFailed('no acl'),
      );
      final decision = await repository.confine();
      expect(
        decision,
        isA<ConfinementRefused>().having(
          (d) => d.reason,
          'reason',
          allOf(contains('no acl'), contains('try again')),
        ),
      );
    });

    test('initialize after a failure tries the whole thing again', () async {
      final repository = unprepared(
        preparation: Future.value(const HostPreparationFailed('no acl')),
      )..adopt(_planned('/ws'));
      await pumpEventQueue();
      await repository.initialize();
      whenAcquire([acquired()]);
      repository.preparation = Future.value(const HostPrepared());

      await repository.initialize();

      expect(repository.readiness, isA<SandboxReady>());
    });

    test(
      'a host with nothing to prepare initializes straight through',
      () async {
        final repository = _GatedRepository(guard);
        whenAcquire([acquired()]);
        repository.adopt(_planned('/ws'));
        await pumpEventQueue();
        expect(repository.readiness, isA<SandboxAwaitingInitialization>());

        await repository.initialize();

        expect(repository.readiness, isA<SandboxReady>());
        verify(() => guard.acquire(any())).called(1);
      },
    );

    test('initialize before adopt does nothing', () async {
      final repository = unprepared();

      await repository.initialize();

      expect(repository.readiness, isA<SandboxPreparingHost>());
      verifyNever(() => guard.acquire(any()));
    });

    test('initialize while already in flight does not start again', () async {
      final prepared = Completer<HostPreparation>();
      final repository = unprepared(preparation: prepared.future)
        ..adopt(_planned('/ws'));
      await pumpEventQueue();
      whenAcquire([acquired()]);
      final first = repository.initialize();
      await pumpEventQueue();

      final second = repository.initialize();

      prepared.complete(const HostPrepared());
      await Future.wait([first, second]);
      verify(() => guard.acquire(any())).called(1);
    });
  });

  group('reset', () {
    test(
      'releases the live confinement, resets the host, and starts over',
      () async {
        final sandbox = _FakeSandbox();
        final repository = _HostPreparingRepository(
          guard,
          prepared: true,
          preparation: Future.value(const HostPrepared()),
        );
        whenAcquire([acquired(sandbox), acquired()]);
        repository.adopt(_planned('/ws'));
        await pumpEventQueue();

        await repository.reset();

        verify(() => guard.release(sandbox)).called(1);
        expect(repository.resets, 1);
        expect(repository.readiness, isA<SandboxAwaitingInitialization>());
      },
    );

    test('on the default host releases and warms up again', () async {
      final sandbox = _FakeSandbox();
      whenAcquire([acquired(sandbox), acquired()]);
      repository.adopt(_planned('/ws'));
      await pumpEventQueue();

      await repository.reset();

      verify(() => guard.release(sandbox)).called(1);
      verify(() => guard.acquire(any())).called(2);
      expect(repository.readiness, isA<SandboxReady>());
    });

    test('before adopt only resets the host', () async {
      final repository = unprepared();

      await repository.reset();

      expect(repository.resets, 1);
      verifyNever(() => guard.release(any()));
    });
  });

  group('plan', () {
    test('is off until one is adopted, and warms nothing up', () async {
      expect(repository.plan, isA<SandboxOff>());

      repository.adopt(const SandboxOff());
      await pumpEventQueue();

      expect(repository.plan, isA<SandboxOff>());
      verifyNever(() => guard.acquire(any()));
    });

    test('holds the adopted plan', () async {
      whenAcquire([acquired()]);
      final planned = SandboxPlanned(spec: _spec('/ws'), failClosed: false);

      repository.adopt(planned);
      await pumpEventQueue();

      expect(repository.plan, same(planned));
    });
  });

  group('replan', () {
    test(
      'widens the plan, releases the old confinement, and provisions the '
      'new one before answering',
      () async {
        final old = _FakeSandbox();
        final fresh = _FakeSandbox();
        whenAcquire([acquired(old), acquired(fresh)]);
        repository.adopt(_planned('/ws'));
        await pumpEventQueue();
        const wider = SandboxSpec(
          workspaceRoot: '/ws',
          writableRoots: ['/home/me/.pub-cache'],
        );

        final acquisition = await repository.replan(wider);

        expect(
          acquisition,
          isA<SandboxAcquired>().having(
            (a) => a.sandbox,
            'sandbox',
            same(fresh),
          ),
        );
        expect(
          repository.plan,
          isA<SandboxPlanned>()
              .having((p) => p.spec, 'spec', wider)
              .having((p) => p.failClosed, 'failClosed', isTrue),
        );
        verify(() => guard.release(old)).called(1);
        expect(
          await repository.confine(),
          isA<Confined>().having((d) => d.sandbox, 'sandbox', same(fresh)),
        );
      },
    );

    test('keeps confining while the host is re-checked', () async {
      whenAcquire([acquired(), acquired()]);
      repository.adopt(_planned('/ws'));
      await pumpEventQueue();

      final replanned = repository.replan(_spec('/other'));
      final decision = await repository.confine();

      expect(decision, isA<Confined>());
      await replanned;
    });

    test('stops at the gate on a host awaiting its grants', () async {
      final repository = unprepared()..adopt(_planned('/ws'));
      await pumpEventQueue();

      final acquisition = await repository.replan(_spec('/other'));

      expect(acquisition, isA<SandboxInitializing>());
      expect(repository.readiness, isA<SandboxAwaitingInitialization>());
      verifyNever(() => guard.acquire(any()));
    });

    test('is unavailable while the sandbox is off', () async {
      final acquisition = await repository.replan(_spec('/ws'));

      expect(acquisition, isA<SandboxUnavailable>());
      verifyNever(() => guard.acquire(any()));
    });
  });

  group('dispose', () {
    test('releases the live confinement', () async {
      final sandbox = _FakeSandbox();
      whenAcquire([acquired(sandbox)]);

      await repository.acquire(_spec('/ws'));
      await repository.dispose();

      verify(() => guard.release(sandbox)).called(1);
    });

    test('is a no-op when nothing is live', () async {
      await repository.dispose();

      verifyNever(() => guard.release(any()));
    });

    test('does not release a failed acquisition', () async {
      whenAcquire([const SandboxUnavailable('off')]);

      await repository.acquire(_spec('/ws'));
      await repository.dispose();

      verifyNever(() => guard.release(any()));
    });
  });
}
