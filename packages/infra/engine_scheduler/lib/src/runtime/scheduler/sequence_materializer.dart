part of 'sequence_scheduler.dart';

final class _SequenceMaterializer {
  _SequenceMaterializer({required BatchingSequenceScheduler owner})
    : _owner = owner;

  final BatchingSequenceScheduler _owner;
  final _prefillSlicer = FairPrefillSlicer();

  Sequences get _sequences => _owner._sequences;

  Allocator get _allocator => _owner._allocator;

  SequenceLedger get _ledger => _owner._ledger;

  int get _contextCheckpointCount => _owner._contextCheckpointCount;

  int get _nSwa => _allocator.nSwa;

  bool get _isRecurrent => _allocator.isRecurrent;

  /// Minimum prefix growth between successive checkpoint captures. Anchors any
  /// denser than this only overlap sliding windows without adding reach.
  static const int _checkpointMinStep = 256;

  List<_MaterializePrefillPlan> planBatch(
    List<SequenceMaterializeRequest> requests,
    Map<Lease, SequenceMaterializeResult> results,
  ) {
    final prefillPlans = <_MaterializePrefillPlan>[];
    for (final request in requests) {
      final plan = _planMaterialization(request);
      switch (plan) {
        case _MaterializeReady(:final result):
          results[request.lease] = result;
        case _MaterializePrefillPlan():
          prefillPlans.add(plan);
      }
    }

    return prefillPlans;
  }

  _MaterializePlan _planMaterialization(SequenceMaterializeRequest request) {
    final lease = request.lease;
    final tokens = request.tokens;
    final previous = _ledger.materializationFor(lease);

    if (previous == null) {
      if (_ledger.isDirty(lease)) {
        return _planMaterializeRebuild(request);
      }
      return _planMaterializePrefill(
        request,
        startOffset: 0,
        strategy: MaterializationStrategy.fullPrefill,
      );
    }

    if (_tokensEqual(previous.tokens, tokens)) {
      final valid = _hasMaterializedUsage(lease, previous);
      if (valid case _MaterializedUsageFailed(:final result)) {
        return _MaterializeReady(result);
      }
      if (valid case _MaterializedUsageLost()) {
        return _planMaterializeViaCheckpoint(
              request,
              previous: previous,
              reusable: previous.materializedTokenCount,
            ) ??
            _planMaterializeRebuild(request);
      }

      if (!previous.isComplete) {
        return _planMaterializePrefill(
          request,
          startOffset: previous.materializedTokenCount,
          strategy: previous.strategy,
          reusedTokenCount: previous.reusedTokenCount,
        );
      }

      // Without logits, the last token is evaluated again as for a
      // truncation instead of rebuilding the whole sequence.
      final logitsTicket = _ledger.logitsTicketFor(lease);
      if (logitsTicket != null) {
        return _MaterializeReady(
          _ledger.recordMaterialization(
            lease,
            tokens,
            positionMin: 0,
            positionMax: previous.positionMax,
            materializedTokenCount: tokens.length,
            logitsTicket: logitsTicket,
            strategy: MaterializationStrategy.prefixReuse,
            reusedTokenCount: tokens.length,
          ),
        );
      }
    }

    final reusable = _reusablePrefixLength(previous, tokens);
    if (reusable == 0) {
      return _planMaterializeRebuild(request);
    }

    final SequenceUsage resident;
    switch (_owner._refreshUsageFor(lease)) {
      case SequenceUsageSucceeded(:final usage):
        resident = usage;
      case final SequenceUsageFailed failure:
        return _MaterializeReady(failure.toMaterializeFailure());
    }

    // Prefix reuse is sound only while the shared prefix is still resident: a
    // benign floor may sit below it, but a floor risen into the SWA window or a
    // ceiling short of the prefix is genuine loss.
    if (!_residentHoldsPrefix(resident, reusable)) {
      return _planMaterializeViaCheckpoint(
            request,
            previous: previous,
            reusable: reusable,
          ) ??
          _planMaterializeRebuild(request);
    }

    // A pure truncation reuses the whole new prompt, but the retained tail no
    // longer carries logits. Re-evaluate the final token so the prefill yields
    // a fresh logits ticket to sample from.
    final startOffset = reusable == tokens.length ? reusable - 1 : reusable;

    final droppedTail = startOffset < previous.materializedTokenCount;
    if (droppedTail) {
      // Recurrent memory (SSM / Gated DeltaNet) cannot partially rewind, so the
      // divergent tail can never be trimmed in place. Restore a full-state
      // checkpoint at or below the divergence, or rebuild from zero — the same
      // recovery a risen SWA floor takes.
      if (_isRecurrent) {
        return _planMaterializeViaCheckpoint(
              request,
              previous: previous,
              reusable: reusable,
            ) ??
            _planMaterializeRebuild(request);
      }
      final failure = _dropDivergentTail(
        lease,
        start: startOffset,
        end: previous.materializedTokenCount,
        tokens: tokens,
      );
      if (failure != null) return _MaterializeReady(failure);
    }

    return _planMaterializePrefill(
      request,
      startOffset: startOffset,
      strategy: droppedTail
          ? MaterializationStrategy.divergentReuse
          : MaterializationStrategy.prefixReuse,
    );
  }

  int _reusablePrefixLength(
    SequenceMaterialization previous,
    TokenizedString tokens,
  ) {
    final common = _commonPrefixLength(previous.tokens, tokens);
    return common < previous.materializedTokenCount
        ? common
        : previous.materializedTokenCount;
  }

  SequenceMaterializeFailed? _dropDivergentTail(
    Lease lease, {
    required int start,
    required int end,
    required TokenizedString tokens,
  }) {
    final removed = _sequences.removeRange(
      lease.sequence.id,
      start: start,
      end: end,
    );
    if (removed case final RemoveRangeFailed failed) {
      _ledger.markDirty(lease);
      return SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceRemoveRangeBackendFailed(failed),
      );
    }

    final rebuilt = _sequences.rebuildSampler(
      lease.sequence.id,
      tokens.sublist(0, start),
    );
    if (rebuilt case final RebuildSamplerFailed failed) {
      _ledger.markDirty(lease);
      return SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceRebuildSamplerBackendFailed(failed),
      );
    }

    _ledger
      ..invalidateLogits(lease)
      ..cacheUsage(lease, start)
      ..invalidateCheckpointsAbove(lease, start);
    return null;
  }

  // On a sliding-window model a risen SWA floor forces a rebuild-from-zero.
  // When a clean checkpoint anchors the reusable prefix we instead restore its
  // partial state and reprocess forward from it — turning a full re-prefill
  // into a partial one and regenerating exact sliding-window state for the
  // tail. Returns null (fall through to rebuild) when no anchor is available;
  // on a backend mutation failure it surfaces the failure directly.
  _MaterializePlan? _planMaterializeViaCheckpoint(
    SequenceMaterializeRequest request, {
    required SequenceMaterialization previous,
    required int reusable,
  }) {
    if ((!_isRecurrent && _nSwa <= 0) || _contextCheckpointCount <= 0) {
      return null;
    }

    final lease = request.lease;
    final checkpoint = _ledger._findCheckpoint(lease, maxTokenCount: reusable);
    if (checkpoint == null) return null;

    final id = lease.sequence.id;
    final restored = _sequences.restoreCheckpoint(id, checkpoint.bytes);
    if (restored case RestoreCheckpointFailed()) {
      _ledger.markDirty(lease);
      return _planMaterializeRebuild(request);
    }

    // On a recurrent model the full-state restore already replaced the whole
    // sequence, so there is no stale tail to drop.
    // Only a partial-state (SWA `PARTIAL_ONLY`) restore leaves the full-
    // attention cells past the anchor resident; those must be trimmed so the
    // reprocess writes fresh cells instead of duplicating positions.
    if (!_isRecurrent &&
        checkpoint.tokenCount < previous.materializedTokenCount) {
      final removed = _sequences.removeRange(
        id,
        start: checkpoint.tokenCount,
        end: previous.materializedTokenCount,
      );
      if (removed case final RemoveRangeFailed failed) {
        _ledger.markDirty(lease);
        return _MaterializeReady(
          SequenceMaterializeFailed(
            reason: SequenceSchedulerFailureReason.backendFailure,
            backendFailure: SequenceRemoveRangeBackendFailed(failed),
          ),
        );
      }
    }

    final rebuilt = _sequences.rebuildSampler(
      id,
      request.tokens.sublist(0, checkpoint.tokenCount),
    );
    if (rebuilt case final RebuildSamplerFailed failed) {
      _ledger.markDirty(lease);
      return _MaterializeReady(
        SequenceMaterializeFailed(
          reason: SequenceSchedulerFailureReason.backendFailure,
          backendFailure: SequenceRebuildSamplerBackendFailed(failed),
        ),
      );
    }

    _ledger
      ..invalidateLogits(lease)
      ..cacheUsage(lease, checkpoint.tokenCount)
      ..invalidateCheckpointsAbove(lease, checkpoint.tokenCount);
    return _planMaterializePrefill(
      request,
      startOffset: checkpoint.tokenCount,
      strategy: MaterializationStrategy.checkpointRestore,
    );
  }

  _MaterializePlan _planMaterializePrefill(
    SequenceMaterializeRequest request, {
    required int startOffset,
    required MaterializationStrategy strategy,
    int? reusedTokenCount,
  }) {
    final readiness = _prefillReadinessFor(
      request.lease,
      targetTokenCount: request.tokens.length,
      additionalTokens: request.tokens.length - startOffset,
    );
    if (readiness case _PrefillDeferred(:final reason)) {
      return _MaterializeReady(SequenceMaterializeDeferred(reason: reason));
    }
    if (readiness case _PrefillFailed(:final reason)) {
      return _MaterializeReady(SequenceMaterializeFailed(reason: reason));
    }
    return _MaterializePrefillPlan(
      lease: request.lease,
      tokens: request.tokens,
      startOffset: startOffset,
      strategy: strategy,
      reusedTokenCount: reusedTokenCount ?? startOffset,
    );
  }

  _MaterializePlan _planMaterializeRebuild(SequenceMaterializeRequest request) {
    final readiness = _materializeRebuildReadinessFor(
      request.lease,
      request.tokens,
    );
    if (readiness != null) return _MaterializeReady(readiness);
    final prepared = _prepareRebuild(request.lease);
    if (prepared != null) {
      return _MaterializeReady(
        SequenceMaterializeFailed(
          reason: prepared.reason,
          backendFailure: prepared.backendFailure,
        ),
      );
    }
    return _MaterializePrefillPlan(
      lease: request.lease,
      tokens: request.tokens,
      startOffset: 0,
      strategy: MaterializationStrategy.rebuild,
      reusedTokenCount: 0,
    );
  }

  void _recordPrefillResult(
    _SlicedMaterializePlan plan,
    PrefillSequenceResult? result,
    Map<Lease, SequenceMaterializeResult> results,
  ) {
    final lease = plan.plan.lease;
    if (result == null) {
      _ledger.markDirty(lease);
      results[lease] = const SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.missingBatchResult,
      );
      return;
    }
    final logitsTicket = switch (result) {
      PrefillSequenceWithLogitsSucceeded(:final logitsTicket) => logitsTicket,
      PrefillSequenceSucceeded() => null,
    };
    final decodedTokenCount = result.positionMax - result.positionMin + 1;
    final materializedTokenCount = plan.startOffset + decodedTokenCount;
    _ledger.appendUsage(
      lease,
      tokenCount: decodedTokenCount,
      positionMax: result.positionMax,
    );
    if (logitsTicket == null) {
      if (plan.isFinalSlice) {
        _ledger.markDirty(lease);
        results[lease] = const SequenceMaterializeFailed(
          reason: SequenceSchedulerFailureReason.missingLogitsTicket,
        );
        return;
      }
      results[lease] = _ledger.recordMaterializationAdvanced(
        lease,
        plan.plan.tokens,
        positionMin: result.positionMin,
        positionMax: result.positionMax,
        materializedTokenCount: materializedTokenCount,
        strategy: plan.plan.strategy,
        reusedTokenCount: plan.plan.reusedTokenCount,
      );
      // Anchor intermediate slice boundaries too, not just the final one. The
      // sole final-length anchor always sits at or above the next turn's
      // divergence (which lands where the prior turn's generated/stripped tail
      // began), so without sub-prompt anchors a divergent turn can never find a
      // usable checkpoint and falls back to a full rebuild.
      _maybeCaptureCheckpoint(lease, materializedTokenCount);
      return;
    }
    results[lease] = _ledger.recordMaterialization(
      lease,
      plan.plan.tokens,
      positionMin: result.positionMin,
      positionMax: result.positionMax,
      materializedTokenCount: materializedTokenCount,
      logitsTicket: logitsTicket,
      strategy: plan.plan.strategy,
      reusedTokenCount: plan.plan.reusedTokenCount,
    );
    _maybeCaptureCheckpoint(lease, materializedTokenCount);
  }

  // Captures a state anchor once a completed prefix has settled. Every reuse
  // path here is a clean forward decode, so the captured state faithfully
  // seeds a future restore.
  void _maybeCaptureCheckpoint(Lease lease, int materializedTokenCount) {
    if ((!_isRecurrent && _nSwa <= 0) || _contextCheckpointCount <= 0) return;
    final last = _ledger.lastCheckpointTokenCountFor(lease) ?? 0;
    if (materializedTokenCount - last < _checkpointMinStep) return;
    final read = _sequences.readCheckpoint(lease.sequence.id);
    if (read case ReadCheckpointSucceeded(:final bytes) when bytes.isNotEmpty) {
      _ledger._putCheckpoint(
        lease,
        _Checkpoint(tokenCount: materializedTokenCount, bytes: bytes),
        maxCount: _contextCheckpointCount,
      );
    }
  }

  List<_SlicedMaterializePlan> _sliceMaterializePlans(
    List<_MaterializePrefillPlan> plans,
    Map<Lease, SequenceMaterializeResult> results, {
    required int maxPrefillRows,
  }) {
    final counts = _prefillSlicer.allocate(
      maxBatchTokens: maxPrefillRows,
      streams: [
        for (final plan in plans)
          FairPrefillStream(
            key: plan.lease,
            remainingTokenCount: plan.tokens.length - plan.startOffset,
            weight: _allocator.effectiveLimitFor(plan.lease),
          ),
      ],
    );
    final sliced = <_SlicedMaterializePlan>[];
    for (var index = 0; index < plans.length; index++) {
      final plan = plans[index];
      final sliceLength = counts[index];
      if (sliceLength == 0) {
        results[plan.lease] = const SequenceMaterializeDeferred(
          reason: SequenceSchedulerDeferralReason.batchCapacityExhausted,
        );
        continue;
      }
      final end = plan.startOffset + sliceLength;
      sliced.add(
        _SlicedMaterializePlan(
          plan: plan,
          startOffset: plan.startOffset,
          tokens: Int64List.fromList(
            plan.tokens.sublist(plan.startOffset, end),
          ),
          isFinalSlice: end == plan.tokens.length,
        ),
      );
    }
    return sliced;
  }

  SequenceMaterializeResult? _materializeRebuildReadinessFor(
    Lease lease,
    TokenizedString tokens,
  ) {
    if (!_allocator.owns(lease)) {
      return const SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.unknownLease,
      );
    }
    if (tokens.length > _allocator.effectiveLimitFor(lease)) {
      return const SequenceMaterializeDeferred(
        reason:
            SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
      );
    }
    return null;
  }

  _MaterializedUsageResult _hasMaterializedUsage(
    Lease lease,
    SequenceMaterialization materialization,
  ) {
    final SequenceUsage resident;
    switch (_owner._refreshUsageFor(lease)) {
      case SequenceUsageSucceeded(:final usage):
        resident = usage;
      case final SequenceUsageFailed failure:
        return _MaterializedUsageFailed(failure.toMaterializeFailure());
    }
    if (!_residentHoldsPrefix(
      resident,
      materialization.materializedTokenCount,
    )) {
      return const _MaterializedUsageLost();
    }
    return const _MaterializedUsageCurrent();
  }

  /// Whether the resident cells still soundly hold the prefix `[0, length)`.
  ///
  /// Two ways to lose it, both of which a non-zero floor alone does *not*
  /// imply: on a sliding-window model the floor has risen into the window the
  /// next token attends to (`positionMin + nSwa > length`), or the resident
  /// ceiling no longer reaches the prefix end (`tokenCount < length`, with
  /// tokenCount counting consumed positions up to the ceiling). A benign SWA
  /// floor sits below the window and — because the interleaved full-attention
  /// layers keep the prefix resident — leaves reuse sound even though
  /// `seq_pos_min` reports it above zero.
  bool _residentHoldsPrefix(SequenceUsage resident, int length) {
    if (_nSwa > 0 &&
        resident.positionMin > 0 &&
        resident.positionMin + _nSwa > length) {
      return false;
    }
    return resident.tokenCount >= length;
  }

  SequenceMaterializeFailed? _prepareRebuild(Lease lease) {
    final clear = _sequences.clear(lease.sequence.id);
    if (clear case final ClearSequenceFailed failed) {
      return SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceClearBackendFailed(failed),
      );
    }
    _ledger
      ..forget(lease)
      ..cacheUsage(lease, 0);

    final rebuild = _sequences.rebuildSampler(lease.sequence.id, Int64List(0));
    if (rebuild case final RebuildSamplerFailed failed) {
      return SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.backendFailure,
        backendFailure: SequenceRebuildSamplerBackendFailed(failed),
      );
    }
    return null;
  }

  _PrefillReadiness? _prefillReadinessFor(
    Lease lease, {
    required int targetTokenCount,
    required int additionalTokens,
  }) {
    if (!_allocator.owns(lease)) {
      return const _PrefillFailed(
        reason: SequenceSchedulerFailureReason.unknownLease,
      );
    }
    final usage = _ledger.usage(lease, _ledger.cachedUsageFor(lease) ?? 0);
    if (usage.tokenCount >= usage.effectiveLimit) {
      return const _PrefillDeferred(
        reason: SequenceSchedulerDeferralReason.effectiveLimitReached,
      );
    }
    if (targetTokenCount > usage.effectiveLimit ||
        usage.tokenCount + additionalTokens > usage.effectiveLimit) {
      return const _PrefillDeferred(
        reason:
            SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
      );
    }
    return null;
  }
}

extension _SequenceUsageFailureMaterialization on SequenceUsageFailed {
  SequenceMaterializeFailed toMaterializeFailure() {
    return SequenceMaterializeFailed(
      reason: reason,
      backendFailure: backendFailure,
    );
  }
}
