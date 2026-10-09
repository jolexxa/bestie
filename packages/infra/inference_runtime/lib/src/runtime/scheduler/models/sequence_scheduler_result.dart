import 'package:inference/inference.dart';
import 'package:inference_runtime/src/runtime/models/lease_allocator_result.dart';

enum MaterializationStrategy {
  fullPrefill,
  prefixReuse,
  divergentReuse,
  checkpointRestore,
  rebuild,
}

final class SequenceMaterialization {
  const SequenceMaterialization({
    required this.tokens,
    required this.materializedTokenCount,
    required this.positionMax,
    required this.strategy,
    required this.reusedTokenCount,
  });

  final TokenizedString tokens;
  final int materializedTokenCount;
  final int positionMax;
  final MaterializationStrategy strategy;

  /// Leading tokens that were already resident before this materialization
  /// began, so they were not prefilled again.
  final int reusedTokenCount;

  bool get isComplete => materializedTokenCount == tokens.length;
}

final class SequenceUsage {
  const SequenceUsage({
    required this.lease,
    required this.tokenCount,
    required this.effectiveLimit,
    this.positionMin = 0,
  });

  final Lease lease;

  /// Context positions consumed by this sequence.
  final int tokenCount;

  final int effectiveLimit;

  /// Lowest physical position still resident for this sequence. A value above
  /// zero means the backend evicted the front of the sequence, so any cached
  /// prefix that started at position zero is no longer materialized.
  final int positionMin;
}

sealed class SequenceUsageResult {
  const SequenceUsageResult();
}

final class SequenceUsageSucceeded extends SequenceUsageResult {
  const SequenceUsageSucceeded(this.usage);

  final SequenceUsage usage;
}

final class SequenceUsageFailed extends SequenceUsageResult {
  const SequenceUsageFailed({required this.reason, this.backendFailure});

  final SequenceSchedulerFailureReason reason;
  final SequenceSchedulerBackendFailure? backendFailure;
}

sealed class SequenceSampleResult {
  const SequenceSampleResult();
}

final class SequenceSampleSucceeded extends SequenceSampleResult {
  const SequenceSampleSucceeded(this.result);

  final SampleSequenceResult result;
}

final class SequenceSampleDeferred extends SequenceSampleResult {
  const SequenceSampleDeferred({required this.reason});

  final SequenceSchedulerDeferralReason reason;
}

final class SequenceSampleFailed extends SequenceSampleResult {
  const SequenceSampleFailed({required this.reason, this.backendFailure});

  final SequenceSchedulerFailureReason reason;
  final SequenceSchedulerBackendFailure? backendFailure;
}

final class SequenceSampleRequest {
  const SequenceSampleRequest({required this.lease});

  final Lease lease;
}

sealed class SequenceMaterializeResult {
  const SequenceMaterializeResult();
}

final class SequenceMaterializeSucceeded extends SequenceMaterializeResult {
  const SequenceMaterializeSucceeded({
    required this.sequenceId,
    required this.positionMin,
    required this.positionMax,
    required this.materialization,
  });

  final SequenceId sequenceId;
  final int positionMin;
  final int positionMax;
  final SequenceMaterialization materialization;
}

final class SequenceMaterializeAdvanced extends SequenceMaterializeResult {
  const SequenceMaterializeAdvanced({
    required this.sequenceId,
    required this.positionMin,
    required this.positionMax,
    required this.materialization,
  });

  final SequenceId sequenceId;
  final int positionMin;
  final int positionMax;
  final SequenceMaterialization materialization;
}

final class SequenceMaterializeDeferred extends SequenceMaterializeResult {
  const SequenceMaterializeDeferred({required this.reason});

  final SequenceSchedulerDeferralReason reason;
}

final class SequenceMaterializeFailed extends SequenceMaterializeResult {
  const SequenceMaterializeFailed({required this.reason, this.backendFailure});

  final SequenceSchedulerFailureReason reason;
  final SequenceSchedulerBackendFailure? backendFailure;
}

final class SequenceMaterializeRequest {
  const SequenceMaterializeRequest({required this.lease, required this.tokens});

  final Lease lease;
  final TokenizedString tokens;
}

/// What one scheduler step did for each lease it was asked about.
final class SequenceStepResults {
  const SequenceStepResults({
    required this.samples,
    required this.materializes,
  });

  final Map<Lease, SequenceSampleResult> samples;
  final Map<Lease, SequenceMaterializeResult> materializes;
}

sealed class SequenceSetSamplingResult {
  const SequenceSetSamplingResult();
}

final class SequenceSetSamplingSucceeded extends SequenceSetSamplingResult {
  const SequenceSetSamplingSucceeded();
}

final class SequenceSetSamplingFailed extends SequenceSetSamplingResult {
  const SequenceSetSamplingFailed({required this.reason, this.backendFailure});

  final SequenceSchedulerFailureReason reason;
  final SequenceSchedulerBackendFailure? backendFailure;
}

sealed class SequenceSchedulerBackendFailure {
  const SequenceSchedulerBackendFailure();
}

final class SequenceStepBackendFailed extends SequenceSchedulerBackendFailure {
  const SequenceStepBackendFailed(this.result);

  final StepBatchFailed result;
}

final class SequenceSnapshotBackendFailed
    extends SequenceSchedulerBackendFailure {
  const SequenceSnapshotBackendFailed(this.result);

  final KvSnapshotFailed result;
}

final class SequenceClearBackendFailed extends SequenceSchedulerBackendFailure {
  const SequenceClearBackendFailed(this.result);

  final ClearSequenceFailed result;
}

final class SequenceRemoveRangeBackendFailed
    extends SequenceSchedulerBackendFailure {
  const SequenceRemoveRangeBackendFailed(this.result);

  final RemoveRangeFailed result;
}

final class SequenceRebuildSamplerBackendFailed
    extends SequenceSchedulerBackendFailure {
  const SequenceRebuildSamplerBackendFailed(this.result);

  final RebuildSamplerFailed result;
}

final class SequenceSetSamplingBackendFailed
    extends SequenceSchedulerBackendFailure {
  const SequenceSetSamplingBackendFailed(this.result);

  final SetSamplingFailed result;
}

enum SequenceSchedulerDeferralReason {
  effectiveLimitReached,
  logitsUnavailable,
  requestWouldExceedEffectiveLimit,
  batchCapacityExhausted,
  backendBackpressure,
}

enum SequenceSchedulerFailureReason {
  unknownLease,
  missingBatchResult,
  missingLogitsTicket,
  backendFailure,
  cancelled,
}
