import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

class _MockForeignSandbox extends Mock implements Sandbox {}

class _ConfinedSandbox implements ConfinedSandbox {
  _ConfinedSandbox(this.enforcement);

  @override
  final SandboxEnforcement enforcement;
}

SandboxEnforcement _enforcing(
  Set<SandboxCapability> capabilities, {
  NetworkEnforcement network = const NetworkConfined(NetworkTier.all),
}) => SandboxEnforcement(
  enforced: capabilities,
  network: network,
  backend: 'test',
);

Sandbox _sandboxEnforcing(
  Set<SandboxCapability> capabilities, {
  NetworkEnforcement network = const NetworkConfined(NetworkTier.all),
}) => _ConfinedSandbox(_enforcing(capabilities, network: network));

List<SandboxDimension> _dimensionsOf(List<SandboxSuspicion> suspicions) => [
  for (final suspicion in suspicions) suspicion.dimension,
];

void main() {
  group('when there is nothing to explain', () {
    test('a clean exit raises nothing, however loud the output', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(0),
        sandbox: _sandboxEnforcing(SandboxCapability.values.toSet()),
        output: const ['permission denied'],
      );

      expect(suspicions, isEmpty);
    });

    test('an unconfined child raises nothing', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: null,
        output: const ['permission denied'],
      );

      expect(suspicions, isEmpty);
    });

    test('a sandbox from another layer raises nothing', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _MockForeignSandbox(),
        output: const ['permission denied'],
      );

      expect(suspicions, isEmpty);
    });

    test('a sandbox enforcing nothing raises nothing', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(const {}),
        output: const ['permission denied'],
      );

      expect(suspicions, isEmpty);
    });
  });

  group('liveness', () {
    test('raises a suspicion with no evidence at all', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(const {SandboxCapability.filesystemRead}),
        output: const ['nothing to see here'],
      );

      expect(_dimensionsOf(suspicions), [SandboxDimension.filesystemRead]);
      expect(suspicions.single.evidence, isEmpty);
    });

    test('raises only the dimensions actually enforced', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(const {SandboxCapability.filesystemWrite}),
        output: const [],
      );

      expect(_dimensionsOf(suspicions), [SandboxDimension.filesystemWrite]);
    });

    test('signals raise suspicions the same as a nonzero exit', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessSignaled(9),
        sandbox: _sandboxEnforcing(const {SandboxCapability.filesystemRead}),
        output: const [],
      );

      expect(_dimensionsOf(suspicions), [SandboxDimension.filesystemRead]);
    });

    test('a confined network tier is live', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(
          const {},
          network: const NetworkConfined(NetworkTier.local),
        ),
        output: const [],
      );

      expect(_dimensionsOf(suspicions), [SandboxDimension.network]);
    });

    test('an unrestricted network tier is not', () {
      // `all` is the helper's default, and the whole point: an unconfined
      // tier can never be the reason anything failed.
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(const {}),
        output: const ['connection refused'],
      );

      expect(suspicions, isEmpty);
    });

    test('a tier this machine cannot enforce is not', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(
          const {},
          network: const NetworkIneligibleForConfinement(
            NetworkTier.local,
            'no unprivileged user namespaces',
          ),
        ),
        output: const ['connection refused'],
      );

      expect(suspicions, isEmpty);
    });
  });

  group('evidence', () {
    test('travels with the dimension it belongs to', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(
          const {SandboxCapability.filesystemRead},
          network: const NetworkConfined(NetworkTier.none),
        ),
        output: const [
          'cat: /etc/shadow: Permission denied',
          'curl: (7) Connection refused',
        ],
      );

      expect(suspicions, hasLength(2));
      expect(suspicions.first.evidence, const [
        'cat: /etc/shadow: Permission denied',
      ]);
      expect(suspicions.last.evidence, const ['curl: (7) Connection refused']);
    });

    test('keeps the child wording while matching case-insensitively', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(const {SandboxCapability.filesystemRead}),
        output: const ['OPERATION NOT PERMITTED'],
      );

      expect(suspicions.single.evidence, const ['OPERATION NOT PERMITTED']);
    });

    test('a line matching two dimensions appears under both', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(SandboxCapability.values.toSet()),
        output: const ['open: permission denied'],
      );

      expect(_dimensionsOf(suspicions), const [
        SandboxDimension.filesystemRead,
        SandboxDimension.filesystemWrite,
      ]);
      for (final suspicion in suspicions) {
        expect(suspicion.evidence, const ['open: permission denied']);
      }
    });

    test('a read-only filesystem points at writes alone', () {
      final suspicions = const SandboxSuspector().suspect(
        exit: const ProcessExited(1),
        sandbox: _sandboxEnforcing(SandboxCapability.values.toSet()),
        output: const ['touch: Read-only file system'],
      );

      expect(suspicions.first.evidence, isEmpty);
      expect(suspicions.last.evidence, const [
        'touch: Read-only file system',
      ]);
    });
  });
}
