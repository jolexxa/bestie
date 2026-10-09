import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('SequenceLedger', () {
    test('caches usage and reports allocator limits', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      )..cacheUsage(primary, 3);

      final usage = ledger.usage(primary, ledger.cachedUsageFor(primary)!);
      expect(usage.tokenCount, 3);
      expect(usage.effectiveLimit, 8);
    });

    test('appendUsage grows from a cacheUsage overwrite', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      )..appendUsage(primary, tokenCount: 3, positionMax: 2);
      expect(ledger.cachedUsageFor(primary), 3);

      ledger.cacheUsage(primary, 5);
      expect(ledger.cachedUsageFor(primary), 5);

      ledger.appendUsage(primary, tokenCount: 1, positionMax: 5);
      expect(ledger.cachedUsageFor(primary), 6);
    });

    test('records completed materializations', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final context = _context([1, 2]);
      final ticket = _logitsTicket(sequenceId: primary.sequence.id);

      final result = ledger.recordMaterialization(
        primary,
        context,
        positionMin: 0,
        positionMax: 1,
        materializedTokenCount: 2,
        logitsTicket: ticket,
        strategy: MaterializationStrategy.fullPrefill,
        reusedTokenCount: 0,
      );

      final materialization = ledger.materializationFor(primary);
      expect(result.materialization.tokens, orderedEquals([1, 2]));
      expect(materialization!.tokens, orderedEquals([1, 2]));
      expect(materialization.isComplete, isTrue);
      expect(ledger.logitsTicketFor(primary), same(ticket));
    });

    test(
      'recorded materializations are isolated from context token changes',
      () {
        final primary = _primaryLease();
        final ledger = SequenceLedger(
          allocator: _FakeAllocator(leases: [primary]),
        );
        final context = _context([1, 2]);

        ledger.recordMaterialization(
          primary,
          context,
          positionMin: 0,
          positionMax: 1,
          materializedTokenCount: 2,
          logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        );
        context[0] = 99;

        final materialization = ledger.materializationFor(primary);
        expect(materialization!.tokens, orderedEquals([1, 2]));
      },
    );

    test('returned materializations are isolated from token changes', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final result = ledger.recordMaterialization(
        primary,
        _context([1, 2]),
        positionMin: 0,
        positionMax: 1,
        materializedTokenCount: 2,
        logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
        strategy: MaterializationStrategy.fullPrefill,
        reusedTokenCount: 0,
      );

      result.materialization.tokens[0] = 99;

      final materialization = ledger.materializationFor(primary);
      expect(materialization!.tokens, orderedEquals([1, 2]));
    });

    test('records partial materializations', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final context = _context([1, 2, 3]);

      final result = ledger.recordMaterializationAdvanced(
        primary,
        context,
        positionMin: 0,
        positionMax: 1,
        materializedTokenCount: 2,
        strategy: MaterializationStrategy.fullPrefill,
        reusedTokenCount: 0,
      );

      final materialization = ledger.materializationFor(primary);
      expect(result.materialization.tokens, orderedEquals([1, 2, 3]));
      expect(result.materialization.materializedTokenCount, 2);
      expect(materialization!.materializedTokenCount, 2);
      expect(materialization.isComplete, isFalse);
      expect(ledger.logitsTicketFor(primary), isNull);
    });

    test('sampled tokens extend a materialized prompt', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final nextTicket = _logitsTicket(sequenceId: primary.sequence.id);
      ledger
        ..recordMaterialization(
          primary,
          _context([1, 2]),
          positionMin: 0,
          positionMax: 1,
          materializedTokenCount: 2,
          logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        )
        ..appendMaterializedToken(primary, 9, 2, nextTicket);

      final materialization = ledger.materializationFor(primary);
      expect(materialization!.tokens, orderedEquals([1, 2, 9]));
      expect(materialization.materializedTokenCount, 3);
      expect(materialization.positionMax, 2);
      expect(ledger.logitsTicketFor(primary), same(nextTicket));
    });

    test('sampled token snapshots stay stable across later appends', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final firstTicket = _logitsTicket(sequenceId: primary.sequence.id);
      final secondTicket = _logitsTicket(sequenceId: primary.sequence.id);
      final result = ledger.recordMaterialization(
        primary,
        _context([1, 2]),
        positionMin: 0,
        positionMax: 1,
        materializedTokenCount: 2,
        logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
        strategy: MaterializationStrategy.fullPrefill,
        reusedTokenCount: 0,
      );
      final initial = result.materialization;

      ledger.appendMaterializedToken(primary, 9, 2, firstTicket);
      final afterFirstAppend = ledger.materializationFor(primary)!;
      ledger.appendMaterializedToken(primary, 10, 3, secondTicket);
      final afterSecondAppend = ledger.materializationFor(primary)!;

      expect(initial.tokens, orderedEquals([1, 2]));
      expect(initial.materializedTokenCount, 2);
      expect(afterFirstAppend.tokens, orderedEquals([1, 2, 9]));
      expect(afterFirstAppend.materializedTokenCount, 3);
      expect(afterSecondAppend.tokens, orderedEquals([1, 2, 9, 10]));
      expect(afterSecondAppend.materializedTokenCount, 4);
      expect(afterSecondAppend.positionMax, 3);
      expect(ledger.logitsTicketFor(primary), same(secondTicket));
    });

    test('sampled tokens can extend an empty materialization', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );
      final nextTicket = _logitsTicket(sequenceId: primary.sequence.id);
      ledger
        ..recordMaterialization(
          primary,
          _context([]),
          positionMin: 0,
          positionMax: -1,
          materializedTokenCount: 0,
          logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        )
        ..appendMaterializedToken(primary, 9, 0, nextTicket);

      final materialization = ledger.materializationFor(primary);
      expect(materialization!.tokens, orderedEquals([9]));
      expect(materialization.materializedTokenCount, 1);
      expect(materialization.positionMax, 0);
      expect(ledger.logitsTicketFor(primary), same(nextTicket));
    });

    test('can invalidate logits without clearing materialization', () {
      final primary = _primaryLease();
      final ledger =
          SequenceLedger(
              allocator: _FakeAllocator(leases: [primary]),
            )
            ..recordMaterialization(
              primary,
              _context([1, 2]),
              positionMin: 0,
              positionMax: 1,
              materializedTokenCount: 2,
              logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
              strategy: MaterializationStrategy.fullPrefill,
              reusedTokenCount: 0,
            )
            ..invalidateLogits(primary);

      expect(ledger.materializationFor(primary), isNotNull);
      expect(ledger.logitsTicketFor(primary), isNull);
    });

    test('can invalidate logits for non-participating leases', () {
      final first = _primaryLease();
      final second = _primaryLease(id: 2);
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [first, second]),
      );
      final firstTicket = _logitsTicket(sequenceId: first.sequence.id);
      final secondTicket = _logitsTicket(sequenceId: second.sequence.id);
      ledger
        ..recordMaterialization(
          first,
          _context([1]),
          positionMin: 0,
          positionMax: 0,
          materializedTokenCount: 1,
          logitsTicket: firstTicket,
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        )
        ..recordMaterialization(
          second,
          _context([2]),
          positionMin: 0,
          positionMax: 0,
          materializedTokenCount: 1,
          logitsTicket: secondTicket,
          strategy: MaterializationStrategy.fullPrefill,
          reusedTokenCount: 0,
        )
        ..invalidateLogitsExcept([first]);

      expect(ledger.logitsTicketFor(first), same(firstTicket));
      expect(ledger.materializationFor(second), isNotNull);
      expect(ledger.logitsTicketFor(second), isNull);
    });

    test('forget clears materialization and cached usage', () {
      final primary = _primaryLease();
      final ledger =
          SequenceLedger(
              allocator: _FakeAllocator(leases: [primary]),
            )
            ..cacheUsage(primary, 2)
            ..recordMaterialization(
              primary,
              _context([1, 2]),
              positionMin: 0,
              positionMax: 1,
              materializedTokenCount: 2,
              logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
              strategy: MaterializationStrategy.fullPrefill,
              reusedTokenCount: 0,
            )
            ..forget(primary);

      expect(ledger.cachedUsageFor(primary), isNull);
      expect(ledger.materializationFor(primary), isNull);
      expect(ledger.isDirty(primary), isFalse);
    });

    test('forget clears a pending rebuild', () {
      final primary = _primaryLease();
      final ledger =
          SequenceLedger(
              allocator: _FakeAllocator(leases: [primary]),
            )
            ..markDirty(primary)
            ..forget(primary);

      expect(ledger.isDirty(primary), isFalse);
    });

    test('materializations carry how many tokens were reused', () {
      final primary = _primaryLease();
      final ledger = SequenceLedger(
        allocator: _FakeAllocator(leases: [primary]),
      );

      final result = ledger.recordMaterialization(
        primary,
        _context([1, 2, 3]),
        positionMin: 2,
        positionMax: 2,
        materializedTokenCount: 3,
        logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
        strategy: MaterializationStrategy.prefixReuse,
        reusedTokenCount: 2,
      );

      expect(result.materialization.reusedTokenCount, 2);
      expect(ledger.materializationFor(primary)!.reusedTokenCount, 2);
    });

    test('markDirty clears active state and records dirty lease', () {
      final primary = _primaryLease();
      final ledger =
          SequenceLedger(
              allocator: _FakeAllocator(leases: [primary]),
            )
            ..cacheUsage(primary, 2)
            ..recordMaterialization(
              primary,
              _context([1, 2]),
              positionMin: 0,
              positionMax: 1,
              materializedTokenCount: 2,
              logitsTicket: _logitsTicket(sequenceId: primary.sequence.id),
              strategy: MaterializationStrategy.fullPrefill,
              reusedTokenCount: 0,
            )
            ..markDirty(primary);

      expect(ledger.cachedUsageFor(primary), isNull);
      expect(ledger.materializationFor(primary), isNull);
      expect(ledger.isDirty(primary), isTrue);
    });
  });
}

PrimaryLease _primaryLease({int id = 1, int fullLimit = 8}) {
  return PrimaryLease(
    sequence: Sequence(id: id),
    fullLimit: fullLimit,
  );
}

TokenizedString _context(List<int> tokens) => Int64List.fromList(tokens);

LogitsTicket _logitsTicket({required SequenceId sequenceId}) {
  return LogitsTicket(
    sequenceId: sequenceId,
    position: 0,
    batchIndex: 0,
    generation: 0,
  );
}

final class _FakeAllocator implements Allocator {
  const _FakeAllocator({required List<Lease> leases}) : _leases = leases;

  final List<Lease> _leases;

  @override
  int get activeSubagentClaims => 0;

  @override
  int get contextSize => 8;

  @override
  int get maxSequences => 4;

  @override
  int get nSwa => 0;

  @override
  bool get isRecurrent => false;

  @override
  int effectiveLimitFor(Lease lease) => switch (lease) {
    PrimaryLease(:final fullLimit) => fullLimit,
    SubagentLease(:final claimSize) => claimSize,
  };

  @override
  bool owns(Lease lease) {
    return _leases.any((owned) => identical(owned, lease));
  }

  @override
  ReleaseLeaseResult release(Lease lease) {
    throw UnimplementedError();
  }

  @override
  ReservePrimaryResult reservePrimary({required EngineSampling sampling}) {
    throw UnimplementedError();
  }

  @override
  ReserveSubagentResult reserveSubagent({
    required int contextSize,
    required EngineSampling sampling,
  }) {
    throw UnimplementedError();
  }
}
