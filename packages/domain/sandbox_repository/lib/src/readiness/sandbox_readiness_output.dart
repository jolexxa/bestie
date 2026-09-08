import 'package:intentions/intentions.dart';

/// Outputs of the readiness state machine.
@model
sealed class SandboxReadinessOutput {
  const SandboxReadinessOutput();
}

/// The machine moved; its readiness may read differently now.
@model
final class ReadinessChanged extends SandboxReadinessOutput {
  const ReadinessChanged();
}
