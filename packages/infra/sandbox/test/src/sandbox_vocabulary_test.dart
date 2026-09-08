import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

class _MockSandbox extends Mock implements Sandbox {}

const _enforcement = SandboxEnforcement(
  enforced: {SandboxCapability.filesystemWrite},
  network: NetworkConfined(NetworkTier.local),
  backend: 'Landlock v1',
  writableRoots: ['/work'],
);

void main() {
  group('value types compare by value', () {
    test('a spec equals one built the same way', () {
      expect(
        const SandboxSpec(workspaceRoot: '/work', deniedReads: ['~/.ssh']),
        const SandboxSpec(workspaceRoot: '/work', deniedReads: ['~/.ssh']),
      );
    });

    test('a spec differs when a denied read differs', () {
      expect(
        const SandboxSpec(workspaceRoot: '/work', deniedReads: ['~/.ssh']),
        isNot(const SandboxSpec(workspaceRoot: '/work')),
      );
    });

    test('a spec leaves the network unrestricted unless asked', () {
      expect(
        const SandboxSpec(workspaceRoot: '/work').network,
        NetworkTier.all,
      );
    });

    test('enforcement equals one reporting the same restrictions', () {
      expect(_enforcement, _enforcement.copyWith());
    });

    test('enforcement differs when the backend differs', () {
      expect(_enforcement, isNot(_enforcement.copyWith(backend: 'Seatbelt')));
    });

    test('a tier that could not be enforced names what was asked for', () {
      const enforcement = NetworkIneligibleForConfinement(
        NetworkTier.local,
        'no userns',
      );

      expect(enforcement.requested, NetworkTier.local);
      expect(enforcement.reason, 'no userns');
    });

    test('a suspicion equals one over the same evidence', () {
      expect(
        const SandboxSuspicion(
          dimension: SandboxDimension.network,
          evidence: ['connection refused'],
        ),
        const SandboxSuspicion(
          dimension: SandboxDimension.network,
          evidence: ['connection refused'],
        ),
      );
    });

    test('a suspicion carries no evidence unless given some', () {
      expect(
        const SandboxSuspicion(dimension: SandboxDimension.network).evidence,
        isEmpty,
      );
    });
  });

  group('acquisition outcomes', () {
    test('an acquired sandbox carries what it enforces', () {
      final sandbox = _MockSandbox();

      final acquired = SandboxAcquired(sandbox, _enforcement);

      expect(acquired.sandbox, same(sandbox));
      expect(acquired.enforcement, _enforcement);
    });

    test('a declined consent names the path it was refused for', () {
      expect(const SandboxConsentDeclined('/work').path, '/work');
    });

    test('a failed provisioning names the operation and why', () {
      const failure = SandboxProvisioningFailed(
        operation: 'SetNamedSecurityInfoW',
        reason: 'Access is denied.',
      );

      expect(failure.operation, 'SetNamedSecurityInfoW');
      expect(failure.reason, 'Access is denied.');
    });

    test('an unavailable sandbox says why confinement is out of reach', () {
      expect(const SandboxUnavailable('no kernel support').reason, isNotEmpty);
    });

    test('an initializing sandbox is a distinct not-ready-yet outcome', () {
      expect(const SandboxInitializing(), isA<SandboxAcquisition>());
    });
  });
}
