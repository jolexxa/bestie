import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart' show capabilityInternetClientSid;

class _MockWorker extends Mock implements SandboxWorker {}

class _ForeignSandbox implements Sandbox {}

const _sid = 'S-1-15-2-test';
const _cap = 'S-1-15-3-1024-cow';

void main() {
  late _MockWorker worker;
  late FileSystem fs;

  setUpAll(() {
    registerFallbackValue(
      const ApplyPlan(
        ProvisionPlan(profileName: '', grants: [], network: NetworkTier.none),
      ),
    );
  });

  setUp(() {
    worker = _MockWorker();
    fs = MemoryFileSystem();
    fs.directory('/ws').createSync(recursive: true);

    when(() => worker.send(any())).thenAnswer(
      (_) async => const ProvisionApplied(
        containerSid: _sid,
        tempDir: '/pkg/AC/Temp',
        network: NetworkConfined(NetworkTier.none),
        loopbackExempted: false,
      ),
    );
    when(() => worker.close()).thenAnswer((_) async {});
  });

  SandboxWindows adapter({
    List<String> systemRoots = const [],
    String? bestieReadCapabilitySid,
  }) => SandboxWindows(
    worker,
    bestieReadCapabilitySid: bestieReadCapabilitySid,
    fileSystem: fs,
    systemRoots: systemRoots,
  );

  SandboxSpec spec({
    List<String> readableRoots = const ['/ws'],
    List<String> writableRoots = const ['/ws'],
    NetworkTier network = NetworkTier.none,
  }) => SandboxSpec(
    workspaceRoot: '/ws',
    writableRoots: writableRoots,
    readableRoots: readableRoots,
    network: network,
  );

  Future<SandboxAcquired> acquire(SandboxWindows cg, SandboxSpec s) async =>
      await cg.acquire(s) as SandboxAcquired;

  ProvisionPlan sentPlan() =>
      (verify(() => worker.send(captureAny())).captured.single as ApplyPlan)
          .plan;

  test('reports the system roots it was given', () {
    expect(adapter(systemRoots: const ['/system']).systemRoots, ['/system']);
  });

  group('acquire', () {
    test('a response meant for another request fails the apply', () async {
      when(() => worker.send(any())).thenAnswer((_) async => const Reversed());

      expect(
        await adapter().acquire(spec()),
        isA<SandboxProvisioningFailed>().having(
          (f) => f.operation,
          'operation',
          'apply',
        ),
      );
    });

    test('sends a plan and reports AppContainer enforcement', () async {
      final result = await acquire(adapter(), spec());

      expect(result.enforcement.backend, 'AppContainer');
      expect(result.enforcement.enforced, {
        SandboxCapability.filesystemRead,
        SandboxCapability.filesystemWrite,
      });
      expect((result.sandbox as WindowsSandbox).containerSid, _sid);
    });

    test('plans a write grant for the workspace', () async {
      await acquire(adapter(), spec());

      final grant = sentPlan().grants.singleWhere((g) => g.path == '/ws');
      expect(grant.write, isTrue);
    });

    test('plans no read grants — reads are the shared grant', () async {
      fs.directory('/opt').createSync(recursive: true);

      await acquire(adapter(), spec(readableRoots: const ['/ws', '/opt']));

      expect(sentPlan().grants.map((g) => g.path), ['/ws']);
    });

    test('omits a write grant covered by system roots', () async {
      fs.directory('/system/out').createSync(recursive: true);

      await acquire(
        adapter(systemRoots: const ['/system']),
        spec(writableRoots: const ['/ws', '/system/out']),
      );

      expect(
        sentPlan().grants.map((g) => g.path),
        isNot(contains('/system/out')),
      );
    });

    test('omits a write grant for a path absent on disk', () async {
      await acquire(adapter(), spec(writableRoots: const ['/ws', '/gone']));

      expect(sentPlan().grants.map((g) => g.path), isNot(contains('/gone')));
    });

    test('carries the requested network tier into the plan', () async {
      await acquire(adapter(), spec(network: NetworkTier.all));

      expect(sentPlan().network, NetworkTier.all);
    });

    test(
      'hands the child the container temp and reports it writable',
      () async {
        final result = await acquire(adapter(), spec());

        expect((result.sandbox as WindowsSandbox).tempDir, '/pkg/AC/Temp');
        expect(result.enforcement.writableRoots, contains('/pkg/AC/Temp'));
      },
    );

    test("reflects the worker's network result into enforcement", () async {
      when(() => worker.send(any())).thenAnswer(
        (_) async => const ProvisionApplied(
          containerSid: _sid,
          tempDir: '/pkg/AC/Temp',
          network: NetworkPartiallyConfined(
            NetworkTier.all,
            'loopback',
            'localhost needs Developer Mode',
          ),
          loopbackExempted: false,
        ),
      );

      final result = await acquire(adapter(), spec(network: NetworkTier.all));

      expect(result.enforcement.network, isA<NetworkPartiallyConfined>());
    });

    test('the all tier carries the InternetClient capability', () async {
      final result = await acquire(adapter(), spec(network: NetworkTier.all));

      expect((result.sandbox as WindowsSandbox).capabilitySids, [
        capabilityInternetClientSid,
      ]);
    });

    test(
      'without a bestie-read capability, none and local carry none',
      () async {
        final none = await acquire(adapter(), spec());

        expect((none.sandbox as WindowsSandbox).capabilitySids, isEmpty);
      },
    );

    test('every tier carries the bestie-read capability when set', () async {
      final cg = adapter(bestieReadCapabilitySid: _cap);

      final none = await acquire(cg, spec());
      expect((none.sandbox as WindowsSandbox).capabilitySids, [_cap]);

      final all = await cg.acquire(spec(network: NetworkTier.all));
      expect((all as SandboxAcquired).sandbox, isA<WindowsSandbox>());
      expect((all.sandbox as WindowsSandbox).capabilitySids, [
        _cap,
        capabilityInternetClientSid,
      ]);
    });

    test('a worker failure returns SandboxProvisioningFailed', () async {
      when(() => worker.send(any())).thenAnswer(
        (_) async => const ProvisionFailedResponse(
          operation: 'grant /ws',
          reason: 'denied',
        ),
      );

      expect(await adapter().acquire(spec()), isA<SandboxProvisioningFailed>());
    });
  });

  group('release', () {
    test('reverses nothing — grants persist for the startup GC', () async {
      final cg = adapter();
      final result = await acquire(cg, spec());

      await cg.release(result.sandbox);

      verify(() => worker.send(any())).called(1); // only the acquire
    });

    test('is a no-op for a foreign sandbox', () async {
      await adapter().release(_ForeignSandbox());

      verifyNever(() => worker.send(any()));
    });
  });

  group('shared read', () {
    test(
      'grants the present roots and holes, mapping applied to null',
      () async {
        fs.directory('/home').createSync();
        fs.directory('/home/.ssh').createSync();
        when(
          () => worker.send(any()),
        ).thenAnswer((_) async => const SharedReadApplied());

        final reason = await adapter().grantSharedRead(
          capabilitySid: _cap,
          readRoots: const ['/home'],
          holes: const ['/home/.ssh'],
        );

        expect(reason, isNull);
        final sent =
            verify(() => worker.send(captureAny())).captured.single
                as GrantSharedRead;
        expect(sent.capabilitySid, _cap);
        expect(sent.readRoots, ['/home']);
        expect(sent.holes, ['/home/.ssh']);
      },
    );

    test('skips holes and roots that do not exist on disk', () async {
      fs.directory('/home').createSync();
      when(
        () => worker.send(any()),
      ).thenAnswer((_) async => const SharedReadApplied());

      await adapter().grantSharedRead(
        capabilitySid: _cap,
        readRoots: const ['/home', '/gone'],
        holes: const ['/home/.ssh'],
      );

      final sent =
          verify(() => worker.send(captureAny())).captured.single
              as GrantSharedRead;
      expect(sent.readRoots, ['/home']);
      expect(sent.holes, isEmpty);
    });

    test('maps a failure response to its reason', () async {
      when(() => worker.send(any())).thenAnswer(
        (_) async => const ProvisionFailedResponse(
          operation: 'shared read /home',
          reason: 'denied',
        ),
      );

      final reason = await adapter().grantSharedRead(
        capabilitySid: _cap,
        readRoots: const ['/home'],
        holes: const [],
      );

      expect(reason, contains('denied'));
    });

    test('reverse sends a ReverseSharedRead', () async {
      fs.directory('/home').createSync();
      fs.directory('/home/.ssh').createSync();
      when(() => worker.send(any())).thenAnswer((_) async => const Reversed());

      await adapter().reverseSharedRead(
        capabilitySid: _cap,
        readRoots: const ['/home'],
        holes: const ['/home/.ssh'],
      );

      expect(
        verify(() => worker.send(captureAny())).captured.single,
        isA<ReverseSharedRead>()
            .having((r) => r.readRoots, 'readRoots', ['/home'])
            .having((r) => r.holes, 'holes', ['/home/.ssh']),
      );
    });
  });

  group('ancestors', () {
    const ancestors = [r'C:\', r'C:\Users'];

    SandboxWindows withHelper() => SandboxWindows(
      worker,
      bestieReadCapabilitySid: _cap,
      helperExecutable: r'C:\dart.exe',
      helperArguments: const ['run', r'C:\bestie.dart'],
      fileSystem: fs,
      systemRoots: const [],
    );

    test('are all listable without a capability, asking nothing', () async {
      expect(
        await adapter().unlistedAncestors(ancestors),
        isA<AncestorsListable>(),
      );
      verifyNever(() => worker.send(any()));
    });

    test('an empty set is listable, asking nothing', () async {
      expect(
        await withHelper().unlistedAncestors(const []),
        isA<AncestorsListable>(),
      );
      verifyNever(() => worker.send(any()));
    });

    test('inspection reports the unlisted ones', () async {
      when(
        () => worker.send(any()),
      ).thenAnswer((_) async => const AncestorsInspected([r'C:\Users']));

      final inspection = await withHelper().unlistedAncestors(ancestors);

      expect(
        inspection,
        isA<AncestorsUnlisted>().having(
          (i) => i.missing,
          'missing',
          [r'C:\Users'],
        ),
      );
      expect(
        verify(() => worker.send(captureAny())).captured.single,
        isA<InspectAncestors>()
            .having((r) => r.capabilitySid, 'capabilitySid', _cap)
            .having((r) => r.paths, 'paths', ancestors),
      );
    });

    test('inspection with nothing missing is listable', () async {
      when(
        () => worker.send(any()),
      ).thenAnswer((_) async => const AncestorsInspected([]));

      expect(
        await withHelper().unlistedAncestors(ancestors),
        isA<AncestorsListable>(),
      );
    });

    test('inspection maps a worker failure to its reason', () async {
      when(() => worker.send(any())).thenAnswer(
        (_) async => const ProvisionFailedResponse(
          operation: 'worker',
          reason: 'gone',
        ),
      );

      final inspection = await withHelper().unlistedAncestors(ancestors);

      expect(
        inspection,
        isA<AncestorInspectionFailed>().having(
          (i) => i.reason,
          'reason',
          contains('gone'),
        ),
      );
    });

    test('granting sends the helper executable to the worker', () async {
      when(
        () => worker.send(any()),
      ).thenAnswer((_) async => const AncestorGrantApplied());

      final outcome = await withHelper().grantAncestorListing(ancestors);

      expect(outcome, isA<AncestorsGranted>());
      expect(
        verify(() => worker.send(captureAny())).captured.single,
        isA<GrantAncestors>()
            .having((r) => r.executable, 'executable', r'C:\dart.exe')
            .having((r) => r.leadingArguments, 'leadingArguments', [
              'run',
              r'C:\bestie.dart',
            ])
            .having((r) => r.paths, 'paths', ancestors),
      );
    });

    test('granting reports a declined prompt', () async {
      when(
        () => worker.send(any()),
      ).thenAnswer((_) async => const AncestorGrantRefused());

      expect(
        await withHelper().grantAncestorListing(ancestors),
        isA<AncestorGrantDeclined>(),
      );
    });

    test('granting maps a worker failure to its reason', () async {
      when(() => worker.send(any())).thenAnswer(
        (_) async => const ProvisionFailedResponse(
          operation: 'elevate',
          reason: 'no shell',
        ),
      );

      final outcome = await withHelper().grantAncestorListing(ancestors);

      expect(
        outcome,
        isA<AncestorGrantFailed>().having(
          (o) => o.reason,
          'reason',
          'elevate: no shell',
        ),
      );
    });

    test('granting fails without a helper, asking nothing', () async {
      expect(
        await adapter(
          bestieReadCapabilitySid: _cap,
        ).grantAncestorListing(ancestors),
        isA<AncestorGrantFailed>(),
      );
      verifyNever(() => worker.send(any()));
    });
  });

  group('reverse workspace', () {
    test('sends a ReverseWorkspace for the profile and roots', () async {
      when(() => worker.send(any())).thenAnswer((_) async => const Reversed());

      await adapter().reverseWorkspace(
        profileName: 'bestie.sandbox.abc',
        workspaceRoot: '/ws',
        widenedRoots: const ['/home/.pub-cache'],
      );

      expect(
        verify(() => worker.send(captureAny())).captured.single,
        isA<ReverseWorkspace>()
            .having((r) => r.profileName, 'profileName', 'bestie.sandbox.abc')
            .having((r) => r.workspaceRoot, 'workspaceRoot', '/ws')
            .having((r) => r.widenedRoots, 'widenedRoots', [
              '/home/.pub-cache',
            ]),
      );
    });
  });

  group('narrow workspace', () {
    test('sends a NarrowWorkspace for the profile and roots', () async {
      when(() => worker.send(any())).thenAnswer((_) async => const Reversed());

      await adapter().narrowWorkspace(
        profileName: 'bestie.sandbox.abc',
        roots: const ['/home/.pub-cache'],
      );

      expect(
        verify(() => worker.send(captureAny())).captured.single,
        isA<NarrowWorkspace>()
            .having((r) => r.profileName, 'profileName', 'bestie.sandbox.abc')
            .having((r) => r.roots, 'roots', ['/home/.pub-cache']),
      );
    });
  });

  group('dispose', () {
    test('closes the worker', () async {
      await adapter().dispose();

      verify(() => worker.close()).called(1);
    });
  });
}
