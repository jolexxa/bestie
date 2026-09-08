import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/subjects.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/src/host_preparation.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_host.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_input.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_logic.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_output.dart';
import 'package:sandbox_repository/src/sandbox_plan.dart';
import 'package:sandbox_repository/src/sandbox_readiness.dart';

/// Owns the process sandbox across a session: it provisions a confinement
/// once per policy and hands the same one to every command, so the
/// provisioning cost — on Windows a synchronous ACL tree-walk over the
/// workspace — is paid once rather than per launch.
@repository
class SandboxRepository {
  /// Confines through [guard], the host's mechanism. A host that
  /// [preparesHost] has one-time grants to check first and refuses to confine
  /// until it has been warmed up.
  SandboxRepository(SandboxBackend guard, {bool preparesHost = false})
    : _guard = guard {
    _logic = SandboxReadinessLogic(
      host: _ReadinessHost(this),
      preparesHost: preparesHost,
    );
    _binding = _logic.bind()
      ..onOutput<ReadinessChanged>((_) => _publish(_logic.value.readiness));
    _logic.start();
    _readiness = BehaviorSubject.seeded(_logic.value.readiness);
  }

  final SandboxBackend _guard;
  late final SandboxReadinessLogic _logic;
  late final LogicBlockBinding<SandboxReadinessState> _binding;
  late final BehaviorSubject<SandboxReadiness> _readiness;

  _Entry? _entry;
  SandboxPlan _plan = const SandboxOff();

  /// Where startup stands right now.
  SandboxReadiness get readiness => _readiness.value;

  /// [readiness] as it moves, opening with the current value.
  Stream<SandboxReadiness> get readinessStream => _readiness.stream;

  /// What was decided about confinement for this session: off until a plan
  /// is adopted, then the policy every program runs under, as last widened.
  SandboxPlan get plan => _plan;

  /// Makes [plan] the session's plan. A planned session starts provisioning
  /// its confinement in the background, or stops at
  /// [SandboxAwaitingInitialization] when the host needs its one-time grants
  /// first.
  void adopt(SandboxPlan plan) {
    _plan = plan;
    if (plan case SandboxPlanned(:final spec)) _logic.input(WarmUp(spec));
  }

  /// Widens a planned session to [spec]: the next program runs under it.
  /// Answers with what was provisioned for it once the host has settled, or
  /// [SandboxInitializing] when the host still needs the user.
  Future<SandboxAcquisition> replan(SandboxSpec spec) => switch (_plan) {
    SandboxOff() => Future.value(
      const SandboxUnavailable('the sandbox is off'),
    ),
    SandboxPlanned(:final failClosed) => _replanWith(
      SandboxPlanned(spec: spec, failClosed: failClosed),
    ),
  };

  Future<SandboxAcquisition> _replanWith(SandboxPlanned plan) async {
    _plan = plan;
    _logic.input(WarmUp(plan.spec));
    await _logic.task;
    return acquire(plan.spec);
  }

  /// Puts the host's one-time grants in place, then provisions. Ignored
  /// unless the gate is showing.
  Future<void> initialize() {
    _logic.input(const Initialize());
    return _logic.task;
  }

  /// Reverses every grant, forgets every record, and warms up again. Ignored
  /// while startup work is in flight.
  Future<void> reset() {
    _logic.input(const Reset());
    return _logic.task;
  }

  /// The confinement for [spec], provisioned once and reused while the policy
  /// holds. Refuses with [SandboxInitializing] until the session has started.
  Future<SandboxAcquisition> acquire(SandboxSpec spec) {
    if (!_logic.value.acceptsAcquire) {
      return Future.value(const SandboxInitializing());
    }
    final live = _entry;
    if (live != null && live.spec == spec) return live.acquisition;

    final entry = _Entry(spec, _replace(live, spec));
    _entry = entry;
    unawaited(_forgetIfFailed(entry));
    return entry.acquisition;
  }

  /// Decides how a program should run under [plan]: confined by the sandbox
  /// provisioned for it, unconfined when the plan allows, or refused.
  Future<ConfinementDecision> confine() => switch (_plan) {
    SandboxOff() => Future.value(const Unconfined()),
    SandboxPlanned(:final spec, :final failClosed) => _confineWith(
      spec,
      failClosed: failClosed,
    ),
  };

  Future<ConfinementDecision> _confineWith(
    SandboxSpec spec, {
    required bool failClosed,
  }) async => switch (await acquire(spec)) {
    SandboxAcquired(:final sandbox) => Confined(sandbox),
    // Refused regardless of fail-closed: the sandbox is about to be ready.
    SandboxInitializing() => ConfinementRefused(_logic.value.refusal),
    SandboxUnavailable(:final reason) => _failed(reason, failClosed),
    SandboxConsentDeclined(:final path) => _failed(
      'consent declined for $path',
      failClosed,
    ),
    SandboxProvisioningFailed(:final operation, :final reason) => _failed(
      '$operation: $reason',
      failClosed,
    ),
  };

  /// What a sandbox that could not be had means for the program: refused
  /// when the plan fails closed, else let through unconfined.
  static ConfinementDecision _failed(String reason, bool failClosed) =>
      failClosed ? ConfinementRefused(reason) : const Unconfined();

  /// Releases the live confinement, if any, then the backend's own resources.
  /// Idempotent.
  Future<void> dispose() async {
    _binding.dispose();
    _logic.dispose();
    final entry = _entry;
    _entry = null;
    if (entry != null) await _release(entry);
    await _guard.dispose();
    await _readiness.close();
  }

  /// Whether the host's one-time grants are already in place for [spec].
  @protected
  Future<bool> hostPrepared(SandboxSpec spec) async => true;

  /// Puts the host's one-time grants in place for [spec].
  @protected
  Future<HostPreparation> prepareHost(SandboxSpec spec) async =>
      const HostPrepared();

  /// Reclaims what the host no longer needs, once the session's confinement
  /// is provisioned.
  @protected
  Future<void> reclaimHost() async {}

  /// Reverses every grant the host holds and forgets every record of them.
  @protected
  Future<void> resetHost() async {}

  /// Provisions a fresh confinement for [spec]. The extension point a
  /// platform-specialized repository overrides to drive its own grant
  /// lifecycle; the default simply asks the guard.
  @protected
  Future<SandboxAcquisition> provision(SandboxSpec spec) =>
      _guard.acquire(spec);

  Future<void> _resetSession() async {
    final live = _entry;
    _entry = null;
    if (live != null) await _release(live);
    await resetHost();
  }

  Future<SandboxAcquisition> _replace(_Entry? live, SandboxSpec spec) async {
    if (live != null) await _release(live);
    return provision(spec);
  }

  Future<void> _release(_Entry entry) async {
    if (await entry.acquisition case SandboxAcquired(:final sandbox)) {
      await _guard.release(sandbox);
    }
  }

  Future<void> _forgetIfFailed(_Entry entry) async {
    if (await entry.acquisition is! SandboxAcquired &&
        identical(_entry, entry)) {
      _entry = null;
    }
  }

  void _publish(SandboxReadiness readiness) {
    if (_readiness.isClosed || _readiness.value == readiness) return;
    _readiness.add(readiness);
  }
}

/// The repository as the readiness machine sees it.
class _ReadinessHost implements SandboxReadinessHost {
  _ReadinessHost(this._repository);

  final SandboxRepository _repository;

  @override
  Future<bool> hostPrepared(SandboxSpec spec) => _repository.hostPrepared(spec);

  @override
  Future<HostPreparation> prepareHost(SandboxSpec spec) =>
      _repository.prepareHost(spec);

  @override
  Future<void> provisionSession(SandboxSpec spec) => _repository.acquire(spec);

  @override
  Future<void> reclaimHost() => _repository.reclaimHost();

  @override
  Future<void> resetSession() => _repository._resetSession();
}

/// One provisioned (or provisioning) confinement, keyed by the policy that
/// asked for it, so a repeat request reuses it and a changed one evicts it.
class _Entry {
  _Entry(this.spec, this.acquisition);

  final SandboxSpec spec;
  final Future<SandboxAcquisition> acquisition;
}
