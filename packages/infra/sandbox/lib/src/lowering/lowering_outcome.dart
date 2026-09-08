import 'package:sandbox/src/lowering/effective_policy.dart';
import 'package:sandbox/src/lowering/lowered_policy.dart';

/// The result of lowering a spec. Backends that could fail may add their own ///// failure arms.
sealed class LoweringOutcome {
  const LoweringOutcome();
}

/// Lowering produced a policy and its report.
final class LoweringSucceeded extends LoweringOutcome {
  /// Wraps the [policy] to encode and the [report] to surface.
  const LoweringSucceeded(this.policy, this.report);

  /// The lowered policy, ready for the encoder.
  final LoweredPolicy policy;

  /// The report that feeds `SandboxEnforcement`.
  final EffectivePolicy report;
}
