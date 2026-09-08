import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_host.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_input.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_logic.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_output.dart';
import 'package:test/test.dart';

class _MockHost extends Mock implements SandboxReadinessHost {}

const _spec = SandboxSpec(workspaceRoot: '/ws');

void main() {
  setUpAll(() => registerFallbackValue(_spec));

  late _MockHost host;

  setUp(() {
    host = _MockHost();
    when(() => host.hostPrepared(any())).thenAnswer((_) async => true);
    when(
      () => host.prepareHost(any()),
    ).thenAnswer((_) async => const HostPrepared());
    when(() => host.provisionSession(any())).thenAnswer((_) async {});
    when(() => host.reclaimHost()).thenAnswer((_) async {});
    when(() => host.resetSession()).thenAnswer((_) async {});
  });

  SandboxReadinessLogic logic({bool preparesHost = false}) =>
      SandboxReadinessLogic(host: host, preparesHost: preparesHost)..start();

  Future<SandboxReadinessLogic> awaiting() async {
    when(() => host.hostPrepared(any())).thenAnswer((_) async => false);
    final machine = logic(preparesHost: true)..input(const WarmUp(_spec));
    await machine.task;
    expect(machine.value, isA<SandboxAwaitingState>());
    return machine;
  }

  group('dormant', () {
    test('a host with nothing to prepare is ready as it stands', () {
      final machine = logic();

      expect(machine.value, isA<SandboxDormantState>());
      expect(machine.value.readiness, const SandboxReady());
      expect(machine.value.acceptsAcquire, isTrue);
    });

    test('a host with grants to check refuses until warmed up', () {
      final machine = logic(preparesHost: true);

      expect(machine.value.readiness, const SandboxPreparingHost());
      expect(machine.value.acceptsAcquire, isFalse);
      expect(machine.value.refusal, contains('still being initialized'));
    });

    test('ignores initialize', () async {
      final machine = logic(preparesHost: true)..input(const Initialize());
      await machine.task;

      expect(machine.value, isA<SandboxDormantState>());
      verifyNever(() => host.prepareHost(any()));
    });

    test('a reset before warming up leaves it dormant', () async {
      final machine = logic()..input(const Reset());
      expect(machine.value, isA<SandboxResettingState>());
      await machine.task;

      expect(machine.value, isA<SandboxDormantState>());
      verify(() => host.resetSession()).called(1);
    });
  });

  group('warming up', () {
    test('checks the host, refusing meanwhile', () {
      final machine = logic(preparesHost: true)..input(const WarmUp(_spec));

      expect(machine.value, isA<SandboxCheckingHostState>());
      expect(machine.value.readiness, const SandboxPreparingHost());
      expect(machine.value.acceptsAcquire, isFalse);
      verify(() => host.hostPrepared(_spec)).called(1);
    });

    test('a host with nothing to prepare reads ready throughout', () async {
      final provisioned = Completer<void>();
      when(
        () => host.provisionSession(any()),
      ).thenAnswer((_) => provisioned.future);
      final machine = logic()..input(const WarmUp(_spec));

      expect(machine.value, isA<SandboxCheckingHostState>());
      expect(machine.value.readiness, const SandboxReady());
      expect(machine.value.acceptsAcquire, isTrue);
      await pumpEventQueue();
      expect(machine.value, isA<SandboxProvisioningState>());
      expect(machine.value.readiness, const SandboxReady());

      provisioned.complete();
      await machine.task;
      expect(machine.value, isA<SandboxReadyState>());
    });

    test('a prepared host provisions, then is ready and reclaims', () async {
      final changes = <ReadinessChanged>[];
      final machine = logic(preparesHost: true);
      final binding = machine.bind()..onOutput<ReadinessChanged>(changes.add);
      final provisioned = Completer<void>();
      when(
        () => host.provisionSession(any()),
      ).thenAnswer((_) => provisioned.future);

      machine.input(const WarmUp(_spec));
      await pumpEventQueue();
      expect(machine.value, isA<SandboxProvisioningState>());
      expect(machine.value.readiness, const SandboxProvisioning());
      expect(machine.value.acceptsAcquire, isTrue);
      verifyNever(() => host.reclaimHost());

      provisioned.complete();
      await machine.task;
      expect(machine.value, isA<SandboxReadyState>());
      expect(machine.value.readiness, const SandboxReady());
      verify(() => host.provisionSession(_spec)).called(1);
      verify(() => host.reclaimHost()).called(1);
      expect(changes, hasLength(3));
      binding.dispose();
    });

    test('an unprepared host waits at the gate', () async {
      final machine = await awaiting();

      expect(machine.value.readiness, const SandboxAwaitingInitialization());
      expect(machine.value.acceptsAcquire, isFalse);
      expect(
        machine.value.refusal,
        allOf(contains('press Enter'), contains('administrator')),
      );
      verifyNever(() => host.prepareHost(any()));
      verifyNever(() => host.provisionSession(any()));
    });

    test('a host that throws while checking fails with the error', () async {
      when(
        () => host.hostPrepared(any()),
      ).thenAnswer((_) async => throw StateError('acl'));

      final machine = logic()..input(const WarmUp(_spec));
      await machine.task;

      expect(machine.value, isA<SandboxFailedState>());
      expect(
        machine.value.readiness,
        isA<SandboxInitializationFailed>().having(
          (r) => r.reason,
          'reason',
          contains('acl'),
        ),
      );
    });

    test('provisioning that throws still ends ready', () async {
      when(
        () => host.provisionSession(any()),
      ).thenAnswer((_) async => throw StateError('boom'));

      final machine = logic()..input(const WarmUp(_spec));
      await machine.task;

      expect(machine.value, isA<SandboxReadyState>());
    });
  });

  group('initializing from the gate', () {
    test('prepares the host, refusing meanwhile, then provisions', () async {
      final prepared = Completer<HostPreparation>();
      when(() => host.prepareHost(any())).thenAnswer((_) => prepared.future);
      final machine = await awaiting()
        ..input(const Initialize());

      expect(machine.value, isA<SandboxPreparingHostState>());
      expect(machine.value.readiness, const SandboxPreparingHost());
      expect(machine.value.acceptsAcquire, isFalse);

      prepared.complete(const HostPrepared());
      await machine.task;
      expect(machine.value, isA<SandboxReadyState>());
      verify(() => host.prepareHost(_spec)).called(1);
      verify(() => host.provisionSession(_spec)).called(1);
    });

    test('a second initialize while preparing is ignored', () async {
      final prepared = Completer<HostPreparation>();
      when(() => host.prepareHost(any())).thenAnswer((_) => prepared.future);
      final machine = await awaiting()
        ..input(const Initialize())
        ..input(const Initialize());

      prepared.complete(const HostPrepared());
      await machine.task;

      verify(() => host.prepareHost(any())).called(1);
    });

    test('a declined preparation fails, naming the decline', () async {
      when(
        () => host.prepareHost(any()),
      ).thenAnswer((_) async => const HostPreparationDeclined());
      final machine = await awaiting()
        ..input(const Initialize());
      await machine.task;

      expect(machine.value, isA<SandboxFailedState>());
      expect(
        machine.value.readiness,
        const SandboxInitializationFailed(
          'administrator approval was declined',
        ),
      );
      expect(
        machine.value.refusal,
        allOf(contains('declined'), contains('try again')),
      );
      verifyNever(() => host.provisionSession(any()));
    });

    test('a failed preparation carries its reason', () async {
      when(
        () => host.prepareHost(any()),
      ).thenAnswer((_) async => const HostPreparationFailed('no acl'));
      final machine = await awaiting()
        ..input(const Initialize());
      await machine.task;

      expect(
        machine.value.readiness,
        const SandboxInitializationFailed('no acl'),
      );
    });

    test('a preparation that throws fails with the error', () async {
      when(
        () => host.prepareHost(any()),
      ).thenAnswer((_) async => throw StateError('uac'));
      final machine = await awaiting()
        ..input(const Initialize());
      await machine.task;

      expect(
        machine.value.readiness,
        isA<SandboxInitializationFailed>().having(
          (r) => r.reason,
          'reason',
          contains('uac'),
        ),
      );
    });

    test('initialize after a failure tries again', () async {
      when(
        () => host.prepareHost(any()),
      ).thenAnswer((_) async => const HostPreparationFailed('no acl'));
      final machine = await awaiting()
        ..input(const Initialize());
      await machine.task;
      when(
        () => host.prepareHost(any()),
      ).thenAnswer((_) async => const HostPrepared());

      machine.input(const Initialize());
      await machine.task;

      expect(machine.value, isA<SandboxReadyState>());
    });

    test('initialize once ready is ignored', () async {
      final machine = logic()..input(const WarmUp(_spec));
      await machine.task;

      machine.input(const Initialize());
      await machine.task;

      expect(machine.value, isA<SandboxReadyState>());
      verifyNever(() => host.prepareHost(any()));
    });
  });

  group('resetting', () {
    test('from ready resets the host and checks it again', () async {
      when(() => host.hostPrepared(any())).thenAnswer((_) async => false);
      final machine = logic(preparesHost: true)..input(const WarmUp(_spec));
      await machine.task;
      machine.input(const Reset());
      expect(machine.value, isA<SandboxResettingState>());
      expect(machine.value.readiness, const SandboxPreparingHost());
      expect(machine.value.acceptsAcquire, isFalse);

      await machine.task;

      expect(machine.value, isA<SandboxAwaitingState>());
      verify(() => host.resetSession()).called(1);
      verify(() => host.hostPrepared(_spec)).called(2);
    });

    test('from the gate resets the host too', () async {
      final machine = await awaiting()
        ..input(const Reset());
      await machine.task;

      verify(() => host.resetSession()).called(1);
    });

    test('while preparing is ignored', () async {
      final prepared = Completer<HostPreparation>();
      when(() => host.prepareHost(any())).thenAnswer((_) => prepared.future);
      final machine = await awaiting()
        ..input(const Initialize())
        ..input(const Reset());

      expect(machine.value, isA<SandboxPreparingHostState>());
      prepared.complete(const HostPrepared());
      await machine.task;
      verifyNever(() => host.resetSession());
    });

    test('a reset that throws fails with the error', () async {
      when(
        () => host.resetSession(),
      ).thenAnswer((_) async => throw StateError('locked'));
      final machine = logic()..input(const WarmUp(_spec));
      await machine.task;

      machine.input(const Reset());
      await machine.task;

      expect(
        machine.value.readiness,
        isA<SandboxInitializationFailed>().having(
          (r) => r.reason,
          'reason',
          contains('locked'),
        ),
      );
    });
  });

  test('warming up again from rest takes the new spec', () async {
    const other = SandboxSpec(workspaceRoot: '/other');
    final machine = logic()..input(const WarmUp(_spec));
    await machine.task;

    machine.input(const WarmUp(other));
    await machine.task;

    verify(() => host.hostPrepared(other)).called(1);
    verify(() => host.provisionSession(other)).called(1);
  });
}
