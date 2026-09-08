import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

class _MockSandboxBackend extends Mock implements SandboxBackend {}

class _FakeSandbox implements Sandbox {}

const _enforcement = SandboxEnforcement(
  enforced: {},
  network: NetworkConfined(NetworkTier.none),
  backend: 'test',
);

const _spec = SandboxSpec(workspaceRoot: '/work');

void main() {
  setUpAll(() {
    registerFallbackValue(_spec);
    registerFallbackValue(_FakeSandbox());
  });

  late _MockSandboxBackend guard;
  late SandboxRepository repository;

  setUp(() {
    guard = _MockSandboxBackend();
    repository = SandboxRepository(guard);
    when(() => guard.release(any())).thenAnswer((_) async {});
    when(() => guard.dispose()).thenAnswer((_) async {});
  });

  void whenAcquires(SandboxAcquisition acquisition) =>
      when(() => guard.acquire(any())).thenAnswer((_) async => acquisition);

  Future<ConfinementDecision> confine({bool failClosed = true}) {
    repository.adopt(SandboxPlanned(spec: _spec, failClosed: failClosed));
    return repository.confine();
  }

  group('confine', () {
    test('runs unconfined when the sandbox is off, asking nothing', () async {
      expect(await repository.confine(), isA<Unconfined>());
      verifyNever(() => guard.acquire(any()));
    });

    test('confines with the sandbox provisioned for the plan', () async {
      final sandbox = _FakeSandbox();
      whenAcquires(SandboxAcquired(sandbox, _enforcement));

      final decision = await confine();

      expect(
        decision,
        isA<Confined>().having((d) => d.sandbox, 'sandbox', same(sandbox)),
      );
      verify(() => guard.acquire(_spec)).called(1);
    });

    test('refuses when a required sandbox cannot be acquired', () async {
      whenAcquires(const SandboxUnavailable('no seatbelt here'));

      final decision = await confine();

      expect(
        decision,
        isA<ConfinementRefused>().having(
          (d) => d.reason,
          'reason',
          'no seatbelt here',
        ),
      );
    });

    test('runs unconfined on a soft failure when fail-closed is off', () async {
      whenAcquires(const SandboxUnavailable('no seatbelt here'));

      expect(await confine(failClosed: false), isA<Unconfined>());
    });

    test('asks the user to wait while the sandbox initializes', () async {
      whenAcquires(const SandboxInitializing());

      final decision = await confine();

      expect(
        decision,
        isA<ConfinementRefused>().having(
          (d) => d.reason,
          'reason',
          contains('still being initialized'),
        ),
      );
    });

    test('refuses while initializing even with fail-closed off', () async {
      whenAcquires(const SandboxInitializing());

      expect(await confine(failClosed: false), isA<ConfinementRefused>());
    });

    test('names the path consent was declined for', () async {
      whenAcquires(const SandboxConsentDeclined('/work/secret'));

      expect(
        (await confine() as ConfinementRefused).reason,
        contains('/work/secret'),
      );
    });

    test('reports the operation that failed to provision', () async {
      whenAcquires(
        const SandboxProvisioningFailed(operation: 'mkdir', reason: 'denied'),
      );

      expect(
        (await confine() as ConfinementRefused).reason,
        allOf(contains('mkdir'), contains('denied')),
      );
    });
  });
}
