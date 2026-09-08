import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';

/// What was decided about confinement for this session: planned at startup,
/// held by the sandbox repository for every feature that runs the agent's
/// programs, and widened as the user grants more.
@model
sealed class SandboxPlan {
  const SandboxPlan();
}

/// The sandbox is turned off: everything runs unconfined.
@model
final class SandboxOff extends SandboxPlan {
  const SandboxOff();
}

/// Programs run inside a confinement provisioned for [spec]. When it cannot
/// be provisioned, [failClosed] says whether to refuse the program or run it
/// unconfined.
@model
final class SandboxPlanned extends SandboxPlan {
  const SandboxPlanned({required this.spec, required this.failClosed});

  final SandboxSpec spec;
  final bool failClosed;
}

/// What confinement one program should run under, decided from a
/// [SandboxPlan] and what the host could provision right now.
@model
sealed class ConfinementDecision {
  const ConfinementDecision();
}

/// Run unconfined: the sandbox is off, or a soft failure the plan chose to
/// run through.
@model
final class Unconfined extends ConfinementDecision {
  const Unconfined();
}

/// Run inside [sandbox].
@model
final class Confined extends ConfinementDecision {
  const Confined(this.sandbox);

  final Sandbox sandbox;
}

/// Refuse to run: confinement was required but could not be acquired.
@model
final class ConfinementRefused extends ConfinementDecision {
  const ConfinementRefused(this.reason);

  final String reason;
}
