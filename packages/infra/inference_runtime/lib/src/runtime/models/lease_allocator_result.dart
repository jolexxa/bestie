import 'package:inference/inference.dart';

/// One sequence held in the shared KV pool.
sealed class Lease {
  const Lease({required this.sequence});

  final Sequence sequence;
}

/// The primary agent's lease. It may grow into whatever the subagents have not
/// claimed, up to [fullLimit].
final class PrimaryLease extends Lease {
  const PrimaryLease({required super.sequence, required this.fullLimit});

  /// The most positions the backend lets one sequence hold.
  final int fullLimit;
}

/// A subagent's lease: a fixed share of the pool set aside for it alone.
final class SubagentLease extends Lease {
  const SubagentLease({required super.sequence, required this.claimSize});

  final int claimSize;
}

sealed class ReservePrimaryResult {
  const ReservePrimaryResult();
}

final class ReservePrimarySucceeded extends ReservePrimaryResult {
  const ReservePrimarySucceeded(this.lease);

  final PrimaryLease lease;
}

sealed class ReserveSubagentResult {
  const ReserveSubagentResult();
}

final class ReserveSubagentSucceeded extends ReserveSubagentResult {
  const ReserveSubagentSucceeded(this.lease);

  final SubagentLease lease;
}

final class ReserveLeaseFailed
    implements ReservePrimaryResult, ReserveSubagentResult {
  const ReserveLeaseFailed({required this.reason});

  final ReserveLeaseFailureReason reason;
}

enum ReserveLeaseFailureReason {
  primaryAlreadyReserved,
  invalidClaimSize,
  insufficientClaimSpace,
  noSequenceCapacity,
  schedulerFailure,
}

sealed class ReleaseLeaseResult {
  const ReleaseLeaseResult();
}

final class ReleaseLeaseSucceeded extends ReleaseLeaseResult {
  const ReleaseLeaseSucceeded();
}

final class ReleaseLeaseFailed extends ReleaseLeaseResult {
  const ReleaseLeaseFailed({required this.reason});

  final ReleaseLeaseFailureReason reason;
}

enum ReleaseLeaseFailureReason { unknownLease, schedulerFailure }
