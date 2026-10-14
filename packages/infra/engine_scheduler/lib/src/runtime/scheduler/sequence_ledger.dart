part of 'sequence_scheduler.dart';

final class SequenceLedger {
  SequenceLedger({required Allocator allocator}) : _allocator = allocator;

  final Allocator _allocator;
  final _usageCache = <Lease, int>{};
  final _materializations = <Lease, _LedgerMaterialization>{};
  final _logitsTickets = <Lease, LogitsTicket>{};
  final _dirtyMaterializations = <Lease>{};
  final _checkpoints = <Lease, List<_Checkpoint>>{};

  int? cachedUsageFor(Lease lease) => _usageCache[lease];

  SequenceMaterialization? materializationFor(Lease lease) {
    return _materializations[lease]?.snapshot();
  }

  LogitsTicket? logitsTicketFor(Lease lease) => _logitsTickets[lease];

  bool isDirty(Lease lease) => _dirtyMaterializations.contains(lease);

  /// Drops everything recorded for [lease], including a pending rebuild.
  void forget(Lease lease) {
    _materializations.remove(lease);
    _logitsTickets.remove(lease);
    _usageCache.remove(lease);
    _checkpoints.remove(lease);
    _dirtyMaterializations.remove(lease);
  }

  /// The token count of the newest checkpoint held for [lease], or null when
  /// the ring is empty. Callers use it to space captures by a minimum step.
  int? lastCheckpointTokenCountFor(Lease lease) {
    final ring = _checkpoints[lease];
    if (ring == null || ring.isEmpty) return null;
    return ring.last.tokenCount;
  }

  /// The newest checkpoint whose captured prefix does not exceed
  /// [maxTokenCount] — the nearest clean anchor at or below the reusable
  /// prefix to reprocess forward from. Null when no checkpoint qualifies.
  _Checkpoint? _findCheckpoint(Lease lease, {required int maxTokenCount}) {
    final ring = _checkpoints[lease];
    if (ring == null) return null;
    _Checkpoint? best;
    for (final checkpoint in ring) {
      if (checkpoint.tokenCount <= maxTokenCount &&
          (best == null || checkpoint.tokenCount > best.tokenCount)) {
        best = checkpoint;
      }
    }
    return best;
  }

  void _putCheckpoint(
    Lease lease,
    _Checkpoint checkpoint, {
    required int maxCount,
  }) {
    if (maxCount <= 0) return;
    final ring = _checkpoints.putIfAbsent(lease, () => <_Checkpoint>[])
      ..removeWhere((held) => held.tokenCount == checkpoint.tokenCount)
      ..add(checkpoint)
      ..sort((first, second) => first.tokenCount.compareTo(second.tokenCount));
    while (ring.length > maxCount) {
      ring.removeAt(0);
    }
  }

  /// Drops any checkpoint reaching beyond [tokenCount]. Called after a tail
  /// drop re-bases positions: anything captured past the first re-based token
  /// no longer describes the live cache, as in llama.cpp's
  /// `pos_max > pos_next` reconciliation.
  void invalidateCheckpointsAbove(Lease lease, int tokenCount) {
    final ring = _checkpoints[lease];
    if (ring == null) return;
    ring.removeWhere((checkpoint) => checkpoint.tokenCount > tokenCount);
    if (ring.isEmpty) _checkpoints.remove(lease);
  }

  void markDirty(Lease lease) {
    forget(lease);
    _dirtyMaterializations.add(lease);
  }

  void appendUsage(
    Lease lease, {
    required int tokenCount,
    required int positionMax,
  }) {
    final cached = _usageCache[lease];
    _usageCache[lease] = cached == null ? positionMax + 1 : cached + tokenCount;
  }

  void cacheUsage(Lease lease, int tokenCount) {
    _usageCache[lease] = tokenCount;
  }

  void invalidateLogits(Lease lease) {
    _logitsTickets.remove(lease);
  }

  void invalidateLogitsExcept(Iterable<Lease> retainedLeases) {
    final retained = retainedLeases.toList(growable: false);
    for (final lease in _logitsTickets.keys.toList(growable: false)) {
      if (retained.any((candidate) => identical(candidate, lease))) continue;
      invalidateLogits(lease);
    }
  }

  SequenceUsage usage(Lease lease, int tokenCount, {int positionMin = 0}) {
    return SequenceUsage(
      lease: lease,
      tokenCount: tokenCount,
      effectiveLimit: _allocator.effectiveLimitFor(lease),
      positionMin: positionMin,
    );
  }

  SequenceMaterializeSucceeded recordMaterialization(
    Lease lease,
    TokenizedString tokens, {
    required int positionMin,
    required int positionMax,
    required int materializedTokenCount,
    required LogitsTicket logitsTicket,
    required MaterializationStrategy strategy,
    required int reusedTokenCount,
  }) {
    final record = _LedgerMaterialization(
      tokens: _TokenBuffer.from(tokens),
      materializedTokenCount: materializedTokenCount,
      positionMax: positionMax,
      strategy: strategy,
      reusedTokenCount: reusedTokenCount,
    );
    final materialization = record.snapshot();
    _dirtyMaterializations.remove(lease);
    _materializations[lease] = record;
    _logitsTickets[lease] = logitsTicket;
    return SequenceMaterializeSucceeded(
      sequenceId: lease.sequence.id,
      positionMin: positionMin,
      positionMax: positionMax,
      materialization: materialization,
    );
  }

  SequenceMaterializeAdvanced recordMaterializationAdvanced(
    Lease lease,
    TokenizedString tokens, {
    required int positionMin,
    required int positionMax,
    required int materializedTokenCount,
    required MaterializationStrategy strategy,
    required int reusedTokenCount,
  }) {
    final record = _LedgerMaterialization(
      tokens: _TokenBuffer.from(tokens),
      materializedTokenCount: materializedTokenCount,
      positionMax: positionMax,
      strategy: strategy,
      reusedTokenCount: reusedTokenCount,
    );
    final materialization = record.snapshot();
    _materializations[lease] = record;
    _logitsTickets.remove(lease);
    return SequenceMaterializeAdvanced(
      sequenceId: lease.sequence.id,
      positionMin: positionMin,
      positionMax: positionMax,
      materialization: materialization,
    );
  }

  void appendMaterializedToken(
    Lease lease,
    TokenId token,
    int positionMax,
    LogitsTicket logitsTicket,
  ) {
    final previous = _materializations[lease];
    if (previous == null) return;
    previous.appendToken(token, positionMax: positionMax);
    _logitsTickets[lease] = logitsTicket;
  }
}

final class _LedgerMaterialization {
  _LedgerMaterialization({
    required _TokenBuffer tokens,
    required this.materializedTokenCount,
    required this.positionMax,
    required this.strategy,
    required this.reusedTokenCount,
  }) : _tokens = tokens;

  final _TokenBuffer _tokens;
  int materializedTokenCount;
  int positionMax;
  final MaterializationStrategy strategy;
  final int reusedTokenCount;

  void appendToken(TokenId token, {required int positionMax}) {
    _tokens.append(token);
    materializedTokenCount = _tokens.length;
    this.positionMax = positionMax;
  }

  SequenceMaterialization snapshot() {
    return SequenceMaterialization(
      tokens: _tokens.toTokenizedString(),
      materializedTokenCount: materializedTokenCount,
      positionMax: positionMax,
      strategy: strategy,
      reusedTokenCount: reusedTokenCount,
    );
  }
}

/// A serialized sliding-window (`PARTIAL_ONLY`) KV snapshot captured at a clean
/// forward-decode anchor, tagged with the prefix length it covers.
final class _Checkpoint {
  const _Checkpoint({required this.tokenCount, required this.bytes});

  final int tokenCount;
  final Uint8List bytes;
}

final class _TokenBuffer {
  _TokenBuffer._(this._tokens, this.length);

  factory _TokenBuffer.from(TokenizedString tokens) {
    final copy = Int64List(tokens.length)..setRange(0, tokens.length, tokens);
    return _TokenBuffer._(copy, tokens.length);
  }

  Int64List _tokens;
  int length;

  void append(TokenId token) {
    _ensureCapacity(length + 1);
    _tokens[length] = token;
    length += 1;
  }

  TokenizedString toTokenizedString() {
    return Int64List(length)..setRange(0, length, _tokens);
  }

  void _ensureCapacity(int capacity) {
    if (capacity <= _tokens.length) return;
    final nextCapacity = _tokens.isEmpty ? 8 : _tokens.length * 2;
    _tokens = Int64List(nextCapacity)..setRange(0, length, _tokens);
  }
}
