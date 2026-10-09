import 'dart:math' as math;

import 'package:inference/inference.dart';
import 'package:inference_runtime/src/runtime/models/lease_allocator_result.dart';

abstract interface class Allocator {
  int get contextSize;

  int get maxSequences;

  int get nSwa;

  bool get isRecurrent;

  int get activeSubagentClaims;

  ReservePrimaryResult reservePrimary({required EngineSampling sampling});

  ReserveSubagentResult reserveSubagent({
    required int contextSize,
    required EngineSampling sampling,
  });

  int effectiveLimitFor(Lease lease);

  bool owns(Lease lease);

  ReleaseLeaseResult release(Lease lease);
}

final class LeaseAllocator implements Allocator {
  LeaseAllocator({required Context context}) : _context = context;

  final Context _context;
  PrimaryLease? _primaryLease;
  final Map<SequenceId, SubagentLease> _subagentLeases = {};

  @override
  int get contextSize => _context.envelope.contextSize;

  @override
  int get maxSequences => _context.envelope.maxSequences;

  @override
  int get nSwa => _context.envelope.nSwa;

  @override
  bool get isRecurrent => _context.envelope.isRecurrent;

  @override
  int get activeSubagentClaims =>
      _subagentLeases.values.fold(0, (total, lease) => total + lease.claimSize);

  int get _activeSequenceCount =>
      (_primaryLease == null ? 0 : 1) + _subagentLeases.length;

  @override
  ReservePrimaryResult reservePrimary({required EngineSampling sampling}) {
    if (_primaryLease != null) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.primaryAlreadyReserved,
      );
    }
    if (_activeSequenceCount >= maxSequences) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.noSequenceCapacity,
      );
    }

    final result = _context.sequences.acquire(
      SequenceRequest(sampling: sampling),
    );
    return switch (result) {
      RequestSequenceSucceeded(:final sequence) => _reservePrimary(sequence),
      RequestSequenceFailed() => const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.schedulerFailure,
      ),
    };
  }

  ReservePrimaryResult _reservePrimary(Sequence sequence) {
    final fullLimit = math.min(contextSize, _context.envelope.perSequenceLimit);
    final lease = PrimaryLease(sequence: sequence, fullLimit: fullLimit);
    _primaryLease = lease;
    return ReservePrimarySucceeded(lease);
  }

  /// Admits a subagent only when its claim fits beside the other claims and
  /// the primary's resident cells. An idle primary keeps whatever it grew
  /// into, and those cells cannot be walked back, so a claim that overlaps them
  /// would collide with the primary in the shared pool.
  @override
  ReserveSubagentResult reserveSubagent({
    required int contextSize,
    required EngineSampling sampling,
  }) {
    if (contextSize <= 0) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.invalidClaimSize,
      );
    }
    if (_activeSequenceCount >= maxSequences) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.noSequenceCapacity,
      );
    }
    final resident = _primaryResidentTokens();
    if (resident == null) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.schedulerFailure,
      );
    }
    if (contextSize > this.contextSize - activeSubagentClaims - resident) {
      return const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.insufficientClaimSpace,
      );
    }

    final result = _context.sequences.acquire(
      SequenceRequest(sampling: sampling),
    );
    return switch (result) {
      RequestSequenceSucceeded(:final sequence) => _reserveSubagent(
        sequence,
        claimSize: contextSize,
      ),
      RequestSequenceFailed() => const ReserveLeaseFailed(
        reason: ReserveLeaseFailureReason.schedulerFailure,
      ),
    };
  }

  /// Positions the primary's sequence holds, or null when the backend could
  /// not report them.
  int? _primaryResidentTokens() {
    final primary = _primaryLease;
    if (primary == null) return 0;
    return switch (_context.sequences.kvSnapshot()) {
      KvSnapshotSucceeded(:final snapshot) =>
        snapshot.sequences
                .where((state) => state.sequenceId == primary.sequence.id)
                .firstOrNull
                ?.usedPositions ??
            0,
      KvSnapshotFailed() => null,
    };
  }

  ReserveSubagentResult _reserveSubagent(
    Sequence sequence, {
    required int claimSize,
  }) {
    final lease = SubagentLease(sequence: sequence, claimSize: claimSize);
    _subagentLeases[sequence.id] = lease;
    return ReserveSubagentSucceeded(lease);
  }

  @override
  int effectiveLimitFor(Lease lease) {
    return switch (lease) {
      PrimaryLease(:final fullLimit) => math.min(
        fullLimit,
        contextSize - activeSubagentClaims,
      ),
      SubagentLease(:final claimSize) => claimSize,
    };
  }

  @override
  bool owns(Lease lease) {
    return switch (lease) {
      PrimaryLease() => identical(_primaryLease, lease),
      SubagentLease() => identical(_subagentLeases[lease.sequence.id], lease),
    };
  }

  @override
  ReleaseLeaseResult release(Lease lease) {
    if (!owns(lease)) {
      return const ReleaseLeaseFailed(
        reason: ReleaseLeaseFailureReason.unknownLease,
      );
    }

    final result = _context.sequences.release(lease.sequence.id);
    return switch (result) {
      ReleaseSequenceSucceeded() => _release(lease),
      ReleaseSequenceFailed() => const ReleaseLeaseFailed(
        reason: ReleaseLeaseFailureReason.schedulerFailure,
      ),
    };
  }

  ReleaseLeaseResult _release(Lease lease) {
    switch (lease) {
      case PrimaryLease():
        _primaryLease = null;
      case SubagentLease():
        _subagentLeases.remove(lease.sequence.id);
    }
    return const ReleaseLeaseSucceeded();
  }
}
