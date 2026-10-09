import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  group('LeaseAllocator', () {
    late _MockContext context;
    late _MockSequences scheduler;
    late int nextSequenceId;

    setUpAll(() {
      registerFallbackValue(
        const SequenceRequest(sampling: EngineSampling(seed: 0)),
      );
    });

    setUp(() {
      context = _MockContext();
      scheduler = _MockSequences();
      nextSequenceId = 1;

      when(() => context.envelope).thenReturn(_envelope());
      when(() => context.sequences).thenReturn(scheduler);
      when(() => scheduler.acquire(any())).thenAnswer(
        (_) => RequestSequenceSucceeded(Sequence(id: nextSequenceId++)),
      );
      when(
        () => scheduler.release(any()),
      ).thenReturn(const ReleaseSequenceSucceeded());
      when(() => scheduler.kvSnapshot()).thenReturn(
        const KvSnapshotSucceeded(KvSnapshot(contextSize: 8, sequences: [])),
      );
    });

    test('reports the attention shape of the backing context', () {
      when(
        () => context.envelope,
      ).thenReturn(_envelope(nSwa: 512, isRecurrent: true));

      final allocator = LeaseAllocator(context: context);

      expect(allocator.nSwa, 512);
      expect(allocator.isRecurrent, isTrue);
    });

    test('reserves a primary lease from the context scheduler', () {
      final allocator = LeaseAllocator(context: context);
      const sampling = EngineSampling(seed: 7);

      final result = allocator.reservePrimary(sampling: sampling);

      expect(allocator.contextSize, 8);
      expect(allocator.maxSequences, 4);
      expect(
        result,
        isA<ReservePrimarySucceeded>().having(
          (result) => result.lease.fullLimit,
          'fullLimit',
          8,
        ),
      );
      final lease = (result as ReservePrimarySucceeded).lease;
      expect(allocator.owns(lease), isTrue);
      expect(allocator.effectiveLimitFor(lease), 8);
      verify(
        () => scheduler.acquire(
          any(
            that: isA<SequenceRequest>().having(
              (request) => request.sampling,
              'sampling',
              same(sampling),
            ),
          ),
        ),
      ).called(1);
    });

    test('rejects a duplicate primary lease', () {
      final allocator = LeaseAllocator(context: context)
        ..reservePrimary(sampling: const EngineSampling(seed: 1));

      final result = allocator.reservePrimary(
        sampling: const EngineSampling(seed: 2),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.primaryAlreadyReserved,
        ),
      );
      verify(() => scheduler.acquire(any())).called(1);
    });

    test('rejects primary reservation when sequence capacity is exhausted', () {
      when(() => context.envelope).thenReturn(_envelope(maxSequences: 0));
      final allocator = LeaseAllocator(context: context);

      final result = allocator.reservePrimary(
        sampling: const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.noSequenceCapacity,
        ),
      );
      verifyNever(() => scheduler.acquire(any()));
    });

    test('preserves scheduler failure when reserving a primary lease', () {
      when(() => scheduler.acquire(any())).thenReturn(
        const RequestSequenceFailed(message: 'failed', stackTrace: 'stack'),
      );
      final allocator = LeaseAllocator(context: context);

      final result = allocator.reservePrimary(
        sampling: const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.schedulerFailure,
        ),
      );
    });

    test('reserves subagent leases and accounts for active claims', () {
      final allocator = LeaseAllocator(context: context);
      final primary =
          allocator.reservePrimary(sampling: const EngineSampling(seed: 1))
              as ReservePrimarySucceeded;
      final subagent = allocator.reserveSubagent(
        contextSize: 3,
        sampling: const EngineSampling(seed: 2),
      );

      expect(
        subagent,
        isA<ReserveSubagentSucceeded>().having(
          (result) => result.lease.claimSize,
          'claimSize',
          3,
        ),
      );
      final subagentLease = (subagent as ReserveSubagentSucceeded).lease;
      expect(allocator.activeSubagentClaims, 3);
      expect(allocator.owns(subagentLease), isTrue);
      expect(allocator.effectiveLimitFor(subagentLease), 3);
      expect(allocator.effectiveLimitFor(primary.lease), 5);
    });

    test('rejects invalid subagent claim sizes', () {
      final allocator = LeaseAllocator(context: context);

      final result = allocator.reserveSubagent(
        contextSize: 0,
        sampling: const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.invalidClaimSize,
        ),
      );
      verifyNever(() => scheduler.acquire(any()));
    });

    test(
      'rejects subagent reservations when sequence capacity is exhausted',
      () {
        when(() => context.envelope).thenReturn(_envelope(maxSequences: 1));
        final allocator = LeaseAllocator(context: context)
          ..reservePrimary(sampling: const EngineSampling(seed: 1));

        final result = allocator.reserveSubagent(
          contextSize: 1,
          sampling: const EngineSampling(seed: 2),
        );

        expect(
          result,
          isA<ReserveLeaseFailed>().having(
            (result) => result.reason,
            'reason',
            ReserveLeaseFailureReason.noSequenceCapacity,
          ),
        );
        verify(() => scheduler.acquire(any())).called(1);
      },
    );

    test('rejects subagent reservations without enough claim space', () {
      final allocator = LeaseAllocator(context: context)
        ..reserveSubagent(
          contextSize: 5,
          sampling: const EngineSampling(seed: 1),
        );

      final result = allocator.reserveSubagent(
        contextSize: 4,
        sampling: const EngineSampling(seed: 2),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.insufficientClaimSpace,
        ),
      );
      verify(() => scheduler.acquire(any())).called(1);
    });

    test('rejects a subagent claim that overlaps the primary residency', () {
      final allocator = LeaseAllocator(context: context);
      final primary =
          allocator.reservePrimary(sampling: const EngineSampling(seed: 1))
              as ReservePrimarySucceeded;
      when(() => scheduler.kvSnapshot()).thenReturn(
        KvSnapshotSucceeded(
          KvSnapshot(
            contextSize: 8,
            sequences: [
              const SequenceKvState(
                sequenceId: 7,
                positionMin: 0,
                positionMax: 6,
              ),
              SequenceKvState(
                sequenceId: primary.lease.sequence.id,
                positionMin: 0,
                positionMax: 5,
              ),
            ],
          ),
        ),
      );

      final refused = allocator.reserveSubagent(
        contextSize: 3,
        sampling: const EngineSampling(seed: 2),
      );
      final admitted = allocator.reserveSubagent(
        contextSize: 2,
        sampling: const EngineSampling(seed: 3),
      );

      expect(
        refused,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.insufficientClaimSpace,
        ),
      );
      expect(admitted, isA<ReserveSubagentSucceeded>());
    });

    test('counts an absent primary sequence as holding nothing', () {
      final allocator = LeaseAllocator(context: context)
        ..reservePrimary(sampling: const EngineSampling(seed: 1));

      final result = allocator.reserveSubagent(
        contextSize: 8,
        sampling: const EngineSampling(seed: 2),
      );

      expect(result, isA<ReserveSubagentSucceeded>());
    });

    test('refuses a subagent when the primary residency is unreadable', () {
      final allocator = LeaseAllocator(context: context)
        ..reservePrimary(sampling: const EngineSampling(seed: 1));
      when(() => scheduler.kvSnapshot()).thenReturn(
        const KvSnapshotFailed(message: 'failed', stackTrace: 'stack'),
      );

      final result = allocator.reserveSubagent(
        contextSize: 1,
        sampling: const EngineSampling(seed: 2),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.schedulerFailure,
        ),
      );
    });

    test('caps the primary limit at what one sequence may hold', () {
      when(
        () => context.envelope,
      ).thenReturn(_envelope(perSequenceLimit: 6));
      final allocator = LeaseAllocator(context: context);
      final primary =
          allocator.reservePrimary(sampling: const EngineSampling(seed: 1))
              as ReservePrimarySucceeded;

      expect(primary.lease.fullLimit, 6);
      expect(allocator.effectiveLimitFor(primary.lease), 6);
      allocator.reserveSubagent(
        contextSize: 4,
        sampling: const EngineSampling(seed: 2),
      );
      expect(allocator.effectiveLimitFor(primary.lease), 4);
    });

    test('preserves scheduler failure when reserving a subagent lease', () {
      when(() => scheduler.acquire(any())).thenReturn(
        const RequestSequenceFailed(message: 'failed', stackTrace: 'stack'),
      );
      final allocator = LeaseAllocator(context: context);

      final result = allocator.reserveSubagent(
        contextSize: 1,
        sampling: const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<ReserveLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReserveLeaseFailureReason.schedulerFailure,
        ),
      );
    });

    test('releases owned primary and subagent leases', () {
      final allocator = LeaseAllocator(context: context);
      final primary =
          allocator.reservePrimary(sampling: const EngineSampling(seed: 1))
              as ReservePrimarySucceeded;
      final subagent =
          allocator.reserveSubagent(
                contextSize: 3,
                sampling: const EngineSampling(seed: 2),
              )
              as ReserveSubagentSucceeded;

      expect(allocator.release(subagent.lease), isA<ReleaseLeaseSucceeded>());
      expect(allocator.owns(subagent.lease), isFalse);
      expect(allocator.activeSubagentClaims, 0);
      expect(allocator.release(primary.lease), isA<ReleaseLeaseSucceeded>());
      expect(allocator.owns(primary.lease), isFalse);
      verify(() => scheduler.release(any())).called(2);
    });

    test('rejects releasing an unknown lease', () {
      final allocator = LeaseAllocator(context: context);
      const unknown = PrimaryLease(sequence: Sequence(id: 99), fullLimit: 8);

      final result = allocator.release(unknown);

      expect(
        result,
        isA<ReleaseLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReleaseLeaseFailureReason.unknownLease,
        ),
      );
      verifyNever(() => scheduler.release(any()));
    });

    test('preserves scheduler failure when releasing a lease', () {
      when(() => scheduler.release(any())).thenReturn(
        const ReleaseSequenceFailed(message: 'failed', stackTrace: 'stack'),
      );
      final allocator = LeaseAllocator(context: context);
      final primary =
          allocator.reservePrimary(sampling: const EngineSampling(seed: 1))
              as ReservePrimarySucceeded;

      final result = allocator.release(primary.lease);

      expect(
        result,
        isA<ReleaseLeaseFailed>().having(
          (result) => result.reason,
          'reason',
          ReleaseLeaseFailureReason.schedulerFailure,
        ),
      );
      expect(allocator.owns(primary.lease), isTrue);
    });
  });
}

ContextEnvelope _envelope({
  int contextSize = 8,
  int? perSequenceLimit,
  int maxSequences = 4,
  int nSwa = 0,
  bool isRecurrent = false,
}) => ContextEnvelope(
  contextSize: contextSize,
  perSequenceLimit: perSequenceLimit ?? contextSize,
  maxSequences: maxSequences,
  maxBatchTokens: 4,
  microBatchTokens: 4,
  nSwa: nSwa,
  isRecurrent: isRecurrent,
);

final class _MockContext extends Mock implements Context {}

final class _MockSequences extends Mock implements Sequences {}
