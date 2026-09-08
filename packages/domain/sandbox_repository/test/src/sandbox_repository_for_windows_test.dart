import 'dart:async';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_grant_store/sandbox_grant_store.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:test/test.dart';

class _MockSandboxBackend extends Mock implements SandboxWindows {}

class _FakeWindowsSandbox implements WindowsSandbox {
  @override
  String get containerSid => 'S-container';

  @override
  List<String> get capabilitySids => const [];

  @override
  String get workingDirectory => r'C:\Users\cow\ws';

  @override
  String get tempDir => r'C:\pkg\AC\Temp';
}

const _enforcement = SandboxEnforcement(
  enforced: {},
  network: NetworkConfined(NetworkTier.none),
  backend: 'AppContainer',
);

final _now = DateTime.utc(2026, 8, 15);

const _home = r'C:\Users\cow';
const _ws = r'C:\Users\cow\ws';
const _ancestors = [r'C:\', r'C:\Users'];
const _pubCache = r'C:\Users\cow\.pub-cache';
const _cargo = r'C:\Users\cow\.cargo';

SandboxPlanned _planned(String workspace) =>
    SandboxPlanned(spec: _spec(workspace), failClosed: true);

SandboxSpec _spec(String workspace) => SandboxSpec(workspaceRoot: workspace);

void main() {
  setUpAll(() {
    registerFallbackValue(_spec(r'C:\'));
    registerFallbackValue(_FakeWindowsSandbox());
    registerFallbackValue(<String>[]);
  });

  late _MockSandboxBackend guard;
  late FileSystem fs;
  late SandboxGrantStore store;

  const policy = SandboxReadPolicy(
    readRoots: [_home],
    holes: [r'C:\Users\cow\.ssh'],
    policyVersion: 1,
  );
  const desiredRead = SandboxReadGrant(
    capabilitySid: 'S-cap',
    readRoots: [_home],
    holes: [r'C:\Users\cow\.ssh'],
    policyVersion: 1,
  );

  setUp(() {
    guard = _MockSandboxBackend();
    fs = MemoryFileSystem.test();
    store = SandboxGrantStore(
      file: '/home/.bestie/sandboxes.json',
      fileSystem: fs,
    );

    when(() => guard.acquire(any())).thenAnswer(
      (_) async => SandboxAcquired(_FakeWindowsSandbox(), _enforcement),
    );
    when(() => guard.systemRoots).thenReturn(const []);
    when(
      () => guard.unlistedAncestors(any()),
    ).thenAnswer((_) async => const AncestorsListable());
    when(
      () => guard.grantAncestorListing(any()),
    ).thenAnswer((_) async => const AncestorsGranted());
    when(
      () => guard.grantSharedRead(
        capabilitySid: any(named: 'capabilitySid'),
        readRoots: any(named: 'readRoots'),
        holes: any(named: 'holes'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => guard.reverseSharedRead(
        capabilitySid: any(named: 'capabilitySid'),
        readRoots: any(named: 'readRoots'),
        holes: any(named: 'holes'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => guard.reverseWorkspace(
        profileName: any(named: 'profileName'),
        workspaceRoot: any(named: 'workspaceRoot'),
        widenedRoots: any(named: 'widenedRoots'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => guard.narrowWorkspace(
        profileName: any(named: 'profileName'),
        roots: any(named: 'roots'),
      ),
    ).thenAnswer((_) async {});
    when(() => guard.profileNameFor(any())).thenReturn('bestie.sandbox.hash');
    when(() => guard.release(any())).thenAnswer((_) async {});
    when(() => guard.dispose()).thenAnswer((_) async {});
  });

  SandboxRepositoryForWindows repository({
    Duration staleAfter = const Duration(days: 30),
  }) => SandboxRepositoryForWindows(
    sandboxBackend: guard,
    store: store,
    bestieReadCapabilitySid: 'S-cap',
    readPolicy: policy,
    clock: Clock.fixed(_now),
    staleAfter: staleAfter,
  );

  /// A repository warmed for [workspace] and initialized through the gate.
  Future<SandboxRepositoryForWindows> readied([
    String workspace = _ws,
  ]) async {
    final repo = repository()..adopt(_planned(workspace));
    await pumpEventQueue();
    await repo.initialize();
    return repo;
  }

  group('readiness gate', () {
    test('opens preparing the host, so acquire reports initializing', () async {
      final repo = repository();
      expect(repo.readiness, isA<SandboxPreparingHost>());
      expect(await repo.acquire(_spec(_ws)), isA<SandboxInitializing>());
    });

    test(
      'a fresh store awaits initialization rather than walking home',
      () async {
        final repo = repository()..adopt(_planned(_ws));
        await pumpEventQueue();

        expect(repo.readiness, isA<SandboxAwaitingInitialization>());
        verifyNever(
          () => guard.grantSharedRead(
            capabilitySid: any(named: 'capabilitySid'),
            readRoots: any(named: 'readRoots'),
            holes: any(named: 'holes'),
          ),
        );
        verifyNever(() => guard.acquire(any()));
      },
    );

    test('a recorded read grant with listable ancestors is prepared', () async {
      store.save(const SandboxGrants(read: desiredRead));

      final repo = repository()..adopt(_planned(_ws));
      await pumpEventQueue();

      expect(repo.readiness, isA<SandboxReady>());
      verify(() => guard.acquire(any())).called(1);
    });

    test(
      'a recorded read grant with unlisted ancestors still awaits',
      () async {
        store.save(const SandboxGrants(read: desiredRead));
        when(
          () => guard.unlistedAncestors(any()),
        ).thenAnswer((_) async => const AncestorsUnlisted([r'C:\']));

        final repo = repository()..adopt(_planned(_ws));
        await pumpEventQueue();

        expect(repo.readiness, isA<SandboxAwaitingInitialization>());
      },
    );

    test('refuses while the shared read walk is in flight', () async {
      final walked = Completer<String?>();
      when(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      ).thenAnswer((_) => walked.future);
      final repo = repository()..adopt(_planned(_ws));
      await pumpEventQueue();
      final initialized = repo.initialize();
      await pumpEventQueue();

      expect(repo.readiness, isA<SandboxPreparingHost>());
      expect(await repo.acquire(_spec(_ws)), isA<SandboxInitializing>());
      verifyNever(() => guard.acquire(any()));

      walked.complete(null);
      await initialized;
      expect(repo.readiness, isA<SandboxReady>());
    });

    test('provisions the workspace on initialize, ahead of the first '
        'command', () async {
      final repo = await readied();

      expect(repo.readiness, isA<SandboxReady>());
      verify(() => guard.acquire(any())).called(1);
      expect(await repo.acquire(_spec(_ws)), isA<SandboxAcquired>());
      verifyNever(() => guard.acquire(any()));
    });

    test('fails initialization when the shared read grant fails', () async {
      when(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      ).thenAnswer((_) async => 'denied');

      final repo = await readied();

      expect(repo.readiness, const SandboxInitializationFailed('denied'));
      verifyNever(() => guard.acquire(any()));
    });
  });

  group('ancestors', () {
    test('are the directories above the read roots and the workspace, '
        'less the system trees', () async {
      when(() => guard.systemRoots).thenReturn(const [r'C:\Program Files']);

      await readied(r'D:\code\x');

      final inspected = verify(
        () => guard.unlistedAncestors(captureAny()),
      ).captured;
      expect(inspected.first, [..._ancestors, r'D:\', r'D:\code']);
    });

    test('are granted through the elevated helper before the walk', () async {
      when(
        () => guard.unlistedAncestors(any()),
      ).thenAnswer((_) async => const AncestorsUnlisted([r'C:\Users']));
      final order = <String>[];
      when(() => guard.grantAncestorListing(any())).thenAnswer((_) async {
        order.add('ancestors');
        return const AncestorsGranted();
      });
      when(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      ).thenAnswer((_) async {
        order.add('shared read');
        return null;
      });

      final repo = await readied();

      expect(repo.readiness, isA<SandboxReady>());
      expect(order, ['ancestors', 'shared read']);
      verify(() => guard.grantAncestorListing([r'C:\Users'])).called(1);
    });

    test('a declined prompt fails initialization before the walk', () async {
      when(
        () => guard.unlistedAncestors(any()),
      ).thenAnswer((_) async => const AncestorsUnlisted(_ancestors));
      when(
        () => guard.grantAncestorListing(any()),
      ).thenAnswer((_) async => const AncestorGrantDeclined());

      final repo = await readied();

      expect(
        repo.readiness,
        isA<SandboxInitializationFailed>().having(
          (r) => r.reason,
          'reason',
          contains('declined'),
        ),
      );
      verifyNever(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      );
      expect(store.load().read, isNull);
    });

    test('a failed grant carries its reason', () async {
      when(
        () => guard.unlistedAncestors(any()),
      ).thenAnswer((_) async => const AncestorsUnlisted(_ancestors));
      when(
        () => guard.grantAncestorListing(any()),
      ).thenAnswer((_) async => const AncestorGrantFailed('helper died'));

      final repo = await readied();

      expect(repo.readiness, const SandboxInitializationFailed('helper died'));
    });

    test('an unreadable DACL fails initialization with its reason', () async {
      when(
        () => guard.unlistedAncestors(any()),
      ).thenAnswer((_) async => const AncestorInspectionFailed('unreadable'));

      final repo = await readied();

      expect(repo.readiness, const SandboxInitializationFailed('unreadable'));
    });
  });

  group('shared read reconcile', () {
    test('grants the shared read once on a fresh store', () async {
      await readied();

      verify(
        () => guard.grantSharedRead(
          capabilitySid: 'S-cap',
          readRoots: [_home],
          holes: [r'C:\Users\cow\.ssh'],
        ),
      ).called(1);
      verifyNever(
        () => guard.reverseSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      );
      expect(store.load().read, desiredRead);
    });

    test('skips when the stored grant already matches', () async {
      store.save(const SandboxGrants(read: desiredRead));

      repository().adopt(_planned(_ws));
      await pumpEventQueue();

      verifyNever(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      );
    });

    test('reverses then regrants when the policy version bumps', () async {
      store.save(
        const SandboxGrants(
          read: SandboxReadGrant(
            capabilitySid: 'S-cap',
            readRoots: [_home, r'C:\old'],
            holes: [],
            policyVersion: 0,
          ),
        ),
      );

      await readied();

      verify(
        () => guard.reverseSharedRead(
          capabilitySid: 'S-cap',
          readRoots: [_home, r'C:\old'],
          holes: [],
        ),
      ).called(1);
      verify(
        () => guard.grantSharedRead(
          capabilitySid: 'S-cap',
          readRoots: [_home],
          holes: [r'C:\Users\cow\.ssh'],
        ),
      ).called(1);
      expect(store.load().read, desiredRead);
    });

    test('does not persist a grant that failed', () async {
      when(
        () => guard.grantSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      ).thenAnswer((_) async => 'denied');

      await readied();

      expect(store.load().read, isNull);
    });
  });

  group('workspace ledger', () {
    test('records the workspace for the GC when first seen', () async {
      final repo = await readied();
      final acquisition = await repo.acquire(_spec(_ws));

      expect(acquisition, isA<SandboxAcquired>());
      verify(() => guard.acquire(any())).called(1);

      final entry = store.load().workspaces.single;
      expect(entry.workspaceRoot, _ws);
      expect(entry.profileName, 'bestie.sandbox.hash');
      expect(entry.containerSid, 'S-container');
      expect(entry.lastSeen, _now);
    });

    test('always asks the backend, bumping last-seen when returning', () async {
      store.save(
        SandboxGrants(
          read: desiredRead,
          workspaces: [
            SandboxWorkspaceEntry(
              workspaceRoot: _ws,
              profileName: 'bestie.sandbox.hash',
              containerSid: 'S-container',
              lastSeen: _now.subtract(const Duration(days: 2)),
            ),
          ],
        ),
      );

      final repo = repository()..adopt(_planned(_ws));
      await pumpEventQueue();
      await repo.acquire(_spec(_ws));

      verify(() => guard.acquire(any())).called(1);
      expect(store.load().workspaces.single.lastSeen, _now);
    });

    test('records the roots the spec widens to', () async {
      final repo = await readied();
      await repo.acquire(
        const SandboxSpec(workspaceRoot: _ws, writableRoots: [_ws, _pubCache]),
      );

      expect(store.load().workspaces.single.widenedRoots, [_pubCache]);
    });

    test('takes back the widened roots a narrower spec drops', () async {
      store.save(
        SandboxGrants(
          read: desiredRead,
          workspaces: [
            SandboxWorkspaceEntry(
              workspaceRoot: _ws,
              profileName: 'bestie.sandbox.hash',
              containerSid: 'S-container',
              lastSeen: _now,
              widenedRoots: const [_pubCache, _cargo],
            ),
          ],
        ),
      );
      const kept = SandboxSpec(
        workspaceRoot: _ws,
        writableRoots: [_ws, _cargo],
      );

      repository().adopt(const SandboxPlanned(spec: kept, failClosed: true));
      await pumpEventQueue();

      verifyInOrder([
        () => guard.narrowWorkspace(
          profileName: 'bestie.sandbox.hash',
          roots: [_pubCache],
        ),
        () => guard.acquire(kept),
      ]);
      expect(store.load().workspaces.single.widenedRoots, [_cargo]);
    });

    test('narrows nothing when the spec keeps every widened root', () async {
      store.save(
        SandboxGrants(
          read: desiredRead,
          workspaces: [
            SandboxWorkspaceEntry(
              workspaceRoot: _ws,
              profileName: 'bestie.sandbox.hash',
              containerSid: 'S-container',
              lastSeen: _now,
              widenedRoots: const [_cargo],
            ),
          ],
        ),
      );

      repository().adopt(
        const SandboxPlanned(
          spec: SandboxSpec(
            workspaceRoot: _ws,
            writableRoots: [_ws, _cargo],
          ),
          failClosed: true,
        ),
      );
      await pumpEventQueue();

      verifyNever(
        () => guard.narrowWorkspace(
          profileName: any(named: 'profileName'),
          roots: any(named: 'roots'),
        ),
      );
    });

    test('records nothing when the backend refuses', () async {
      when(() => guard.acquire(any())).thenAnswer(
        (_) async => const SandboxProvisioningFailed(
          operation: 'grant ws',
          reason: 'denied',
        ),
      );

      final repo = await readied();
      await repo.acquire(_spec(_ws));

      expect(store.load().workspaces, isEmpty);
    });
  });

  group('startup GC', () {
    SandboxWorkspaceEntry entry(String root, DateTime lastSeen) =>
        SandboxWorkspaceEntry(
          workspaceRoot: root,
          profileName: 'profile.$root',
          containerSid: 'S-$root',
          lastSeen: lastSeen,
          widenedRoots: ['$root-widened'],
        );

    test('reverses only workspaces unseen past the window', () async {
      store.save(
        SandboxGrants(
          read: desiredRead,
          workspaces: [
            entry(r'C:\stale', _now.subtract(const Duration(days: 40))),
            entry(r'C:\fresh', _now.subtract(const Duration(days: 5))),
          ],
        ),
      );

      repository().adopt(_planned(r'C:\other'));
      await pumpEventQueue();

      verify(
        () => guard.reverseWorkspace(
          profileName: r'profile.C:\stale',
          workspaceRoot: r'C:\stale',
          widenedRoots: [r'C:\stale-widened'],
        ),
      ).called(1);
      verifyNever(
        () => guard.reverseWorkspace(
          profileName: r'profile.C:\fresh',
          workspaceRoot: any(named: 'workspaceRoot'),
          widenedRoots: any(named: 'widenedRoots'),
        ),
      );

      final roots = store.load().workspaces.map((w) => w.workspaceRoot);
      expect(roots, isNot(contains(r'C:\stale')));
      expect(roots, contains(r'C:\fresh'));
    });
  });

  group('reset', () {
    test('reverses the read grant and every workspace, forgets the store, '
        'and gates again', () async {
      store.save(
        SandboxGrants(
          read: desiredRead,
          workspaces: [
            SandboxWorkspaceEntry(
              workspaceRoot: _ws,
              profileName: 'bestie.sandbox.hash',
              containerSid: 'S-container',
              lastSeen: _now,
              widenedRoots: const [_pubCache],
            ),
          ],
        ),
      );
      final repo = repository()
        ..adopt(
          const SandboxPlanned(
            spec: SandboxSpec(
              workspaceRoot: _ws,
              writableRoots: [_ws, _pubCache],
            ),
            failClosed: true,
          ),
        );
      await pumpEventQueue();

      await repo.reset();

      verify(
        () => guard.reverseSharedRead(
          capabilitySid: 'S-cap',
          readRoots: [_home],
          holes: [r'C:\Users\cow\.ssh'],
        ),
      ).called(1);
      verify(
        () => guard.reverseWorkspace(
          profileName: 'bestie.sandbox.hash',
          workspaceRoot: _ws,
          widenedRoots: const [_pubCache],
        ),
      ).called(1);
      expect(fs.file('/home/.bestie/sandboxes.json').existsSync(), isFalse);
      expect(repo.readiness, isA<SandboxAwaitingInitialization>());
    });

    test('with nothing recorded reverses nothing', () async {
      final repo = repository()..adopt(_planned(_ws));
      await pumpEventQueue();

      await repo.reset();

      verifyNever(
        () => guard.reverseSharedRead(
          capabilitySid: any(named: 'capabilitySid'),
          readRoots: any(named: 'readRoots'),
          holes: any(named: 'holes'),
        ),
      );
      verifyNever(
        () => guard.reverseWorkspace(
          profileName: any(named: 'profileName'),
          workspaceRoot: any(named: 'workspaceRoot'),
          widenedRoots: any(named: 'widenedRoots'),
        ),
      );
    });
  });

  group('eviction and dispose', () {
    test('a policy change reverses nothing', () async {
      final repo = await readied();
      await repo.acquire(_spec(_ws));
      await repo.acquire(_spec(r'C:\other'));

      verifyNever(
        () => guard.reverseWorkspace(
          profileName: any(named: 'profileName'),
          workspaceRoot: any(named: 'workspaceRoot'),
          widenedRoots: any(named: 'widenedRoots'),
        ),
      );
    });

    test('dispose reverses nothing and closes the guard', () async {
      final repo = await readied();
      await repo.acquire(_spec(_ws));

      await repo.dispose();

      verifyNever(
        () => guard.reverseWorkspace(
          profileName: any(named: 'profileName'),
          workspaceRoot: any(named: 'workspaceRoot'),
          widenedRoots: any(named: 'widenedRoots'),
        ),
      );
      verify(() => guard.dispose()).called(1);
    });
  });
}
