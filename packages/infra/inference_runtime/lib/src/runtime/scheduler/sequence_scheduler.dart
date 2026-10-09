import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_runtime/src/runtime/lease_allocator.dart';
import 'package:inference_runtime/src/runtime/models/lease_allocator_result.dart';
import 'package:inference_runtime/src/runtime/scheduler/models/sequence_scheduler_result.dart';
import 'package:isolate_worker/isolate_worker.dart';

part 'adaptive_step_budget.dart';
part 'fair_prefill_slicer.dart';
part 'sequence_ledger.dart';
part 'sequence_materializer.dart';

abstract interface class SequenceScheduler {
  int effectiveLimitFor(Lease lease);

  SequenceUsageResult usageFor(Lease lease);

  /// This lease's resident token count if already cached, else null.
  int? cachedTokenCountFor(Lease lease);

  SequenceStepResults stepBatch({
    List<SequenceSampleRequest> samples,
    List<SequenceMaterializeRequest> materializes,
    IsolateCancellationToken? cancellationToken,
  });

  SequenceSetSamplingResult setSampling(Lease lease, EngineSampling sampling);

  /// Releases [lease] back to the allocator and forgets everything recorded
  /// for it.
  ReleaseLeaseResult release(Lease lease);
}

final class BatchingSequenceScheduler implements SequenceScheduler {
  BatchingSequenceScheduler({
    required Sequences sequences,
    required Allocator allocator,
    AdaptiveStepBudget? stepBudget,
    int contextCheckpointCount = 0,
  }) : _sequences = sequences,
       _allocator = allocator,
       _stepBudget = stepBudget ?? AdaptiveStepBudget(),
       _contextCheckpointCount = contextCheckpointCount,
       _ledger = SequenceLedger(allocator: allocator) {
    _materializer = _SequenceMaterializer(owner: this);
  }

  final Sequences _sequences;
  final Allocator _allocator;
  final AdaptiveStepBudget _stepBudget;
  final int _contextCheckpointCount;
  final SequenceLedger _ledger;
  late final _SequenceMaterializer _materializer;

  @override
  int effectiveLimitFor(Lease lease) {
    return _allocator.effectiveLimitFor(lease);
  }

  @override
  ReleaseLeaseResult release(Lease lease) {
    final result = _allocator.release(lease);
    if (result is ReleaseLeaseSucceeded) _ledger.forget(lease);
    return result;
  }

  @override
  int? cachedTokenCountFor(Lease lease) {
    if (!_allocator.owns(lease)) return null;
    return _ledger.cachedUsageFor(lease);
  }

  @override
  SequenceUsageResult usageFor(Lease lease) {
    if (!_allocator.owns(lease)) {
      return const SequenceUsageFailed(
        reason: SequenceSchedulerFailureReason.unknownLease,
      );
    }
    final cached = _ledger.cachedUsageFor(lease);
    if (cached != null) return SequenceUsageSucceeded(_usage(lease, cached));
    return _refreshUsageFor(lease);
  }

  void _recordSampleResult(
    Lease lease,
    SampleSequenceResult? result,
    Map<Lease, SequenceSampleResult> results,
  ) {
    if (result == null) {
      _ledger.invalidateLogits(lease);
      results[lease] = const SequenceSampleFailed(
        reason: SequenceSchedulerFailureReason.missingBatchResult,
      );
      return;
    }
    if (result case SampleSequenceToken(:final position)) {
      _ledger
        ..appendUsage(lease, tokenCount: 1, positionMax: position)
        ..appendMaterializedToken(
          lease,
          result.token,
          position,
          result.nextLogitsTicket,
        );
    } else {
      _ledger.invalidateLogits(lease);
    }
    results[lease] = SequenceSampleSucceeded(result);
  }

  @override
  SequenceStepResults stepBatch({
    List<SequenceSampleRequest> samples = const [],
    List<SequenceMaterializeRequest> materializes = const [],
    IsolateCancellationToken? cancellationToken,
  }) {
    final sampleResults = <Lease, SequenceSampleResult>{};
    final materializeResults = <Lease, SequenceMaterializeResult>{};

    final ready = <_ReadySampleRequest>[];
    for (final request in samples) {
      switch (_sampleReadinessFor(request.lease)) {
        case _SampleReady(:final logitsTicket):
          ready.add(
            _ReadySampleRequest(request: request, logitsTicket: logitsTicket),
          );
        case _SampleNotReady(:final result):
          sampleResults[request.lease] = result;
      }
    }

    final prefillPlans = _materializer.planBatch(
      materializes,
      materializeResults,
    );
    final stepBudget = _stepBudget.forStep(
      readySampleRows: ready.length,
      maxBatchTokens: _sequences.maxBatchTokens,
    );
    final admittedSamples = ready.take(stepBudget.maxSampleRows).toList();
    final deferredSamples = ready.skip(stepBudget.maxSampleRows);
    for (final request in deferredSamples) {
      sampleResults[request.request.lease] = const SequenceSampleDeferred(
        reason: SequenceSchedulerDeferralReason.backendBackpressure,
      );
    }

    final slicedPlans = _materializer._sliceMaterializePlans(
      prefillPlans,
      materializeResults,
      maxPrefillRows: stepBudget.maxPrefillRows,
    );

    if (admittedSamples.isEmpty && slicedPlans.isEmpty) {
      return SequenceStepResults(
        samples: sampleResults,
        materializes: materializeResults,
      );
    }

    final stepRequest = StepRequest(
      samples: [
        for (final request in admittedSamples)
          SampleRequest(logitsTicket: request.logitsTicket),
      ],
      prefills: [
        for (final plan in slicedPlans)
          PrefillRequest(
            sequenceId: plan.plan.lease.sequence.id,
            tokens: plan.tokens,
            retainLogits: plan.isFinalSlice,
            samplerMode: PrefillSamplerMode.accept,
          ),
      ],
    );
    final prefillRows = _prefillRowCount(slicedPlans);
    final shape = StepBatchShape(
      sampleRows: admittedSamples.length,
      prefillRows: prefillRows,
    );
    final stopwatch = _stepBudget.startStep();
    final step = _sequences.stepBatch(
      stepRequest,
      cancellationToken: cancellationToken,
    );

    final StepBatchSucceeded succeeded;
    switch (step) {
      case final StepBatchFailed failed:
        return _recordStepFailure(
          failed,
          shape: shape,
          admittedSamples: admittedSamples,
          slicedPlans: slicedPlans,
          sampleResults: sampleResults,
          materializeResults: materializeResults,
          cancellationToken: cancellationToken,
        );
      case final StepBatchSucceeded value:
        succeeded = value;
    }

    _stepBudget.observe(
      shape: shape,
      succeeded: true,
      elapsed: stopwatch.elapsed,
    );
    _ledger.invalidateLogitsExcept([
      for (final request in admittedSamples) request.request.lease,
      for (final plan in slicedPlans) plan.plan.lease,
    ]);
    for (final request in admittedSamples) {
      _recordSampleResult(
        request.request.lease,
        _findSampleResult(request.request.lease.sequence.id, succeeded.samples),
        sampleResults,
      );
    }
    for (final plan in slicedPlans) {
      _materializer._recordPrefillResult(
        plan,
        _findPrefillResult(plan.plan.lease.sequence.id, succeeded.prefills),
        materializeResults,
      );
    }
    return SequenceStepResults(
      samples: sampleResults,
      materializes: materializeResults,
    );
  }

  SequenceStepResults _recordStepFailure(
    StepBatchFailed failed, {
    required StepBatchShape shape,
    required List<_ReadySampleRequest> admittedSamples,
    required List<_SlicedMaterializePlan> slicedPlans,
    required Map<Lease, SequenceSampleResult> sampleResults,
    required Map<Lease, SequenceMaterializeResult> materializeResults,
    IsolateCancellationToken? cancellationToken,
  }) {
    final cancelled = cancellationToken?.isCancellationRequested ?? false;
    if (!cancelled &&
        failed.backendCode == decodeKvSlotUnavailableBackendCode) {
      _stepBudget.observe(
        shape: shape,
        backendCode: failed.backendCode,
        succeeded: false,
      );
      final canReducePrefill =
          shape.prefillRows > 0 &&
          (shape.isMixed ||
              shape.prefillRows > adaptiveStepMinimumSoloPrefillRows);
      final canReduceSamples = shape.sampleRows > adaptiveStepMinimumSampleRows;
      if (shape.prefillRows == 0 &&
          shape.sampleRows == adaptiveStepMinimumSampleRows) {
        for (final request in admittedSamples) {
          sampleResults[request.request.lease] = const SequenceSampleDeferred(
            reason: SequenceSchedulerDeferralReason.effectiveLimitReached,
          );
        }
        return SequenceStepResults(
          samples: sampleResults,
          materializes: materializeResults,
        );
      }
      if (canReducePrefill || canReduceSamples) {
        for (final request in admittedSamples) {
          sampleResults[request.request.lease] = const SequenceSampleDeferred(
            reason: SequenceSchedulerDeferralReason.backendBackpressure,
          );
        }
        for (final plan in slicedPlans) {
          materializeResults[plan.plan.lease] =
              const SequenceMaterializeDeferred(
                reason: SequenceSchedulerDeferralReason.backendBackpressure,
              );
        }
        return SequenceStepResults(
          samples: sampleResults,
          materializes: materializeResults,
        );
      }
    }
    for (final request in admittedSamples) {
      _ledger.markDirty(request.request.lease);
      sampleResults[request.request.lease] = cancelled
          ? const SequenceSampleFailed(
              reason: SequenceSchedulerFailureReason.cancelled,
            )
          : SequenceSampleFailed(
              reason: SequenceSchedulerFailureReason.backendFailure,
              backendFailure: SequenceStepBackendFailed(failed),
            );
    }
    for (final plan in slicedPlans) {
      _ledger.markDirty(plan.plan.lease);
      materializeResults[plan.plan.lease] = cancelled
          ? const SequenceMaterializeFailed(
              reason: SequenceSchedulerFailureReason.cancelled,
            )
          : SequenceMaterializeFailed(
              reason: SequenceSchedulerFailureReason.backendFailure,
              backendFailure: SequenceStepBackendFailed(failed),
            );
    }
    return SequenceStepResults(
      samples: sampleResults,
      materializes: materializeResults,
    );
  }

  @override
  SequenceSetSamplingResult setSampling(Lease lease, EngineSampling sampling) {
    if (!_allocator.owns(lease)) {
      return const SequenceSetSamplingFailed(
        reason: SequenceSchedulerFailureReason.unknownLease,
      );
    }
    final result = _sequences.setSampling(lease.sequence.id, sampling);
    return switch (result) {
      SetSamplingSucceeded() => _replayIntoSampler(lease),
      SetSamplingFailed() => SequenceSetSamplingFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceSetSamplingBackendFailed(result),
      ),
    };
  }

  /// A new sampler has seen none of the tokens the sequence holds, so they
  /// are replayed into it and the cache is kept. With nothing materialized
  /// there is nothing to keep, and the sequence is rebuilt on its next
  /// materialize.
  SequenceSetSamplingResult _replayIntoSampler(Lease lease) {
    final materialization = _ledger.materializationFor(lease);
    if (materialization == null) {
      _ledger.markDirty(lease);
      return const SequenceSetSamplingSucceeded();
    }
    _ledger.invalidateLogits(lease);
    final rebuilt = _sequences.rebuildSampler(
      lease.sequence.id,
      materialization.tokens.sublist(
        0,
        materialization.materializedTokenCount,
      ),
    );
    if (rebuilt case final RebuildSamplerFailed failed) {
      _ledger.markDirty(lease);
      return SequenceSetSamplingFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceRebuildSamplerBackendFailed(failed),
      );
    }
    return const SequenceSetSamplingSucceeded();
  }

  _SampleReadiness _sampleReadinessFor(Lease lease) {
    if (!_allocator.owns(lease)) {
      return const _SampleNotReady(
        SequenceSampleFailed(
          reason: SequenceSchedulerFailureReason.unknownLease,
        ),
      );
    }
    final logitsTicket = _ledger.logitsTicketFor(lease);
    if (logitsTicket == null) {
      return const _SampleNotReady(
        SequenceSampleDeferred(
          reason: SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );
    }
    if (logitsTicket.sequenceId != lease.sequence.id) {
      return const _SampleNotReady(
        SequenceSampleFailed(
          reason: SequenceSchedulerFailureReason.missingLogitsTicket,
        ),
      );
    }
    final usage = _ledger.usage(lease, _ledger.cachedUsageFor(lease) ?? 0);
    if (usage.tokenCount >= usage.effectiveLimit) {
      return const _SampleNotReady(
        SequenceSampleDeferred(
          reason: SequenceSchedulerDeferralReason.effectiveLimitReached,
        ),
      );
    }
    return _SampleReady(logitsTicket);
  }

  SequenceUsageResult _refreshUsageFor(Lease lease) {
    final snapshot = _sequences.kvSnapshot();
    return switch (snapshot) {
      KvSnapshotSucceeded(:final snapshot) => _usageFromSnapshot(
        lease,
        snapshot,
      ),
      KvSnapshotFailed() => SequenceUsageFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceSnapshotBackendFailed(snapshot),
      ),
    };
  }

  SequenceUsageSucceeded _usageFromSnapshot(Lease lease, KvSnapshot snapshot) {
    var usedPositions = 0;
    var positionMin = 0;
    for (final sequence in snapshot.sequences) {
      if (sequence.sequenceId == lease.sequence.id) {
        usedPositions = sequence.usedPositions;
        positionMin = sequence.positionMin < 0 ? 0 : sequence.positionMin;
        break;
      }
    }
    _ledger.cacheUsage(lease, usedPositions);
    return SequenceUsageSucceeded(
      _usage(lease, usedPositions, positionMin: positionMin),
    );
  }

  SequenceUsage _usage(Lease lease, int tokenCount, {int positionMin = 0}) {
    return _ledger.usage(lease, tokenCount, positionMin: positionMin);
  }

  PrefillSequenceResult? _findPrefillResult(
    SequenceId sequenceId,
    List<PrefillSequenceResult> results,
  ) {
    for (final result in results) {
      if (result.sequenceId == sequenceId) return result;
    }
    return null;
  }

  SampleSequenceResult? _findSampleResult(
    SequenceId sequenceId,
    List<SampleSequenceResult> results,
  ) {
    for (final result in results) {
      if (result.sequenceId == sequenceId) return result;
    }
    return null;
  }
}

int _prefillRowCount(List<_SlicedMaterializePlan> plans) {
  var rows = 0;
  for (final plan in plans) {
    rows += plan.tokens.length;
  }
  return rows;
}

bool _tokensEqual(TokenizedString first, TokenizedString second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

int _commonPrefixLength(TokenizedString first, TokenizedString second) {
  final limit = first.length < second.length ? first.length : second.length;
  for (var i = 0; i < limit; i++) {
    if (first[i] != second[i]) return i;
  }
  return limit;
}

sealed class _MaterializedUsageResult {
  const _MaterializedUsageResult();
}

final class _MaterializedUsageCurrent extends _MaterializedUsageResult {
  const _MaterializedUsageCurrent();
}

final class _MaterializedUsageLost extends _MaterializedUsageResult {
  const _MaterializedUsageLost();
}

final class _MaterializedUsageFailed extends _MaterializedUsageResult {
  const _MaterializedUsageFailed(this.result);

  final SequenceMaterializeFailed result;
}

sealed class _SampleReadiness {
  const _SampleReadiness();
}

final class _SampleReady extends _SampleReadiness {
  const _SampleReady(this.logitsTicket);

  final LogitsTicket logitsTicket;
}

final class _SampleNotReady extends _SampleReadiness {
  const _SampleNotReady(this.result);

  final SequenceSampleResult result;
}

final class _ReadySampleRequest {
  const _ReadySampleRequest({
    required this.request,
    required this.logitsTicket,
  });

  final SequenceSampleRequest request;
  final LogitsTicket logitsTicket;
}

sealed class _MaterializePlan {
  const _MaterializePlan();
}

final class _MaterializeReady extends _MaterializePlan {
  const _MaterializeReady(this.result);

  final SequenceMaterializeResult result;
}

final class _MaterializePrefillPlan extends _MaterializePlan {
  const _MaterializePrefillPlan({
    required this.lease,
    required this.tokens,
    required this.startOffset,
    required this.strategy,
    required this.reusedTokenCount,
  });

  final Lease lease;
  final TokenizedString tokens;
  final int startOffset;
  final MaterializationStrategy strategy;
  final int reusedTokenCount;
}

final class _SlicedMaterializePlan {
  const _SlicedMaterializePlan({
    required this.plan,
    required this.startOffset,
    required this.tokens,
    required this.isFinalSlice,
  });

  final _MaterializePrefillPlan plan;
  final int startOffset;
  final TokenizedString tokens;
  final bool isFinalSlice;
}

sealed class _PrefillReadiness {
  const _PrefillReadiness();
}

final class _PrefillDeferred extends _PrefillReadiness {
  const _PrefillDeferred({required this.reason});

  final SequenceSchedulerDeferralReason reason;
}

final class _PrefillFailed extends _PrefillReadiness {
  const _PrefillFailed({required this.reason});

  final SequenceSchedulerFailureReason reason;
}
