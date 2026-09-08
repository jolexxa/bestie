import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/src/host_preparation.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_data.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_host.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_input.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_output.dart';
import 'package:sandbox_repository/src/sandbox_readiness.dart';
import 'package:sandbox_repository/src/sandbox_repository.dart';

// ── Base state ──────────────────────────────────────────────

/// Where the session's sandbox stands since startup.
@model
sealed class SandboxReadinessState extends StateLogic<SandboxReadinessState> {
  SandboxReadinessData get data => get<SandboxReadinessData>();

  SandboxReadinessHost get host => data.host;

  /// The policy the session was warmed for; only read by states [WarmUp]
  /// leads to.
  SandboxSpec get spec => data.spec!;

  /// How this reads to the rest of the app. A host with no one-time work is
  /// ready throughout: nothing it does on the way needs the user.
  SandboxReadiness get readiness =>
      data.preparesHost ? progress : const SandboxReady();

  /// Where startup stands for a host that prepares.
  SandboxReadiness get progress;

  /// Whether a confinement may be acquired right now.
  bool get acceptsAcquire => false;

  /// Why a program is refused while [acceptsAcquire] is false.
  String get refusal =>
      'The sandbox is still being initialized; the status bar shows its '
      'progress. This can take a few minutes on Windows the first time. '
      'Try again once it reports ready.';

  Transition warm(WarmUp input) {
    data.spec = input.spec;
    return to<SandboxCheckingHostState>();
  }

  Transition fail(String reason) {
    data.failure = reason;
    return to<SandboxFailedState>();
  }

  static HostWorkFailed unexpected(Object error) => HostWorkFailed('$error');
}

// ── Compound states ─────────────────────────────────────────

/// Nothing is in flight: the session can be warmed up or reset.
@model
sealed class SandboxRestingState extends SandboxReadinessState {
  SandboxRestingState() {
    on<WarmUp>(warm);
    on<Reset>((_) => to<SandboxResettingState>());
  }
}

/// The gate is showing: the user can ask for initialization. Read as it is
/// on every host, since the gate needs the user.
@model
sealed class SandboxGatedState extends SandboxRestingState {
  SandboxGatedState() {
    on<Initialize>((_) => to<SandboxPreparingHostState>());
  }

  @override
  SandboxReadiness get readiness => progress;
}

/// The host is busy with a step of its own; nothing may be acquired.
@model
sealed class SandboxHostWorkingState extends SandboxReadinessState {
  SandboxHostWorkingState() {
    on<HostWorkFailed>((input) => fail(input.reason));
  }

  @override
  SandboxReadiness get progress => const SandboxPreparingHost();
}

// ── Concrete states ─────────────────────────────────────────

/// Nothing has been asked yet. A host with grants to check refuses until it
/// is warmed up; any other is ready as it stands.
@model
final class SandboxDormantState extends SandboxRestingState {
  SandboxDormantState() {
    onEnter(() => output(const ReadinessChanged()));
  }

  @override
  SandboxReadiness get progress => const SandboxPreparingHost();

  @override
  bool get acceptsAcquire => !data.preparesHost;
}

/// Asking the host whether its one-time grants are in place.
@model
final class SandboxCheckingHostState extends SandboxHostWorkingState {
  SandboxCheckingHostState() {
    onEnter(() {
      output(const ReadinessChanged());
      async(host.hostPrepared(spec))
          .input((prepared) => HostChecked(prepared: prepared))
          .errorInput(SandboxReadinessState.unexpected);
    });

    on<HostChecked>(
      (input) => input.prepared
          ? to<SandboxProvisioningState>()
          : to<SandboxAwaitingState>(),
    );
  }

  @override
  bool get acceptsAcquire => !data.preparesHost;
}

/// The host needs its one-time grants and the user has not asked for them.
@model
final class SandboxAwaitingState extends SandboxGatedState {
  SandboxAwaitingState() {
    onEnter(() => output(const ReadinessChanged()));
  }

  @override
  SandboxReadiness get progress => const SandboxAwaitingInitialization();

  @override
  String get refusal =>
      'The sandbox has not been initialized yet. Ask the user to press Enter '
      'in the chat area to initialize it; on Windows this asks for '
      'administrator approval once and can take a few minutes.';
}

/// The host's one-time grants are being put in place.
@model
final class SandboxPreparingHostState extends SandboxHostWorkingState {
  SandboxPreparingHostState() {
    onEnter(() {
      output(const ReadinessChanged());
      async(host.prepareHost(spec))
          .input(HostPreparationSettled.new)
          .errorInput(SandboxReadinessState.unexpected);
    });

    on<HostPreparationSettled>(
      (input) => switch (input.preparation) {
        HostPrepared() => to<SandboxProvisioningState>(),
        HostPreparationDeclined() => fail(declinedReason),
        HostPreparationFailed(:final reason) => fail(reason),
      },
    );
  }

  static const declinedReason = 'administrator approval was declined';
}

/// The session's confinement is being provisioned; acquiring joins it.
@model
final class SandboxProvisioningState extends SandboxReadinessState {
  SandboxProvisioningState() {
    onEnter(() {
      output(const ReadinessChanged());
      async(host.provisionSession(spec))
          .input((_) => const SessionProvisioned())
          .errorInput((_) => const SessionProvisioned());
    });

    on<SessionProvisioned>((_) => to<SandboxReadyState>());
  }

  @override
  SandboxReadiness get progress => const SandboxProvisioning();

  @override
  bool get acceptsAcquire => true;
}

/// Startup has settled; the host reclaims what it no longer needs behind it.
@model
final class SandboxReadyState extends SandboxRestingState {
  SandboxReadyState() {
    onEnter(() {
      output(const ReadinessChanged());
      async(host.reclaimHost());
    });
  }

  @override
  SandboxReadiness get progress => const SandboxReady();

  @override
  bool get acceptsAcquire => true;
}

/// Initialization failed; the user may try again or reset.
@model
final class SandboxFailedState extends SandboxGatedState {
  SandboxFailedState() {
    onEnter(() => output(const ReadinessChanged()));
  }

  @override
  SandboxReadiness get progress => SandboxInitializationFailed(data.failure);

  @override
  String get refusal =>
      'Sandbox initialization failed: ${data.failure}. Ask the user to press '
      'Enter in the chat area to try again.';
}

/// Every grant is being reversed; the session starts over once it is done.
@model
final class SandboxResettingState extends SandboxHostWorkingState {
  SandboxResettingState() {
    onEnter(() {
      output(const ReadinessChanged());
      async(host.resetSession())
          .input((_) => const HostReset())
          .errorInput(SandboxReadinessState.unexpected);
    });

    on<HostReset>(
      (_) => data.spec == null
          ? to<SandboxDormantState>()
          : to<SandboxCheckingHostState>(),
    );
  }
}

// ── Logic block ─────────────────────────────────────────────

/// The state machine behind a [SandboxRepository]'s readiness.
@PartOf(SandboxRepository)
final class SandboxReadinessLogic extends LogicBlock<SandboxReadinessState> {
  SandboxReadinessLogic({
    required SandboxReadinessHost host,
    required bool preparesHost,
  }) {
    set(SandboxReadinessData(host: host, preparesHost: preparesHost));

    set(SandboxDormantState());
    set(SandboxCheckingHostState());
    set(SandboxAwaitingState());
    set(SandboxPreparingHostState());
    set(SandboxProvisioningState());
    set(SandboxReadyState());
    set(SandboxFailedState());
    set(SandboxResettingState());
  }

  @override
  Transition getInitialState() => to<SandboxDormantState>();
}
