import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_windows/src/ancestor_grant_helper.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:sandbox_windows/src/windows_elevator.dart';
import 'package:sandbox_windows/src/windows_provision_command_handler.dart';
import 'package:sandbox_windows/src/windows_provisioner.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart' show NO_INHERITANCE;

class _MockProvisioner extends Mock implements WindowsProvisioner {}

class _MockElevator extends Mock implements WindowsElevator {}

const _sid = 'S-1-15-2-test';
const _cap = 'S-1-15-3-1024-cow';
const _folder = r'C:\Users\cow\AppData\Local\Packages\bestie.sandbox.test';
const _tempDir =
    r'C:\Users\cow\AppData\Local\Packages\bestie.sandbox.test\AC\Temp';

void main() {
  late _MockProvisioner provisioner;
  late _MockElevator elevator;
  late FileSystem fs;

  setUp(() {
    provisioner = _MockProvisioner();
    elevator = _MockElevator();
    fs = MemoryFileSystem(style: FileSystemStyle.windows);
    when(
      () => provisioner.provision(any()),
    ).thenReturn(const ProvisionSucceeded(_sid, folder: _folder));
    when(
      () => provisioner.grant(
        containerSid: any(named: 'containerSid'),
        path: any(named: 'path'),
        write: any(named: 'write'),
      ),
    ).thenReturn(null);
    when(
      () => provisioner.holds(
        containerSid: any(named: 'containerSid'),
        path: any(named: 'path'),
        write: any(named: 'write'),
      ),
    ).thenReturn(const GrantMissing());
    when(
      () => provisioner.grantCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: any(named: 'path'),
      ),
    ).thenReturn(null);
    when(() => provisioner.protect(any())).thenReturn(null);
    when(
      () => provisioner.holdsCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: any(named: 'path'),
        inheritance: any(named: 'inheritance'),
      ),
    ).thenReturn(const GrantHeld());
    when(
      () => provisioner.addLoopback(any()),
    ).thenReturn(const LoopbackApplied());
  });

  WindowsProvisionCommandHandler handler() => WindowsProvisionCommandHandler(
    provisioner: provisioner,
    elevator: elevator,
    fileSystem: fs,
  );

  ProvisionPlan plan({
    List<PlanGrant> grants = const [PlanGrant('/ws', write: true)],
    NetworkTier network = NetworkTier.none,
  }) => ProvisionPlan(
    profileName: 'bestie.sandbox.test',
    grants: grants,
    network: network,
  );

  Future<ProvisionResponse> apply(
    WindowsProvisionCommandHandler h,
    ProvisionPlan p,
  ) async => h.call(ApplyPlan(p));

  group('apply', () {
    test('provisions, grants, and returns Applied', () async {
      final response = await apply(handler(), plan());

      expect(
        response,
        isA<ProvisionApplied>().having((r) => r.containerSid, 'sid', _sid),
      );
      verify(() => provisioner.provision('bestie.sandbox.test')).called(1);
      verify(
        () => provisioner.grant(containerSid: _sid, path: '/ws', write: true),
      ).called(1);
    });

    test(
      'an empty grant list still provisions and reconciles network',
      () async {
        final response = await apply(handler(), plan(grants: const []));

        expect(response, isA<ProvisionApplied>());
        verifyNever(
          () => provisioner.grant(
            containerSid: any(named: 'containerSid'),
            path: any(named: 'path'),
            write: any(named: 'write'),
          ),
        );
      },
    );

    test(
      'creates the container temp inside its profile and reports it',
      () async {
        final response = await apply(handler(), plan());

        expect(
          response,
          isA<ProvisionApplied>().having((r) => r.tempDir, 'tempDir', _tempDir),
        );
        expect(fs.directory(_tempDir).existsSync(), isTrue);
      },
    );

    test('a temp that cannot be created tears the profile down', () async {
      // A file squatting where the folder must go makes creation fail.
      fs.file(fs.path.join(_folder, 'AC')).createSync(recursive: true);

      final response = await apply(handler(), plan());

      expect(
        response,
        isA<ProvisionFailedResponse>().having(
          (r) => r.operation,
          'operation',
          startsWith('temp '),
        ),
      );
      verify(() => provisioner.dispose(_sid)).called(1);
      verifyNever(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      );
    });

    test('a provision failure applies nothing', () async {
      when(
        () => provisioner.provision(any()),
      ).thenReturn(const ProvisionFailed('nope'));

      final response = await apply(handler(), plan());

      expect(response, isA<ProvisionFailedResponse>());
      verifyNever(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      );
    });

    test('a grant failure tears down what was provisioned', () async {
      when(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      ).thenReturn('access denied');

      final response = await apply(handler(), plan());

      expect(response, isA<ProvisionFailedResponse>());
      verify(() => provisioner.dispose(_sid)).called(1);
    });

    test('skips a grant the DACL already holds', () async {
      when(
        () => provisioner.holds(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      ).thenReturn(const GrantHeld());

      final response = await apply(handler(), plan());

      expect(response, isA<ProvisionApplied>());
      verifyNever(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      );
    });

    test('re-applies a grant the DACL has lost', () async {
      final response = await apply(handler(), plan());

      expect(response, isA<ProvisionApplied>());
      verify(
        () => provisioner.holds(containerSid: _sid, path: '/ws', write: true),
      ).called(1);
      verify(
        () => provisioner.grant(containerSid: _sid, path: '/ws', write: true),
      ).called(1);
    });

    test('an inspection failure tears down what was provisioned', () async {
      when(
        () => provisioner.holds(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      ).thenReturn(const GrantInspectionFailed('unreadable'));

      final response = await apply(handler(), plan());

      expect(
        response,
        isA<ProvisionFailedResponse>()
            .having((r) => r.operation, 'operation', 'inspect /ws')
            .having((r) => r.reason, 'reason', 'unreadable'),
      );
      verify(() => provisioner.dispose(_sid)).called(1);
      verifyNever(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
          write: any(named: 'write'),
        ),
      );
    });

    test('a later failure revokes only what this call granted', () async {
      when(
        () => provisioner.holds(
          containerSid: any(named: 'containerSid'),
          path: '/held',
          write: any(named: 'write'),
        ),
      ).thenReturn(const GrantHeld());
      when(
        () => provisioner.grant(
          containerSid: any(named: 'containerSid'),
          path: '/broken',
          write: any(named: 'write'),
        ),
      ).thenReturn('access denied');

      final response = await apply(
        handler(),
        plan(
          grants: const [
            PlanGrant('/held', write: true),
            PlanGrant('/ws', write: true),
            PlanGrant('/broken', write: true),
          ],
        ),
      );

      expect(response, isA<ProvisionFailedResponse>());
      verify(
        () => provisioner.revoke(containerSid: _sid, path: '/ws'),
      ).called(1);
      verifyNever(() => provisioner.revoke(containerSid: _sid, path: '/held'));
    });
  });

  group('network', () {
    Future<ProvisionApplied> applyTier(NetworkTier tier) async =>
        await apply(handler(), plan(network: tier)) as ProvisionApplied;

    test('none never touches the loopback exemption', () async {
      final response = await applyTier(NetworkTier.none);

      expect(response.network, isA<NetworkConfined>());
      expect(response.loopbackExempted, isFalse);
      verifyNever(() => provisioner.addLoopback(any()));
    });

    test('local with Developer Mode is confined and exempted', () async {
      final response = await applyTier(NetworkTier.local);

      expect(
        response.network,
        isA<NetworkConfined>().having((n) => n.tier, 'tier', NetworkTier.local),
      );
      expect(response.loopbackExempted, isTrue);
    });

    test('all with Developer Mode is confined and exempted', () async {
      final response = await applyTier(NetworkTier.all);

      expect(
        response.network,
        isA<NetworkConfined>().having((n) => n.tier, 'tier', NetworkTier.all),
      );
      expect(response.loopbackExempted, isTrue);
    });

    test('local without Developer Mode is ineligible', () async {
      when(
        () => provisioner.addLoopback(any()),
      ).thenReturn(const LoopbackDeveloperModeOff());

      final response = await applyTier(NetworkTier.local);

      expect(response.network, isA<NetworkIneligibleForConfinement>());
      expect(response.loopbackExempted, isFalse);
    });

    test('all without Developer Mode keeps internet, loses loopback', () async {
      when(
        () => provisioner.addLoopback(any()),
      ).thenReturn(const LoopbackDeveloperModeOff());

      final response = await applyTier(NetworkTier.all);

      expect(response.network, isA<NetworkPartiallyConfined>());
      expect(response.loopbackExempted, isFalse);
    });

    test('a loopback failure degrades local to ineligible', () async {
      when(
        () => provisioner.addLoopback(any()),
      ).thenReturn(const LoopbackFailed('boom'));

      final response = await applyTier(NetworkTier.local);

      expect(response.network, isA<NetworkIneligibleForConfinement>());
    });

    test('a loopback failure degrades all to partially confined', () async {
      when(
        () => provisioner.addLoopback(any()),
      ).thenReturn(const LoopbackFailed('boom'));

      final response = await applyTier(NetworkTier.all);

      expect(response.network, isA<NetworkPartiallyConfined>());
    });
  });

  group('shared read', () {
    GrantSharedRead grant({
      List<String> readRoots = const ['/home'],
      List<String> holes = const [],
    }) => GrantSharedRead(
      capabilitySid: _cap,
      readRoots: readRoots,
      holes: holes,
    );

    test('grants each root to the capability and returns applied', () async {
      final response = await handler().call(
        grant(readRoots: const ['/home', '/opt/bin']),
      );

      expect(response, isA<SharedReadApplied>());
      verify(
        () => provisioner.grantCapability(capabilitySid: _cap, path: '/home'),
      ).called(1);
      verify(
        () =>
            provisioner.grantCapability(capabilitySid: _cap, path: '/opt/bin'),
      ).called(1);
    });

    test('carves each hole', () async {
      await handler().call(grant(holes: const ['/home/.ssh']));

      verify(() => provisioner.protect('/home/.ssh')).called(1);
    });

    test('a capability grant failure reverses what was granted', () async {
      when(
        () => provisioner.grantCapability(
          capabilitySid: any(named: 'capabilitySid'),
          path: '/opt/bin',
        ),
      ).thenReturn('access denied');

      final response = await handler().call(
        grant(readRoots: const ['/home', '/opt/bin']),
      );

      expect(response, isA<ProvisionFailedResponse>());
      verify(
        () => provisioner.revokeCapability(capabilitySid: _cap, path: '/home'),
      ).called(1);
    });

    test('reverse skips a root that never held the capability', () async {
      when(
        () => provisioner.holdsCapability(
          capabilitySid: any(named: 'capabilitySid'),
          path: '/never',
          inheritance: any(named: 'inheritance'),
        ),
      ).thenReturn(const GrantMissing());

      await handler().call(
        const ReverseSharedRead(
          capabilitySid: _cap,
          readRoots: ['/home', '/never'],
          holes: [],
        ),
      );

      verify(
        () => provisioner.revokeCapability(capabilitySid: _cap, path: '/home'),
      ).called(1);
      verifyNever(
        () => provisioner.revokeCapability(capabilitySid: _cap, path: '/never'),
      );
    });

    test('reverse undoes holes then revokes each root', () async {
      final response = await handler().call(
        const ReverseSharedRead(
          capabilitySid: _cap,
          readRoots: ['/home'],
          holes: ['/home/.ssh'],
        ),
      );

      expect(response, isA<Reversed>());
      verify(() => provisioner.unprotect('/home/.ssh')).called(1);
      verify(
        () => provisioner.revokeCapability(capabilitySid: _cap, path: '/home'),
      ).called(1);
    });
  });

  group('ancestors', () {
    void holding(Map<String, GrantInspection> byPath) {
      for (final entry in byPath.entries) {
        when(
          () => provisioner.holdsCapability(
            capabilitySid: any(named: 'capabilitySid'),
            path: entry.key,
            inheritance: any(named: 'inheritance'),
          ),
        ).thenReturn(entry.value);
      }
    }

    const inspect = InspectAncestors(
      capabilitySid: _cap,
      paths: [r'C:\', r'C:\Users'],
    );
    const grant = GrantAncestors(
      capabilitySid: _cap,
      paths: [r'C:\', r'C:\Users'],
      executable: r'C:\bestie.exe',
      leadingArguments: ['run', r'C:\bestie.dart'],
    );

    test('inspect reports the paths not held this-folder-only', () async {
      holding({
        r'C:\': const GrantHeld(),
        r'C:\Users': const GrantMissing(),
      });

      final response = await handler().call(inspect);

      expect(
        response,
        isA<AncestorsInspected>().having(
          (r) => r.missing,
          'missing',
          [r'C:\Users'],
        ),
      );
      verify(
        () => provisioner.holdsCapability(
          capabilitySid: _cap,
          path: r'C:\',
          inheritance: NO_INHERITANCE,
        ),
      ).called(1);
    });

    test('inspect counts an unreadable DACL as missing', () async {
      holding({
        r'C:\': const GrantInspectionFailed('unreadable'),
        r'C:\Users': const GrantHeld(),
      });

      final response = await handler().call(inspect);

      expect((response as AncestorsInspected).missing, [r'C:\']);
    });

    test(
      'grant runs the helper elevated and confirms from the DACLs',
      () async {
        holding({r'C:\': const GrantHeld(), r'C:\Users': const GrantHeld()});
        when(
          () => elevator.run(
            executable: any(named: 'executable'),
            arguments: any(named: 'arguments'),
          ),
        ).thenReturn(const ElevatedRunCompleted(0));

        final response = await handler().call(grant);

        expect(response, isA<AncestorGrantApplied>());
        verify(
          () => elevator.run(
            executable: r'C:\bestie.exe',
            arguments: [
              'run',
              r'C:\bestie.dart',
              grantSandboxAncestorsFlag,
              r'C:\',
              r'C:\Users',
            ],
          ),
        ).called(1);
      },
    );

    test('grant is refused when the user declines the prompt', () async {
      when(
        () => elevator.run(
          executable: any(named: 'executable'),
          arguments: any(named: 'arguments'),
        ),
      ).thenReturn(const ElevatedRunDeclined());

      final response = await handler().call(grant);

      expect(response, isA<AncestorGrantRefused>());
      verifyNever(
        () => provisioner.holdsCapability(
          capabilitySid: any(named: 'capabilitySid'),
          path: any(named: 'path'),
          inheritance: any(named: 'inheritance'),
        ),
      );
    });

    test('grant fails when the helper cannot run', () async {
      when(
        () => elevator.run(
          executable: any(named: 'executable'),
          arguments: any(named: 'arguments'),
        ),
      ).thenReturn(const ElevatedRunFailed('no shell'));

      final response = await handler().call(grant);

      expect(
        response,
        isA<ProvisionFailedResponse>()
            .having((r) => r.operation, 'operation', 'elevate')
            .having((r) => r.reason, 'reason', 'no shell'),
      );
    });

    test('grant fails, naming what stayed unlisted, when the DACLs say '
        'so after the helper', () async {
      holding({r'C:\': const GrantHeld(), r'C:\Users': const GrantMissing()});
      when(
        () => elevator.run(
          executable: any(named: 'executable'),
          arguments: any(named: 'arguments'),
        ),
      ).thenReturn(const ElevatedRunCompleted(2));

      final response = await handler().call(grant);

      expect(
        response,
        isA<ProvisionFailedResponse>()
            .having((r) => r.operation, 'operation', 'grant ancestors')
            .having((r) => r.reason, 'reason', contains(r'C:\Users'))
            .having((r) => r.reason, 'reason', contains('2')),
      );
    });
  });

  group('narrow workspace', () {
    test('derives and revokes each root, keeping the profile', () async {
      final response = await handler().call(
        const NarrowWorkspace(
          profileName: 'bestie.sandbox.test',
          roots: ['/home/.pub-cache', '/home/.cargo'],
        ),
      );

      expect(response, isA<Reversed>());
      verify(() => provisioner.provision('bestie.sandbox.test')).called(1);
      verify(
        () => provisioner.revoke(containerSid: _sid, path: '/home/.pub-cache'),
      ).called(1);
      verify(
        () => provisioner.revoke(containerSid: _sid, path: '/home/.cargo'),
      ).called(1);
      verifyNever(() => provisioner.removeLoopback(any()));
      verifyNever(() => provisioner.dispose(any()));
    });

    test('a profile that cannot be derived is a no-op', () async {
      when(
        () => provisioner.provision(any()),
      ).thenReturn(const ProvisionFailed('gone'));

      final response = await handler().call(
        const NarrowWorkspace(
          profileName: 'bestie.sandbox.gone',
          roots: ['/home/.pub-cache'],
        ),
      );

      expect(response, isA<Reversed>());
      verifyNever(
        () => provisioner.revoke(
          containerSid: any(named: 'containerSid'),
          path: any(named: 'path'),
        ),
      );
    });
  });

  group('reverse workspace', () {
    test(
      'derives, revokes the write grants, and deletes the profile',
      () async {
        final response = await handler().call(
          const ReverseWorkspace(
            profileName: 'bestie.sandbox.test',
            workspaceRoot: '/ws',
            widenedRoots: ['/home/.pub-cache'],
          ),
        );

        expect(response, isA<Reversed>());
        verify(() => provisioner.provision('bestie.sandbox.test')).called(1);
        verify(
          () => provisioner.revoke(containerSid: _sid, path: '/ws'),
        ).called(1);
        verify(
          () =>
              provisioner.revoke(containerSid: _sid, path: '/home/.pub-cache'),
        ).called(1);
        verify(() => provisioner.removeLoopback(_sid)).called(1);
        verify(() => provisioner.dispose(_sid)).called(1);
      },
    );

    test('a profile that cannot be derived is a no-op reversal', () async {
      when(
        () => provisioner.provision(any()),
      ).thenReturn(const ProvisionFailed('gone'));

      final response = await handler().call(
        const ReverseWorkspace(
          profileName: 'bestie.sandbox.gone',
          workspaceRoot: '/ws',
          widenedRoots: [],
        ),
      );

      expect(response, isA<Reversed>());
      verifyNever(() => provisioner.dispose(any()));
    });
  });
}
