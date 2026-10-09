import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockStopwatch extends Mock implements Stopwatch {}

const _fullStep = StepBatchShape(sampleRows: 0, prefillRows: 512);

void main() {
  group('AdaptiveStepBudget', () {
    test('uses full backend capacity by default', () {
      final budget = AdaptiveStepBudget();

      final result = budget.forStep(readySampleRows: 3, maxBatchTokens: 512);

      expect(result.maxSampleRows, 3);
      expect(result.maxPrefillRows, 509);
    });

    test('halves elastic prefill only after slot failure', () {
      final budget = AdaptiveStepBudget()
        ..observe(
          shape: const StepBatchShape(
            sampleRows: 1,
            prefillRows: 300,
          ),
          backendCode: decodeKvSlotUnavailableBackendCode,
          succeeded: false,
        );
      final retried = budget.forStep(readySampleRows: 1, maxBatchTokens: 512);

      expect(retried.maxSampleRows, 1);
      expect(retried.maxPrefillRows, 150);
    });

    test('restores full capacity after a successful retry', () {
      final budget = AdaptiveStepBudget()
        ..observe(
          shape: const StepBatchShape(
            sampleRows: 1,
            prefillRows: 300,
          ),
          backendCode: decodeKvSlotUnavailableBackendCode,
          succeeded: false,
        )
        ..observe(
          shape: const StepBatchShape(
            sampleRows: 1,
            prefillRows: 150,
          ),
          succeeded: true,
        );
      final restored = budget.forStep(readySampleRows: 1, maxBatchTokens: 512);

      expect(restored.maxSampleRows, 1);
      expect(restored.maxPrefillRows, 511);
    });

    group('time budget', () {
      AdaptiveStepBudget budgetAfter(List<Duration> steps) {
        final budget = AdaptiveStepBudget();
        for (final elapsed in steps) {
          final allowed = budget.forStep(
            readySampleRows: 0,
            maxBatchTokens: 512,
          );
          budget.observe(
            shape: StepBatchShape(
              sampleRows: 0,
              prefillRows: allowed.maxPrefillRows,
            ),
            succeeded: true,
            elapsed: elapsed,
          );
        }
        return budget;
      }

      test('caps prefill so a slow step lands near the target', () {
        final budget = budgetAfter([const Duration(milliseconds: 200)]);

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          128,
        );
      });

      test('runs a prefill uncapped while nothing waits to decode', () {
        final budget = budgetAfter([const Duration(milliseconds: 200)]);

        expect(
          budget
              .forStep(readySampleRows: 0, maxBatchTokens: 512)
              .maxPrefillRows,
          512,
        );
      });

      test('grows the cap again, at most doubling per step', () {
        final budget = AdaptiveStepBudget();
        for (final elapsed in const [
          Duration(milliseconds: 200),
          Duration(milliseconds: 5),
        ]) {
          final allowed = budget.forStep(
            readySampleRows: 1,
            maxBatchTokens: 512,
          );
          budget.observe(
            shape: StepBatchShape(
              sampleRows: 1,
              prefillRows: allowed.maxPrefillRows,
            ),
            succeeded: true,
            elapsed: elapsed,
          );
        }

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          255,
        );
      });

      test('counts decode rows against the target', () {
        final budget = AdaptiveStepBudget()
          ..forStep(readySampleRows: 12, maxBatchTokens: 512)
          ..observe(
            shape: const StepBatchShape(sampleRows: 12, prefillRows: 500),
            succeeded: true,
            elapsed: const Duration(milliseconds: 100),
          );

        expect(
          budget
              .forStep(readySampleRows: 12, maxBatchTokens: 512)
              .maxPrefillRows,
          244,
        );
      });

      test('a short step that had little to prefill teaches nothing', () {
        final budget = budgetAfter([const Duration(milliseconds: 200)])
          ..observe(
            shape: const StepBatchShape(sampleRows: 0, prefillRows: 4),
            succeeded: true,
            elapsed: const Duration(milliseconds: 1),
          );

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          128,
        );
      });

      test('a short step past the target still shrinks the cap', () {
        final budget = AdaptiveStepBudget()
          ..observe(
            shape: const StepBatchShape(sampleRows: 0, prefillRows: 100),
            succeeded: true,
            elapsed: const Duration(milliseconds: 100),
          );

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          50,
        );
      });

      test('keeps at least one prefill row', () {
        final budget = budgetAfter([const Duration(seconds: 100)]);

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          1,
        );
      });

      test('steps without prefill or timing leave the cap alone', () {
        final budget = budgetAfter([const Duration(milliseconds: 200)])
          ..observe(
            shape: const StepBatchShape(sampleRows: 4, prefillRows: 0),
            succeeded: true,
            elapsed: const Duration(seconds: 1),
          )
          ..observe(shape: _fullStep, succeeded: true)
          ..observe(
            shape: _fullStep,
            succeeded: false,
            elapsed: const Duration(milliseconds: 1),
          );

        expect(
          budget
              .forStep(readySampleRows: 1, maxBatchTokens: 512)
              .maxPrefillRows,
          128,
        );
      });

      test('times each step with the injected stopwatch', () {
        final stopwatch = _MockStopwatch();
        when(() => stopwatch.elapsed).thenReturn(
          const Duration(milliseconds: 100),
        );
        final budget = AdaptiveStepBudget(stopwatch: () => stopwatch);
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
          stepBudget: budget,
        );

        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5, 6]));

        verify(stopwatch.start).called(1);
        expect(
          budget.forStep(readySampleRows: 1, maxBatchTokens: 5).maxPrefillRows,
          2,
        );
      });
    });
  });

  group('BatchingSequenceScheduler', () {
    test('materialize prefill runs through the backend scheduler', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1, 2]));

      expect(backend.prefillBatchCalls, 1);
      expect(backend.lastPrefillRequests, hasLength(1));
      expect(
        result,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.sequenceId,
          'sequenceId',
          primary.sequence.id,
        ),
      );
    });

    test('materialize forwards cancellation token to backend prefill', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      final cancellation = IsolateCancellationTokenSource();

      _materialize(
        scheduler,
        primary,
        _context([1, 2]),
        cancellationToken: cancellation.token,
      );

      expect(backend.lastPrefillCancellationToken, same(cancellation.token));
    });

    test('sample runs immediately through the backend scheduler', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      _materialize(scheduler, primary, _context([1]));

      final result = _sample(scheduler, primary);

      expect(backend.sampleBatchCalls, 1);
      expect(backend.lastSampleRequests, hasLength(1));
      expect(result, isA<SequenceSampleSucceeded>());
    });

    test('sample forwards cancellation token to backend sample', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      final cancellation = IsolateCancellationTokenSource();
      _materialize(scheduler, primary, _context([1]));

      _sample(scheduler, primary, cancellationToken: cancellation.token);

      expect(backend.lastSampleCancellationToken, same(cancellation.token));
    });

    test(
      'defers materialize prefill that would exceed the effective limit',
      () {
        final backend = _FakeSequences(
          snapshot: const KvSnapshot(
            contextSize: 8,
            sequences: [
              SequenceKvState(sequenceId: 2, positionMin: 0, positionMax: 2),
            ],
          ),
        );
        final subagent = _subagentLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [subagent],
        )..usageFor(subagent);

        final result = _materialize(scheduler, subagent, _context([1, 2]));

        expect(
          result,
          isA<SequenceMaterializeDeferred>().having(
            (result) => result.reason,
            'reason',
            SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
          ),
        );
      },
    );

    test('defers sample when effective limit is reached', () {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 2, positionMin: 0, positionMax: 3),
          ],
        ),
      );
      final subagent = _subagentLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [subagent],
      );
      _materialize(scheduler, subagent, _context([1, 2, 3, 4]));

      final result = _sample(scheduler, subagent);

      expect(
        result,
        isA<SequenceSampleDeferred>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerDeferralReason.effectiveLimitReached,
        ),
      );
      expect(backend.sampleBatchCalls, 0);
    });

    test('reports the effective limit with usage', () async {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 0, positionMax: 2),
          ],
        ),
      );
      final primary = _primaryLease();
      final allocator = _FakeAllocator(
        leases: [primary],
        effectiveLimits: {primary: 5},
      );
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: allocator,
      );

      final result = scheduler.usageFor(primary);

      expect(
        result,
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.effectiveLimit,
          'effectiveLimit',
          5,
        ),
      );
    });

    test('delegates effective limit lookups to the allocator', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: _FakeAllocator(
          leases: [primary],
          effectiveLimits: {primary: 5},
        ),
      );

      expect(scheduler.effectiveLimitFor(primary), 5);
    });

    test('usageFor returns cached usage after the first snapshot', () async {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 0, positionMax: 1),
          ],
        ),
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      expect(scheduler.usageFor(primary), isA<SequenceUsageSucceeded>());
      backend._snapshot = const KvSnapshot(
        contextSize: 8,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 0, positionMax: 5),
        ],
      );
      final result = scheduler.usageFor(primary);

      expect(backend.snapshotCalls, 1);
      expect(
        result,
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.tokenCount,
          'tokenCount',
          2,
        ),
      );
    });

    test('materialize prefills full prompt the first time', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1, 2, 3]));

      expect(
        result,
        isA<SequenceMaterializeSucceeded>()
            .having(
              (result) => result.materialization.strategy,
              'strategy',
              MaterializationStrategy.fullPrefill,
            )
            .having((result) => result.positionMax, 'positionMax', 2),
      );
      expect(backend.prefillBatchCalls, 1);
      expect(backend.clearCalls, 0);
      expect(
        backend.lastPrefillRequests.single.tokens,
        orderedEquals([1, 2, 3]),
      );
    });

    test('materialize advances long prompts one backend batch at a time', () {
      final backend = _FakeSequences(maxBatchTokens: 2);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      final context = _context([1, 2, 3, 4]);

      final first = _materialize(scheduler, primary, context);
      final second = _materialize(scheduler, primary, context);

      expect(
        first,
        isA<SequenceMaterializeAdvanced>()
            .having((result) => result.positionMax, 'positionMax', 1)
            .having(
              (result) => result.materialization.materializedTokenCount,
              'materializedTokenCount',
              2,
            ),
      );
      expect(
        second,
        isA<SequenceMaterializeSucceeded>()
            .having((result) => result.positionMax, 'positionMax', 3)
            .having(
              (result) => result.materialization.materializedTokenCount,
              'materializedTokenCount',
              4,
            ),
      );
      expect(backend.prefillBatchCalls, 2);
      expect(backend.lastPrefillRequests.single.retainLogits, isTrue);
    });

    test('materialize reuses an exact materialized prompt', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());

      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3]),
      );

      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.prefixReuse,
        ),
      );
      expect(backend.prefillBatchCalls, 1);
      expect(backend.clearCalls, 0);
    });

    test('materialize prefills only the suffix for an exact prefix', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());

      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 5]),
      );
      await _flush();

      expect(
        second,
        isA<SequenceMaterializeSucceeded>()
            .having(
              (result) => result.materialization.strategy,
              'strategy',
              MaterializationStrategy.prefixReuse,
            )
            .having((result) => result.positionMax, 'positionMax', 4),
      );
      expect(backend.prefillBatchCalls, 2);
      expect(backend.clearCalls, 0);
      expect(backend.lastPrefillRequests.single.tokens, orderedEquals([4, 5]));
    });

    test('sampled tokens extend materialized prompt for later reuse', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final materialized = _materialize(scheduler, primary, _context([1, 2]));
      expect(materialized, isA<SequenceMaterializeSucceeded>());

      final sample = _sample(scheduler, primary);
      expect(sample, isA<SequenceSampleSucceeded>());

      final next = _materialize(scheduler, primary, _context([1, 2, 1]));

      expect(
        next,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.prefixReuse,
        ),
      );
      expect(backend.prefillBatchCalls, 1);
      expect(backend.clearCalls, 0);
    });

    test('does not rebuild-loop an idle SWA sequence whose window has slid '
        '(livelock regression)', () async {
      final backend = _FakeSequences(maxBatchTokens: 16);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        nSwa: 2,
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // The sequence sits idle. On a sliding-window model llama.cpp keeps only
      // the window, so the snapshot floor legitimately climbs to length - nSwa
      // while the tail still reaches the end. Re-materializing the SAME prompt
      // must recognize the prefix as intact — not read the risen floor as a
      // lost cache and rebuild from zero, which is the loop we observed in the
      // wild.
      backend._snapshot = const KvSnapshot(
        contextSize: 8,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 3, positionMax: 4),
        ],
      );

      final again = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 5]),
      );

      expect(
        again,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.prefixReuse,
        ),
      );
      expect(backend.clearCalls, 0);
    });

    test('rebuilds when an SWA floor rises into the reused window', () async {
      final backend = _FakeSequences(maxBatchTokens: 16);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        nSwa: 2,
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // Floor at 4 with a two-token window: decoding at position 5 attends to
      // [3, 5), but position 3 has been evicted from the SWA sub-cache, so the
      // reused prefix can no longer be trusted.
      backend._snapshot = const KvSnapshot(
        contextSize: 8,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 4, positionMax: 5),
        ],
      );

      final grown = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 5, 6]),
      );

      expect(
        grown,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
      expect(backend.clearCalls, 1);
    });

    test('reuses when an SWA floor stays below the reused window', () async {
      final backend = _FakeSequences(maxBatchTokens: 16);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        nSwa: 2,
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // Floor at 1 sits below the window [3, 5) needed to decode at position 5,
      // so the reused prefix is still intact — a benign SWA floor, reuse
      // stands.
      backend._snapshot = const KvSnapshot(
        contextSize: 8,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 1, positionMax: 5),
        ],
      );

      final grown = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 5, 6]),
      );

      expect(
        grown,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.prefixReuse,
        ),
      );
      expect(backend.clearCalls, 0);
      expect(backend.lastPrefillRequests.single.tokens, orderedEquals([6]));
    });

    test('restores a checkpoint instead of rebuilding from zero on genuine SWA '
        'loss', () async {
      final backend = _FakeSequences(maxBatchTokens: 512)
        ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
      final primary = _primaryLease(fullLimit: 4096);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        nSwa: 2,
        contextCheckpointCount: 4,
        contextSize: 4096,
      );

      final base = List.generate(300, (index) => index + 1);
      expect(
        _materialize(scheduler, primary, _context(base)),
        isA<SequenceMaterializeSucceeded>(),
      );
      // A clean forward decode past the min-step captured a checkpoint anchor.
      expect(backend.readCheckpointCalls, greaterThan(0));

      // The window floor has risen into the prefix a divergent turn wants to
      // reuse: genuine loss. With an anchor available we restore it and
      // reprocess forward rather than rebuilding the whole prefix from zero.
      backend._snapshot = const KvSnapshot(
        contextSize: 4096,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 299, positionMax: 300),
        ],
      );

      final grown = _materialize(
        scheduler,
        primary,
        _context([...base, 301]),
      );

      expect(
        grown,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.checkpointRestore,
        ),
      );
      expect(backend.restoreCheckpointCalls, 1);
      expect(backend.clearCalls, 0);
    });

    group('checkpoint restore on genuine SWA loss', () {
      final base = List.generate(300, (index) => index + 1);
      final grown = [...base, ...List.generate(20, (index) => 1000 + index)];

      BatchingSequenceScheduler anchoredScheduler(
        _FakeSequences backend,
        Lease primary,
      ) {
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
          nSwa: 2,
          contextCheckpointCount: 4,
          contextSize: 4096,
        );
        expect(
          _materialize(scheduler, primary, _context(base)),
          isA<SequenceMaterializeSucceeded>(),
        );
        expect(
          _materialize(scheduler, primary, _context(grown)),
          isA<SequenceMaterializeSucceeded>(),
        );
        backend._snapshot = KvSnapshot(
          contextSize: 4096,
          sequences: [
            SequenceKvState(
              sequenceId: 1,
              positionMin: grown.length - 1,
              positionMax: grown.length,
            ),
          ],
        );
        return scheduler;
      }

      test('drops the cells past an older anchor before reprocessing', () {
        final backend = _FakeSequences(maxBatchTokens: 512)
          ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
        final primary = _primaryLease(fullLimit: 4096);
        final scheduler = anchoredScheduler(backend, primary);

        final restored = _materialize(
          scheduler,
          primary,
          _context([...grown, 9]),
        );

        expect(
          restored,
          isA<SequenceMaterializeSucceeded>().having(
            (result) => result.materialization.strategy,
            'strategy',
            MaterializationStrategy.checkpointRestore,
          ),
        );
        expect(backend.lastRemoveRangeStart, base.length);
        expect(backend.lastRemoveRangeEnd, grown.length);
      });

      test('rebuilds from zero when the anchor cannot be restored', () {
        final backend = _FakeSequences(maxBatchTokens: 512)
          ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
        final primary = _primaryLease(fullLimit: 4096);
        final scheduler = anchoredScheduler(backend, primary);
        backend.restoreCheckpointResult = const RestoreCheckpointFailed(
          message: 'restore failed',
          stackTrace: '',
        );

        final rebuilt = _materialize(
          scheduler,
          primary,
          _context([...grown, 9]),
        );

        expect(rebuilt, isNot(isA<SequenceMaterializeFailed>()));
        expect(backend.restoreCheckpointCalls, 1);
        expect(backend.clearCalls, greaterThan(0));
      });

      test('fails when the stale cells cannot be dropped', () {
        const failure = RemoveRangeFailed(message: 'rm failed', stackTrace: '');
        final backend = _FakeSequences(
          maxBatchTokens: 512,
          removeRangeResult: failure,
        )..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
        final primary = _primaryLease(fullLimit: 4096);
        final scheduler = anchoredScheduler(backend, primary);

        final result = _materialize(
          scheduler,
          primary,
          _context([...grown, 9]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>()
              .having(
                (failed) => failed.reason,
                'reason',
                SequenceSchedulerFailureReason.backendFailure,
              )
              .having(
                (failed) => failed.backendFailure,
                'backendFailure',
                isA<SequenceRemoveRangeBackendFailed>(),
              ),
        );
      });

      test('fails when the sampler cannot be rebuilt at the anchor', () {
        const failure = RebuildSamplerFailed(
          message: 'sampler failed',
          stackTrace: '',
        );
        final backend = _FakeSequences(
          maxBatchTokens: 512,
          rebuildSamplerResult: failure,
        )..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
        final primary = _primaryLease(fullLimit: 4096);
        final scheduler = anchoredScheduler(backend, primary);

        final result = _materialize(
          scheduler,
          primary,
          _context([...grown, 9]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (failed) => failed.backendFailure,
            'backendFailure',
            isA<SequenceRebuildSamplerBackendFailed>(),
          ),
        );
      });
    });

    test('recurrent model rebuilds from zero on a divergent tail rather than '
        'dropping it in place', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // Recurrent memory cannot partially rewind, so the divergent tail can
      // never be trimmed in place — the sequence rebuilds from zero instead
      // of issuing a partial removeRange the backend would reject.
      final second = _materialize(
        scheduler,
        primary,
        _context([1, 9, 3]),
      );

      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
      expect(backend.removeRangeCalls, 0);
      expect(backend.clearCalls, greaterThan(0));
    });

    test('recurrent model restores a full-state checkpoint on a divergent turn '
        'without a partial remove', () async {
      final backend = _FakeSequences(maxBatchTokens: 512)
        ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
      final primary = _primaryLease(fullLimit: 4096);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
        contextCheckpointCount: 4,
        contextSize: 4096,
      );

      // Build up two anchors across turns: one at 300, one at 600 (each a
      // clean forward decode past the 256-token min-step).
      final first = List.generate(300, (index) => index + 1);
      expect(
        _materialize(scheduler, primary, _context(first)),
        isA<SequenceMaterializeSucceeded>(),
      );
      final grown = List.generate(600, (index) => index + 1);
      expect(
        _materialize(scheduler, primary, _context(grown)),
        isA<SequenceMaterializeSucceeded>(),
      );
      // Full-state anchors were captured even though this is a recurrent
      // (nSwa == 0) model.
      expect(backend.readCheckpointCalls, greaterThan(0));

      // A turn diverges at position 400 — inside the materialized range. A
      // recurrent model cannot drop the tail, so it restores the nearest
      // anchor at/below the divergence (300) and reprocesses forward, never a
      // partial removeRange.
      final divergent = _materialize(
        scheduler,
        primary,
        _context([...grown.sublist(0, 400), 9999]),
      );

      expect(
        divergent,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.checkpointRestore,
        ),
      );
      expect(backend.restoreCheckpointCalls, 1);
      expect(backend.removeRangeCalls, 0);
    });

    test('recurrent model anchors sub-prompt slices so a divergence one token '
        'below the final length still restores', () async {
      // Regression: capturing only the final slice leaves the sole anchor at
      // the full prompt length, always >= the next turn's divergence, so a
      // divergent turn can never find a usable anchor and rebuilds from zero.
      final backend = _FakeSequences(maxBatchTokens: 256)
        ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
      final primary = _primaryLease(fullLimit: 4096);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
        contextCheckpointCount: 4,
        contextSize: 4096,
      );

      // A prompt long enough to slice into several batches.
      final base = List.generate(600, (index) => index + 1);
      var result = _materialize(scheduler, primary, _context(base));
      var guard = 0;
      while (result is SequenceMaterializeAdvanced && guard++ < 10) {
        result = _materialize(scheduler, primary, _context(base));
      }
      expect(result, isA<SequenceMaterializeSucceeded>());
      // Intermediate slices anchored below the final length, not just at 600.
      expect(backend.readCheckpointCalls, greaterThan(1));

      final divergent = _materialize(
        scheduler,
        primary,
        _context([...base.sublist(0, 599), 9999]),
      );

      expect(
        divergent,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.checkpointRestore,
        ),
      );
      expect(backend.removeRangeCalls, 0);
    });

    test('keeps only the newest anchors once the ring is full', () {
      final backend = _FakeSequences(maxBatchTokens: 256)
        ..readCheckpointBytes = Uint8List.fromList([1, 2, 3]);
      final primary = _primaryLease(fullLimit: 4096);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
        contextCheckpointCount: 1,
        contextSize: 4096,
      );
      final base = List.generate(600, (index) => index + 1);
      var result = _materialize(scheduler, primary, _context(base));
      var guard = 0;
      while (result is SequenceMaterializeAdvanced && guard++ < 10) {
        result = _materialize(scheduler, primary, _context(base));
      }
      expect(backend.readCheckpointCalls, greaterThan(1));

      final divergent = _materialize(
        scheduler,
        primary,
        _context([...base.sublist(0, 300), 9999]),
      );

      expect(
        divergent,
        isNot(
          isA<SequenceMaterializeSucceeded>().having(
            (result) => result.materialization.strategy,
            'strategy',
            MaterializationStrategy.checkpointRestore,
          ),
        ),
      );
      expect(backend.restoreCheckpointCalls, 0);
    });

    test('hybrid tail-only snapshot reports consumed positions, not the '
        'resident span', () async {
      // Hybrid (recurrent + attention) memories report
      // seq_pos_min ≈ seq_pos_max because the recurrent half only holds a
      // tail cell. Usage must reflect the consumed ceiling, not the ~1-wide
      // span between the reported bounds.
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 4, positionMax: 4),
          ],
        ),
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
      );

      final result = scheduler.usageFor(primary);

      expect(
        result,
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.tokenCount,
          'tokenCount',
          5,
        ),
      );
      expect(scheduler.cachedTokenCountFor(primary), 5);
    });

    test('re-materializing against a hybrid tail-only snapshot keeps the '
        'cached usage intact', () async {
      final backend = _FakeSequences(maxBatchTokens: 16);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary],
        isRecurrent: true,
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(scheduler.cachedTokenCountFor(primary), 5);

      // The refresh that runs while re-materializing the same prompt reads a
      // tail-only hybrid snapshot. It must not clobber the cached usage down
      // to the reported span (the regression that pinned the context gauge
      // near empty on hybrid models).
      backend._snapshot = const KvSnapshot(
        contextSize: 8,
        sequences: [
          SequenceKvState(sequenceId: 1, positionMin: 4, positionMax: 4),
        ],
      );

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(scheduler.cachedTokenCountFor(primary), 5);
      expect(backend.clearCalls, 0);
    });

    test('prefill invalidates skipped logits before sampling', () {
      final backend = _FakeSequences();
      final first = _primaryLease();
      final second = _primaryLease(id: 2);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [first, second],
      );

      expect(
        _materialize(scheduler, first, _context([1])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(
        _materialize(scheduler, second, _context([2])),
        isA<SequenceMaterializeSucceeded>(),
      );

      final result = _sample(scheduler, first);

      expect(
        result,
        isA<SequenceSampleDeferred>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );
      expect(backend.sampleBatchCalls, 0);
    });

    test('sample invalidates skipped logits before later sampling', () {
      final backend = _FakeSequences();
      final first = _primaryLease();
      final second = _primaryLease(id: 2);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [first, second],
      );

      final materialized = scheduler.stepBatch(
        materializes: [
          SequenceMaterializeRequest(lease: first, tokens: _context([1])),
          SequenceMaterializeRequest(lease: second, tokens: _context([2])),
        ],
      );

      expect(materialized, isA<SequenceStepResults>());
      expect(_sample(scheduler, first), isA<SequenceSampleSucceeded>());

      final result = _sample(scheduler, second);

      expect(
        result,
        isA<SequenceSampleDeferred>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );
      expect(backend.sampleBatchCalls, 1);

      expect(
        _materialize(scheduler, second, _context([2])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(_sample(scheduler, second), isA<SequenceSampleSucceeded>());
    });

    test('sample stop invalidates logits, so the last token is evaluated '
        'again', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      expect(
        _materialize(scheduler, primary, _context([1])),
        isA<SequenceMaterializeSucceeded>(),
      );
      backend.sampleResults = const [
        SampleSequenceStopped(
          sequenceId: 1,
          token: 2,
        ),
      ];

      expect(_sample(scheduler, primary), isA<SequenceSampleSucceeded>());

      final again = _materialize(scheduler, primary, _context([1]));

      expect(
        again,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.divergentReuse,
        ),
      );
      expect(backend.clearCalls, 0);
      expect(backend.lastRemoveRangeStart, 0);
      expect(backend.lastRemoveRangeEnd, 1);
      expect(backend.lastRebuildSamplerTokens, isEmpty);
    });

    test(
      'materialize drops the divergent tail and re-prefills from it',
      () async {
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        final first = _materialize(scheduler, primary, _context([1, 2, 3]));
        expect(first, isA<SequenceMaterializeSucceeded>());

        final second = _materialize(
          scheduler,
          primary,
          _context([1, 9, 3]),
        );

        expect(
          second,
          isA<SequenceMaterializeSucceeded>()
              .having(
                (result) => result.materialization.strategy,
                'strategy',
                MaterializationStrategy.divergentReuse,
              )
              .having((result) => result.positionMax, 'positionMax', 2)
              .having(
                (result) => result.materialization.materializedTokenCount,
                'materializedTokenCount',
                3,
              ),
        );
        // The common prefix [1] is retained; only the divergent tail is
        // dropped.
        expect(backend.clearCalls, 0);
        expect(backend.removeRangeCalls, 1);
        expect(backend.lastRemoveRangeStart, 1);
        expect(backend.lastRemoveRangeEnd, 3);
        expect(backend.rebuildSamplerCalls, 1);
        expect(
          backend.lastPrefillRequests.single.tokens,
          orderedEquals([9, 3]),
        );
      },
    );

    test(
      'reuses an exact prefix through a benign floor below the prefix',
      () async {
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );

        // A non-zero floor with the prefix still resident (ceiling covers it):
        // a benign interleaved-SWA window, not a genuine eviction, so the exact
        // re-materialize reuses rather than rebuilding.
        backend._snapshot = const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 1, positionMax: 4),
          ],
        );

        final reused = _materialize(
          scheduler,
          primary,
          _context([1, 2, 3]),
        );

        expect(
          reused,
          isA<SequenceMaterializeSucceeded>().having(
            (result) => result.materialization.strategy,
            'strategy',
            MaterializationStrategy.prefixReuse,
          ),
        );
        expect(backend.clearCalls, 0);
      },
    );

    test(
      'rebuilds an exact prefix when the resident ceiling falls short',
      () async {
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );

        // The backend genuinely lost cells: the ceiling no longer reaches the
        // materialized prefix, so the exact re-materialize must rebuild.
        backend._snapshot = const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 0, positionMax: 1),
          ],
        );

        final rebuilt = _materialize(
          scheduler,
          primary,
          _context([1, 2, 3]),
        );

        expect(
          rebuilt,
          isA<SequenceMaterializeSucceeded>().having(
            (result) => result.materialization.strategy,
            'strategy',
            MaterializationStrategy.rebuild,
          ),
        );
        expect(backend.clearCalls, 1);
        expect(
          backend.lastPrefillRequests.single.tokens,
          orderedEquals([1, 2, 3]),
        );
      },
    );

    test(
      'reuses a prefix through a benign floor left below the reused span',
      () async {
        final backend = _FakeSequences(maxBatchTokens: 16);
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );

        // A non-zero floor with the reused prefix still resident: an
        // interleaved- SWA window can raise the reported floor without evicting
        // the full-attention prefix, so reuse stays valid.
        backend._snapshot = const KvSnapshot(
          contextSize: 8,
          sequences: [
            SequenceKvState(sequenceId: 1, positionMin: 1, positionMax: 4),
          ],
        );

        final grown = _materialize(
          scheduler,
          primary,
          _context([1, 2, 3, 4, 5]),
        );

        expect(
          grown,
          isA<SequenceMaterializeSucceeded>().having(
            (result) => result.materialization.strategy,
            'strategy',
            MaterializationStrategy.prefixReuse,
          ),
        );
        expect(backend.clearCalls, 0);
        expect(backend.removeRangeCalls, 0);
        expect(
          backend.lastPrefillRequests.single.tokens,
          orderedEquals([4, 5]),
        );
      },
    );

    test('divergent reuse keeps a long shared prefix and only prefills the '
        'tail', () async {
      final backend = _FakeSequences(maxBatchTokens: 16);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5, 6])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // Shares [1, 2, 3, 4]; diverges at index 4.
      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 9, 8]),
      );

      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.divergentReuse,
        ),
      );
      expect(backend.lastRemoveRangeStart, 4);
      expect(backend.lastRemoveRangeEnd, 6);
      // Sampler is rebuilt with exactly the retained prefix.
      expect(backend.lastRebuildSamplerTokens, orderedEquals([1, 2, 3, 4]));
      // Only the divergent tail is re-prefilled.
      expect(backend.lastPrefillRequests.single.tokens, orderedEquals([9, 8]));
    });

    test('sampling works after a divergent reuse', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      expect(
        _materialize(scheduler, primary, _context([1, 2, 3])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(
        _materialize(scheduler, primary, _context([1, 9, 3])),
        isA<SequenceMaterializeSucceeded>(),
      );

      // The stale tail ticket was invalidated; the re-prefill must hand back a
      // fresh, usable logits ticket.
      expect(_sample(scheduler, primary), isA<SequenceSampleSucceeded>());
      expect(backend.sampleBatchCalls, 1);
    });

    test(
      'materialize preserves remove-range failure during divergent reuse',
      () async {
        const failure = RemoveRangeFailed(
          message: 'remove failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences(removeRangeResult: failure);
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );
        final result = _materialize(
          scheduler,
          primary,
          _context([1, 9, 3]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceRemoveRangeBackendFailed>().having(
              (failure) => failure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test(
      'materialize preserves rebuild sampler failure during divergent reuse',
      () async {
        const failure = RebuildSamplerFailed(
          message: 'rebuild failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences(rebuildSamplerResult: failure);
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );
        final result = _materialize(
          scheduler,
          primary,
          _context([1, 9, 3]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceRebuildSamplerBackendFailed>().having(
              (failure) => failure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test('materialize rebuilds when exact prompt usage is lost', () async {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(contextSize: 8, sequences: []),
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());

      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3]),
      );

      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
      expect(backend.clearCalls, 1);
      expect(backend.rebuildSamplerCalls, 1);
    });

    test('materialize rebuilds when prefix prompt usage is lost', () async {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(contextSize: 8, sequences: []),
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());

      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4]),
      );

      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
      expect(backend.clearCalls, 1);
      expect(
        backend.lastPrefillRequests.single.tokens,
        orderedEquals([1, 2, 3, 4]),
      );
    });

    test(
      'materialize fails when usage refresh fails for exact reuse',
      () async {
        const failure = KvSnapshotFailed(
          message: 'snapshot failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        final first = _materialize(scheduler, primary, _context([1, 2, 3]));
        expect(first, isA<SequenceMaterializeSucceeded>());
        backend._snapshotResult = failure;

        final second = _materialize(
          scheduler,
          primary,
          _context([1, 2, 3]),
        );

        expect(
          second,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceSnapshotBackendFailed>().having(
              (backendFailure) => backendFailure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test(
      'materialize fails when usage refresh fails for divergent reuse',
      () async {
        const failure = KvSnapshotFailed(
          message: 'snapshot failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        expect(
          _materialize(scheduler, primary, _context([1, 2, 3])),
          isA<SequenceMaterializeSucceeded>(),
        );
        backend._snapshotResult = failure;
        final result = _materialize(
          scheduler,
          primary,
          _context([1, 2, 9]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceSnapshotBackendFailed>().having(
              (backendFailure) => backendFailure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test('materialize reuses the prefix and re-evaluates the final token when '
        'the prompt is a pure truncation', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());

      final second = _materialize(scheduler, primary, _context([1, 2]));

      expect(
        second,
        isA<SequenceMaterializeSucceeded>()
            .having(
              (result) => result.materialization.strategy,
              'strategy',
              MaterializationStrategy.divergentReuse,
            )
            .having((result) => result.positionMax, 'positionMax', 1)
            .having(
              (result) => result.materialization.materializedTokenCount,
              'materializedTokenCount',
              2,
            ),
      );
      expect(backend.clearCalls, 0);
      expect(backend.removeRangeCalls, 1);
      expect(backend.lastRemoveRangeStart, 1);
      expect(backend.lastRemoveRangeEnd, 3);
      // The retained tail carried no logits, so the final token is
      // re-prefilled.
      expect(backend.lastPrefillRequests.single.tokens, orderedEquals([2]));
      expect(backend.lastPrefillRequests.single.retainLogits, isTrue);
    });

    test('materialize defers when prompt exceeds effective limit', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: _FakeAllocator(
          leases: [primary],
          effectiveLimits: {primary: 2},
        ),
      );

      final result = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3]),
      );

      expect(
        result,
        isA<SequenceMaterializeDeferred>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit,
        ),
      );
      expect(backend.prefillBatchCalls, 0);
    });

    test(
      'materialize defers suffix prefill when effective limit is reached',
      () async {
        final backend = _FakeSequences();
        final primary = _primaryLease();
        final effectiveLimits = {primary: 8};
        final scheduler = BatchingSequenceScheduler(
          sequences: backend,
          allocator: _FakeAllocator(
            leases: [primary],
            effectiveLimits: effectiveLimits,
          ),
        );

        final first = _materialize(scheduler, primary, _context([1, 2, 3]));
        expect(first, isA<SequenceMaterializeSucceeded>());
        effectiveLimits[primary] = 3;

        final result = _materialize(
          scheduler,
          primary,
          _context([1, 2, 3, 4]),
        );

        expect(
          result,
          isA<SequenceMaterializeDeferred>().having(
            (result) => result.reason,
            'reason',
            SequenceSchedulerDeferralReason.effectiveLimitReached,
          ),
        );
        expect(backend.prefillBatchCalls, 1);
      },
    );

    test('materialize suffix fails when retained logits are missing', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());
      backend.prefillResults = const [
        PrefillSequenceSucceeded(sequenceId: 1, positionMin: 3, positionMax: 3),
      ];

      final second = _materialize(scheduler, primary, _context([1, 2, 3, 4]));
      await _flush();

      expect(
        second,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingLogitsTicket,
        ),
      );
    });

    test('materialize suffix preserves step backend failure', () async {
      const failure = StepBatchFailed(
        message: 'step failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());
      backend.stepResult = failure;

      final second = _materialize(scheduler, primary, _context([1, 2, 3, 4]));
      await _flush();

      expect(
        second,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceStepBackendFailed>().having(
            (backendFailure) => backendFailure.result,
            'result',
            same(failure),
          ),
        ),
      );
    });

    test('materialize fails when retained logits are missing', () async {
      final backend = _FakeSequences(
        prefillResults: const [
          PrefillSequenceSucceeded(
            sequenceId: 1,
            positionMin: 0,
            positionMax: 0,
          ),
        ],
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingLogitsTicket,
        ),
      );
    });

    test(
      'materialize preserves clear backend failure during rebuild',
      () async {
        const failure = ClearSequenceFailed(
          message: 'clear failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences(clearResult: failure);
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        final first = _materialize(scheduler, primary, _context([1, 2, 3]));
        expect(first, isA<SequenceMaterializeSucceeded>());
        final result = _materialize(
          scheduler,
          primary,
          _context([9, 2, 3]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceClearBackendFailed>().having(
              (backendFailure) => backendFailure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test(
      'materialize preserves rebuild sampler backend failure during rebuild',
      () async {
        const failure = RebuildSamplerFailed(
          message: 'rebuild failed',
          stackTrace: 'stack',
        );
        final backend = _FakeSequences(rebuildSamplerResult: failure);
        final primary = _primaryLease();
        final scheduler = _sequenceScheduler(
          backend: backend,
          leases: [primary],
        );

        final first = _materialize(scheduler, primary, _context([1, 2, 3]));
        expect(first, isA<SequenceMaterializeSucceeded>());
        final result = _materialize(
          scheduler,
          primary,
          _context([9, 2, 3]),
        );

        expect(
          result,
          isA<SequenceMaterializeFailed>().having(
            (result) => result.backendFailure,
            'backendFailure',
            isA<SequenceRebuildSamplerBackendFailed>().having(
              (backendFailure) => backendFailure.result,
              'result',
              same(failure),
            ),
          ),
        );
      },
    );

    test('materialize preserves step backend failure during rebuild', () async {
      const failure = StepBatchFailed(
        message: 'step failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());
      backend.stepResult = failure;

      final result = _materialize(
        scheduler,
        primary,
        _context([9, 2, 3]),
      );

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceStepBackendFailed>().having(
            (backendFailure) => backendFailure.result,
            'result',
            same(failure),
          ),
        ),
      );
    });

    test('materialize reports missing batch result during rebuild', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());
      backend.prefillResults = const [];

      final result = _materialize(
        scheduler,
        primary,
        _context([9, 2, 3]),
      );

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingBatchResult,
        ),
      );
    });

    test('materialize reports missing logits during rebuild', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final first = _materialize(scheduler, primary, _context([1, 2, 3]));
      expect(first, isA<SequenceMaterializeSucceeded>());
      backend.prefillResults = const [
        PrefillSequenceSucceeded(sequenceId: 1, positionMin: 0, positionMax: 2),
      ];

      final result = _materialize(
        scheduler,
        primary,
        _context([9, 2, 3]),
      );

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingLogitsTicket,
        ),
      );
    });

    test('preserves materialize step backend failure result', () async {
      const failure = StepBatchFailed(
        message: 'step failed',
        stackTrace: 'stack',
        backendCode: 42,
      );
      final backend = _FakeSequences(stepResult: failure);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>()
            .having(
              (result) => result.reason,
              'reason',
              SequenceSchedulerFailureReason.backendFailure,
            )
            .having(
              (result) => result.backendFailure,
              'backendFailure',
              isA<SequenceStepBackendFailed>().having(
                (failure) => failure.result,
                'result',
                same(failure),
              ),
            ),
      );
    });

    test('preserves sample step backend failure result', () async {
      const failure = StepBatchFailed(
        message: 'step failed',
        stackTrace: 'stack',
        backendCode: 42,
      );
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      final materialized = _materialize(scheduler, primary, _context([1, 2]));
      expect(materialized, isA<SequenceMaterializeSucceeded>());
      backend.stepResult = failure;

      final future = _sample(scheduler, primary);
      final result = future;

      expect(
        result,
        isA<SequenceSampleFailed>()
            .having(
              (result) => result.reason,
              'reason',
              SequenceSchedulerFailureReason.backendFailure,
            )
            .having(
              (result) => result.backendFailure,
              'backendFailure',
              isA<SequenceStepBackendFailed>().having(
                (failure) => failure.result,
                'result',
                same(failure),
              ),
            ),
      );

      backend.stepResult = null;
      final rebuilt = _materialize(scheduler, primary, _context([1, 2]));
      expect(
        rebuilt,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
    });

    test('preserves snapshot backend failure result', () async {
      const failure = KvSnapshotFailed(
        message: 'snapshot failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences(snapshotResult: failure);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = scheduler.usageFor(primary);

      expect(
        result,
        isA<SequenceUsageFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceSnapshotBackendFailed>().having(
            (failure) => failure.result,
            'result',
            same(failure),
          ),
        ),
      );
    });

    test('rejects scheduler operations for unknown leases', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final unknown = _primaryLease(id: 3);
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      expect(
        scheduler.usageFor(unknown),
        isA<SequenceUsageFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.unknownLease,
        ),
      );
      expect(
        _sample(scheduler, unknown),
        isA<SequenceSampleFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.unknownLease,
        ),
      );
      expect(
        _materialize(scheduler, unknown, _context([1])),
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.unknownLease,
        ),
      );
      expect(backend.prefillBatchCalls, 0);
      expect(backend.sampleBatchCalls, 0);
    });

    test('defers sample without current logits', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _sample(scheduler, primary);

      expect(
        result,
        isA<SequenceSampleDeferred>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );
      expect(backend.sampleBatchCalls, 0);
    });

    test('dirty unknown lease fails through rebuild readiness', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final owned = <Lease>[primary];
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: _FakeAllocator(leases: owned),
      )..setSampling(primary, const EngineSampling(seed: 1));
      owned.clear();

      final result = _materialize(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.unknownLease,
        ),
      );
      expect(backend.clearCalls, 0);
    });

    test('preserves clear backend failure during rebuild', () async {
      const failure = ClearSequenceFailed(
        message: 'clear failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences(clearResult: failure);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _rebuild(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceClearBackendFailed>().having(
            (failure) => failure.result,
            'result',
            same(failure),
          ),
        ),
      );
    });

    test('preserves rebuild sampler backend failure during rebuild', () async {
      const failure = RebuildSamplerFailed(
        message: 'rebuild failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences(rebuildSamplerResult: failure);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _rebuild(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceRebuildSamplerBackendFailed>().having(
            (failure) => failure.result,
            'result',
            same(failure),
          ),
        ),
      );
    });

    test('reports missing materialize prefill batch result', () async {
      final backend = _FakeSequences(prefillResults: const []);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1]));

      expect(
        result,
        isA<SequenceMaterializeFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingBatchResult,
        ),
      );
    });

    test('reports missing sample batch result', () async {
      final backend = _FakeSequences(sampleResults: const []);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      _materialize(scheduler, primary, _context([1]));

      final future = _sample(scheduler, primary);
      final result = future;

      expect(
        result,
        isA<SequenceSampleFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.missingBatchResult,
        ),
      );
    });

    test('usage is zero when snapshot has no sequence state', () async {
      final backend = _FakeSequences(
        snapshot: const KvSnapshot(contextSize: 8, sequences: []),
      );
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = scheduler.usageFor(primary);

      expect(
        result,
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.tokenCount,
          'tokenCount',
          0,
        ),
      );
    });

    test(
      'usage cache is scoped to a lease, not a reusable sequence id',
      () async {
        final firstLease = _primaryLease();
        final secondLease = _primaryLease();
        final leases = [firstLease];
        final scheduler = BatchingSequenceScheduler(
          sequences: _FakeSequences(
            snapshot: const KvSnapshot(contextSize: 8, sequences: []),
          ),
          allocator: _FakeAllocator(leases: leases),
        );

        final prefill = _materialize(
          scheduler,
          firstLease,
          _context([1, 2, 3, 4]),
        );
        expect(prefill, isA<SequenceMaterializeSucceeded>());

        leases
          ..clear()
          ..add(secondLease);

        final result = scheduler.usageFor(secondLease);

        expect(
          result,
          isA<SequenceUsageSucceeded>().having(
            (result) => result.usage.tokenCount,
            'tokenCount',
            0,
          ),
        );
      },
    );

    test('usage cache tracks consumed positions when the resident floor is '
        'above zero', () {
      final primary = _primaryLease(fullLimit: 32);
      final backend = _FakeSequences(
        maxBatchTokens: 8,
        initialPositionMins: {primary.sequence.id: 10},
        initialPositionMaxes: {primary.sequence.id: 14},
      );
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: _FakeAllocator(
          leases: [primary],
          effectiveLimits: {primary: 32},
        ),
      );

      // A floor above zero (evicted or folded front) does not shrink the
      // consumed budget: positions [0, 14] are spent regardless of how many
      // cells below the floor remain resident.
      expect(
        scheduler.usageFor(primary),
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.tokenCount,
          'tokenCount',
          15,
        ),
      );
      expect(
        _materialize(scheduler, primary, _context([1, 2, 3, 4, 5, 6])),
        isA<SequenceMaterializeSucceeded>(),
      );
      expect(_sample(scheduler, primary), isA<SequenceSampleSucceeded>());

      expect(
        scheduler.usageFor(primary),
        isA<SequenceUsageSucceeded>().having(
          (result) => result.usage.tokenCount,
          'tokenCount',
          22,
        ),
      );
      expect(backend.snapshotCalls, 1);
    });

    test('sets sampling for an owned lease', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      const sampling = EngineSampling(seed: 7, temperature: 0.2);

      final result = scheduler.setSampling(primary, sampling);

      expect(result, isA<SequenceSetSamplingSucceeded>());
      expect(backend.setSamplingCalls, 1);
      expect(backend.lastSetSamplingSequenceId, primary.sequence.id);
      expect(backend.lastSampling, sampling);
    });

    test('set sampling replays the materialized prefix into the new sampler '
        'and keeps the cache', () async {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      expect(
        _materialize(scheduler, primary, _context([1, 2])),
        isA<SequenceMaterializeSucceeded>(),
      );

      expect(
        scheduler.setSampling(primary, const EngineSampling(seed: 7)),
        isA<SequenceSetSamplingSucceeded>(),
      );
      expect(backend.lastRebuildSamplerTokens, orderedEquals([1, 2]));
      final reused = _materialize(scheduler, primary, _context([1, 2, 3]));

      expect(
        reused,
        isA<SequenceMaterializeSucceeded>()
            .having(
              (result) => result.materialization.strategy,
              'strategy',
              MaterializationStrategy.prefixReuse,
            )
            .having(
              (result) => result.materialization.reusedTokenCount,
              'reusedTokenCount',
              2,
            ),
      );
      expect(backend.clearCalls, 0);
    });

    test('set sampling marks the lease dirty when the replay fails', () async {
      const failure = RebuildSamplerFailed(
        message: 'rebuild failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      expect(
        _materialize(scheduler, primary, _context([1, 2])),
        isA<SequenceMaterializeSucceeded>(),
      );
      backend.rebuildSamplerResult = failure;

      expect(
        scheduler.setSampling(primary, const EngineSampling(seed: 7)),
        isA<SequenceSetSamplingFailed>().having(
          (result) => result.backendFailure,
          'backendFailure',
          isA<SequenceRebuildSamplerBackendFailed>().having(
            (failed) => failed.result,
            'result',
            same(failure),
          ),
        ),
      );
      backend.rebuildSamplerResult = const RebuildSamplerSucceeded();
      expect(
        _materialize(scheduler, primary, _context([1, 2])),
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.rebuild,
        ),
      );
    });

    test('set sampling fails for unknown leases', () async {
      final backend = _FakeSequences();
      final scheduler = _sequenceScheduler(backend: backend, leases: const []);

      final result = scheduler.setSampling(
        _primaryLease(),
        const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<SequenceSetSamplingFailed>().having(
          (result) => result.reason,
          'reason',
          SequenceSchedulerFailureReason.unknownLease,
        ),
      );
      expect(backend.setSamplingCalls, 0);
    });

    test('preserves set sampling backend failure result', () async {
      const failure = SetSamplingFailed(
        message: 'sampling failed',
        stackTrace: 'stack',
      );
      final backend = _FakeSequences(setSamplingResult: failure);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = scheduler.setSampling(
        primary,
        const EngineSampling(seed: 1),
      );

      expect(
        result,
        isA<SequenceSetSamplingFailed>()
            .having(
              (result) => result.reason,
              'reason',
              SequenceSchedulerFailureReason.backendFailure,
            )
            .having(
              (result) => result.backendFailure,
              'backendFailure',
              isA<SequenceSetSamplingBackendFailed>().having(
                (failure) => failure.result,
                'result',
                same(failure),
              ),
            ),
      );
    });
  });

  group('release', () {
    test('releases the lease and forgets what the ledger held', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final allocator = _ReleasingAllocator(leases: [primary]);
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: allocator,
      );
      _materialize(scheduler, primary, _context([1, 2]));
      expect(scheduler.cachedTokenCountFor(primary), 2);

      final result = scheduler.release(primary);

      expect(result, isA<ReleaseLeaseSucceeded>());
      expect(allocator.released, [same(primary)]);
      allocator.readmit(primary);
      expect(scheduler.cachedTokenCountFor(primary), isNull);
      backend.clearPositions();
      final rematerialized = _materialize(scheduler, primary, _context([1, 2]));
      expect(
        rematerialized,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.strategy,
          'strategy',
          MaterializationStrategy.fullPrefill,
        ),
      );
    });

    test('keeps the ledger when the allocator refuses the release', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final allocator = _ReleasingAllocator(
        leases: [primary],
        result: const ReleaseLeaseFailed(
          reason: ReleaseLeaseFailureReason.schedulerFailure,
        ),
      );
      final scheduler = BatchingSequenceScheduler(
        sequences: backend,
        allocator: allocator,
      );
      _materialize(scheduler, primary, _context([1, 2]));

      final result = scheduler.release(primary);

      expect(result, isA<ReleaseLeaseFailed>());
      expect(scheduler.cachedTokenCountFor(primary), 2);
    });
  });

  group('reused tokens', () {
    test('a first materialization reuses nothing', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);

      final result = _materialize(scheduler, primary, _context([1, 2]));

      expect(
        result,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.reusedTokenCount,
          'reusedTokenCount',
          0,
        ),
      );
    });

    test('a follow-up turn reuses the shared prefix', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      _materialize(scheduler, primary, _context([1, 2]));

      final result = _materialize(scheduler, primary, _context([1, 2, 3]));

      expect(
        result,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.reusedTokenCount,
          'reusedTokenCount',
          2,
        ),
      );
    });

    test('an identical prompt reuses every token', () {
      final backend = _FakeSequences();
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      _materialize(scheduler, primary, _context([1, 2]));

      final result = _materialize(scheduler, primary, _context([1, 2]));

      expect(
        result,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.reusedTokenCount,
          'reusedTokenCount',
          2,
        ),
      );
    });

    test('later slices keep the reuse of the first', () {
      final backend = _FakeSequences(maxBatchTokens: 2);
      final primary = _primaryLease();
      final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
      _materialize(scheduler, primary, _context([1, 2]));

      final first = _materialize(scheduler, primary, _context([1, 2, 3, 4, 5]));
      final second = _materialize(
        scheduler,
        primary,
        _context([1, 2, 3, 4, 5]),
      );

      expect(
        first,
        isA<SequenceMaterializeAdvanced>().having(
          (result) => result.materialization.reusedTokenCount,
          'reusedTokenCount',
          2,
        ),
      );
      expect(
        second,
        isA<SequenceMaterializeSucceeded>().having(
          (result) => result.materialization.reusedTokenCount,
          'reusedTokenCount',
          2,
        ),
      );
    });
  });

  test('a step cancelled mid-flight fails as cancelled and dirties', () {
    final backend = _FakeSequences();
    final primary = _primaryLease();
    final scheduler = _sequenceScheduler(backend: backend, leases: [primary]);
    final cancellation = IsolateCancellationTokenSource()..cancel();

    final result = _materialize(
      scheduler,
      primary,
      _context([1, 2]),
      cancellationToken: cancellation.token,
    );

    expect(
      result,
      isA<SequenceMaterializeFailed>().having(
        (result) => result.reason,
        'reason',
        SequenceSchedulerFailureReason.cancelled,
      ),
    );
  });

  test('usageFor refuses an unknown lease', () {
    final scheduler = _sequenceScheduler(
      backend: _FakeSequences(),
      leases: const [],
    );

    expect(
      scheduler.usageFor(_primaryLease()),
      isA<SequenceUsageFailed>().having(
        (result) => result.reason,
        'reason',
        SequenceSchedulerFailureReason.unknownLease,
      ),
    );
  });

  group('stepBatch', () {
    test('samples and prefills in a single backend step', () {
      final backend = _FakeSequences();
      final running = _subagentLease(id: 1, claimSize: 16);
      final fresh = _subagentLease(claimSize: 16);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [running, fresh],
      );
      _materialize(scheduler, running, _context([1, 2]));
      backend.stepBatchCalls = 0;

      final result = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: running)],
        materializes: [
          SequenceMaterializeRequest(
            lease: fresh,
            tokens: _context([5, 6, 7, 8]),
          ),
        ],
      );

      expect(backend.stepBatchCalls, 1);
      expect(backend.lastStepRequest!.samples, hasLength(1));
      expect(backend.lastStepRequest!.prefills, hasLength(1));
      expect(backend.lastStepRequest!.prefills.single.tokens, hasLength(3));
      expect(result.samples[running], isA<SequenceSampleSucceeded>());
      expect(result.materializes[fresh], isA<SequenceMaterializeAdvanced>());
    });

    test('uses full backend room for solo prefill by default', () {
      final backend = _FakeSequences(maxBatchTokens: 512);
      final lease = _subagentLease(id: 1, claimSize: 512);
      final scheduler = _sequenceScheduler(backend: backend, leases: [lease]);

      final result = _materialize(
        scheduler,
        lease,
        _context(List<int>.generate(100, (index) => index + 1)),
      );

      expect(result, isA<SequenceMaterializeSucceeded>());
      expect(backend.lastPrefillRequests.single.tokens, hasLength(100));
    });

    test('weights concurrent prefill by each lease effective limit', () {
      final backend = _FakeSequences(maxBatchTokens: 12);
      final primary = _primaryLease(fullLimit: 100);
      final first = _subagentLease(claimSize: 10);
      final second = _subagentLease(id: 3, claimSize: 10);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [primary, first, second],
        effectiveLimits: {primary: 100, first: 10, second: 10},
      );

      final result = scheduler.stepBatch(
        materializes: [
          SequenceMaterializeRequest(
            lease: primary,
            tokens: _context(
              List<int>.generate(100, (index) => index),
            ),
          ),
          SequenceMaterializeRequest(
            lease: first,
            tokens: _context(
              List<int>.generate(10, (index) => index + 100),
            ),
          ),
          SequenceMaterializeRequest(
            lease: second,
            tokens: _context(
              List<int>.generate(10, (index) => index + 200),
            ),
          ),
        ],
      );

      expect(
        result.materializes.values,
        everyElement(isA<SequenceMaterializeAdvanced>()),
      );
      expect(
        backend.lastPrefillRequests.map((request) => request.tokens.length),
        [10, 1, 1],
      );
    });

    test('maps decode slot exhaustion with prefill to backpressure', () {
      const failure = StepBatchFailed(
        message: 'llama_decode failed with code 1.',
        stackTrace: '',
        backendCode: decodeKvSlotUnavailableBackendCode,
      );
      final backend = _FakeSequences(maxBatchTokens: 512);
      final running = _subagentLease(id: 1, claimSize: 512);
      final fresh = _subagentLease(claimSize: 512);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [running, fresh],
      );
      _materialize(scheduler, running, _context([1]));
      backend
        ..stepResult = failure
        ..stepBatchCalls = 0;

      final rejected = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: running)],
        materializes: [
          SequenceMaterializeRequest(
            lease: fresh,
            tokens: _context(
              List<int>.generate(300, (index) => index),
            ),
          ),
        ],
      );

      expect(backend.lastPrefillRequests.single.tokens, hasLength(300));
      expect(
        rejected.samples[running],
        isA<SequenceSampleDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.backendBackpressure,
        ),
      );
      expect(
        rejected.materializes[fresh],
        isA<SequenceMaterializeDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.backendBackpressure,
        ),
      );

      backend.stepResult = null;
      final retried = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: running)],
        materializes: [
          SequenceMaterializeRequest(
            lease: fresh,
            tokens: _context(
              List<int>.generate(300, (index) => index),
            ),
          ),
        ],
      );

      expect(backend.lastPrefillRequests.single.tokens, hasLength(150));
      expect(retried.samples[running], isA<SequenceSampleSucceeded>());
      expect(retried.materializes[fresh], isA<SequenceMaterializeAdvanced>());
    });

    test('maps solo prefill slot exhaustion to a smaller retry', () {
      const failure = StepBatchFailed(
        message: 'llama_decode failed with code 1.',
        stackTrace: '',
        backendCode: decodeKvSlotUnavailableBackendCode,
      );
      final backend = _FakeSequences(maxBatchTokens: 512)..stepResult = failure;
      final fresh = _subagentLease(claimSize: 512);
      final scheduler = _sequenceScheduler(backend: backend, leases: [fresh]);
      final request = SequenceMaterializeRequest(
        lease: fresh,
        tokens: _context(List<int>.generate(300, (index) => index)),
      );

      final rejected = scheduler.stepBatch(materializes: [request]);

      expect(
        rejected.materializes[fresh],
        isA<SequenceMaterializeDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.backendBackpressure,
        ),
      );

      backend.stepResult = null;
      scheduler.stepBatch(materializes: [request]);

      expect(
        backend.lastPrefillRequests.single.tokens.length,
        lessThan(300),
      );
    });

    test('maps multi-sample slot exhaustion to backpressure', () {
      const failure = StepBatchFailed(
        message: 'llama_decode failed with code 1.',
        stackTrace: '',
        backendCode: decodeKvSlotUnavailableBackendCode,
      );
      final backend = _FakeSequences();
      final first = _subagentLease(id: 1, claimSize: 16);
      final second = _subagentLease(claimSize: 16);
      final third = _subagentLease(id: 3, claimSize: 16);
      final scheduler =
          _sequenceScheduler(
            backend: backend,
            leases: [first, second, third],
          )..stepBatch(
            materializes: [
              SequenceMaterializeRequest(lease: first, tokens: _context([1])),
              SequenceMaterializeRequest(lease: second, tokens: _context([2])),
              SequenceMaterializeRequest(lease: third, tokens: _context([3])),
            ],
          );
      backend.stepResult = failure;

      final rejected = scheduler.stepBatch(
        samples: [
          SequenceSampleRequest(lease: first),
          SequenceSampleRequest(lease: second),
          SequenceSampleRequest(lease: third),
        ],
      );

      expect(
        rejected.samples.values,
        everyElement(
          isA<SequenceSampleDeferred>().having(
            (deferred) => deferred.reason,
            'reason',
            SequenceSchedulerDeferralReason.backendBackpressure,
          ),
        ),
      );
      expect(backend.lastStepRequest!.samples, hasLength(3));

      backend.stepResult = null;
      final retried = scheduler.stepBatch(
        samples: [
          SequenceSampleRequest(lease: first),
          SequenceSampleRequest(lease: second),
          SequenceSampleRequest(lease: third),
        ],
      );

      expect(backend.lastStepRequest!.samples, hasLength(1));
      expect(retried.samples[first], isA<SequenceSampleSucceeded>());
      expect(
        retried.samples[second],
        isA<SequenceSampleDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.backendBackpressure,
        ),
      );
      expect(
        retried.samples[third],
        isA<SequenceSampleDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.backendBackpressure,
        ),
      );
    });

    test('maps single-sample slot exhaustion to effective limit', () {
      const failure = StepBatchFailed(
        message: 'llama_decode failed with code 1.',
        stackTrace: '',
        backendCode: decodeKvSlotUnavailableBackendCode,
      );
      final backend = _FakeSequences();
      final lease = _subagentLease(id: 1, claimSize: 16);
      final scheduler = _sequenceScheduler(backend: backend, leases: [lease]);
      _materialize(scheduler, lease, _context([1]));
      backend.stepResult = failure;

      final result = _sample(scheduler, lease);

      expect(
        result,
        isA<SequenceSampleDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.effectiveLimitReached,
        ),
      );
    });

    test('defers prefill when sample reservation exhausts batch capacity', () {
      final backend = _FakeSequences(maxBatchTokens: 1);
      final running = _subagentLease(id: 1, claimSize: 16);
      final fresh = _subagentLease(claimSize: 16);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [running, fresh],
      );
      expect(
        _materialize(scheduler, running, _context([1])),
        isA<SequenceMaterializeSucceeded>(),
      );
      backend.stepBatchCalls = 0;

      final result = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: running)],
        materializes: [
          SequenceMaterializeRequest(
            lease: fresh,
            tokens: _context([5]),
          ),
        ],
      );

      expect(backend.stepBatchCalls, 1);
      expect(backend.lastStepRequest!.samples, hasLength(1));
      expect(backend.lastStepRequest!.prefills, isEmpty);
      expect(
        result.materializes[fresh],
        isA<SequenceMaterializeDeferred>().having(
          (deferred) => deferred.reason,
          'reason',
          SequenceSchedulerDeferralReason.batchCapacityExhausted,
        ),
      );
    });

    test('reports not-ready samples without a backend step', () {
      final backend = _FakeSequences();
      final lease = _subagentLease(id: 1, claimSize: 16);
      final scheduler = _sequenceScheduler(backend: backend, leases: [lease]);

      final result = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: lease)],
      );

      expect(backend.stepBatchCalls, 0);
      expect(
        result.samples[lease],
        isA<SequenceSampleDeferred>().having(
          (failed) => failed.reason,
          'reason',
          SequenceSchedulerDeferralReason.logitsUnavailable,
        ),
      );
    });

    test('marks participants dirty and fails when the step fails', () {
      final backend = _FakeSequences();
      final running = _subagentLease(id: 1, claimSize: 16);
      final fresh = _subagentLease(claimSize: 16);
      final scheduler = _sequenceScheduler(
        backend: backend,
        leases: [running, fresh],
      );
      _materialize(scheduler, running, _context([1, 2]));
      backend.stepResult = const StepBatchFailed(
        message: 'step failed',
        stackTrace: '',
      );

      final result = scheduler.stepBatch(
        samples: [SequenceSampleRequest(lease: running)],
        materializes: [
          SequenceMaterializeRequest(
            lease: fresh,
            tokens: _context([5]),
          ),
        ],
      );

      expect(
        result.samples[running],
        isA<SequenceSampleFailed>().having(
          (failed) => failed.backendFailure,
          'backendFailure',
          isA<SequenceStepBackendFailed>(),
        ),
      );
      expect(
        result.materializes[fresh],
        isA<SequenceMaterializeFailed>().having(
          (failed) => failed.backendFailure,
          'backendFailure',
          isA<SequenceStepBackendFailed>(),
        ),
      );
    });
  });
}

BatchingSequenceScheduler _sequenceScheduler({
  required _FakeSequences backend,
  required List<Lease> leases,
  AdaptiveStepBudget? stepBudget,
  Map<Lease, int> effectiveLimits = const {},
  int nSwa = 0,
  bool isRecurrent = false,
  int contextCheckpointCount = 0,
  int contextSize = 8,
}) {
  return BatchingSequenceScheduler(
    sequences: backend,
    allocator: _FakeAllocator(
      leases: leases,
      effectiveLimits: effectiveLimits,
      nSwa: nSwa,
      isRecurrent: isRecurrent,
      contextSize: contextSize,
    ),
    stepBudget: stepBudget,
    contextCheckpointCount: contextCheckpointCount,
  );
}

SequenceMaterializeResult _materialize(
  BatchingSequenceScheduler scheduler,
  Lease lease,
  TokenizedString tokens, {
  IsolateCancellationToken? cancellationToken,
}) {
  final batch = scheduler.stepBatch(
    materializes: [SequenceMaterializeRequest(lease: lease, tokens: tokens)],
    cancellationToken: cancellationToken,
  );
  return batch.materializes[lease] ??
      const SequenceMaterializeFailed(
        reason: SequenceSchedulerFailureReason.missingBatchResult,
      );
}

SequenceSampleResult _sample(
  BatchingSequenceScheduler scheduler,
  Lease lease, {
  IsolateCancellationToken? cancellationToken,
}) {
  final batch = scheduler.stepBatch(
    samples: [SequenceSampleRequest(lease: lease)],
    cancellationToken: cancellationToken,
  );
  return batch.samples[lease] ??
      const SequenceSampleFailed(
        reason: SequenceSchedulerFailureReason.missingBatchResult,
      );
}

SequenceMaterializeResult _rebuild(
  BatchingSequenceScheduler scheduler,
  Lease lease,
  TokenizedString tokens,
) {
  scheduler.setSampling(lease, const EngineSampling(seed: 1));
  return _materialize(scheduler, lease, tokens);
}

PrimaryLease _primaryLease({int id = 1, int fullLimit = 8}) {
  return PrimaryLease(
    sequence: Sequence(id: id),
    fullLimit: fullLimit,
  );
}

SubagentLease _subagentLease({int id = 2, int claimSize = 4}) {
  return SubagentLease(
    sequence: Sequence(id: id),
    claimSize: claimSize,
  );
}

TokenizedString _tokens(List<int> tokens) => Int64List.fromList(tokens);

TokenizedString _context(List<int> tokens) => _tokens(tokens);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _FakeAllocator implements Allocator {
  _FakeAllocator({
    required List<Lease> leases,
    Map<Lease, int> effectiveLimits = const {},
    int nSwa = 0,
    bool isRecurrent = false,
    int contextSize = 8,
  }) : _leases = leases,
       _effectiveLimits = effectiveLimits,
       _nSwa = nSwa,
       _isRecurrent = isRecurrent,
       _contextSize = contextSize;

  final List<Lease> _leases;
  final Map<Lease, int> _effectiveLimits;
  final int _nSwa;
  final bool _isRecurrent;
  final int _contextSize;
  @override
  int get activeSubagentClaims => _leases.whereType<SubagentLease>().fold(
    0,
    (total, lease) => total + lease.claimSize,
  );

  @override
  int get contextSize => _contextSize;

  @override
  int get maxSequences => 4;

  @override
  int get nSwa => _nSwa;

  @override
  bool get isRecurrent => _isRecurrent;

  @override
  int effectiveLimitFor(Lease lease) {
    return _effectiveLimits[lease] ??
        switch (lease) {
          PrimaryLease() => contextSize - activeSubagentClaims,
          SubagentLease(:final claimSize) => claimSize,
        };
  }

  @override
  bool owns(Lease lease) => _leases.any((owned) => identical(owned, lease));

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

final class _FakeSequences implements Sequences {
  _FakeSequences({
    this.maxBatchTokens = 4,
    KvSnapshot? snapshot,
    KvSnapshotResult? snapshotResult,
    Map<SequenceId, int> initialPositionMins = const {},
    Map<SequenceId, int> initialPositionMaxes = const {},
    this.prefillResults,
    this.sampleResults,
    this.stepResult,
    ClearSequenceResult clearResult = const ClearSequenceSucceeded(),
    RemoveRangeResult removeRangeResult = const RemoveRangeSucceeded(),
    this.rebuildSamplerResult = const RebuildSamplerSucceeded(),
    SetSamplingResult setSamplingResult = const SetSamplingSucceeded(),
  }) : _snapshot = snapshot,
       _snapshotResult = snapshotResult,
       _clearResult = clearResult,
       _removeRangeResult = removeRangeResult,
       _setSamplingResult = setSamplingResult {
    _positionMinBySequence.addAll(initialPositionMins);
    _positionMaxBySequence.addAll(initialPositionMaxes);
  }

  KvSnapshot? _snapshot;
  KvSnapshotResult? _snapshotResult;
  List<PrefillSequenceResult>? prefillResults;
  List<SampleSequenceResult>? sampleResults;
  final ClearSequenceResult _clearResult;
  final RemoveRangeResult _removeRangeResult;
  RebuildSamplerResult rebuildSamplerResult;
  final SetSamplingResult _setSamplingResult;
  final _positionMinBySequence = <SequenceId, int>{};
  final _positionMaxBySequence = <SequenceId, int>{};
  int prefillBatchCalls = 0;
  int sampleBatchCalls = 0;
  int stepBatchCalls = 0;
  StepBatchResult? stepResult;
  StepRequest? lastStepRequest;
  IsolateCancellationToken? lastStepCancellationToken;
  int clearCalls = 0;
  int removeRangeCalls = 0;
  int? lastRemoveRangeStart;
  int? lastRemoveRangeEnd;
  int rebuildSamplerCalls = 0;
  TokenizedString? lastRebuildSamplerTokens;
  int setSamplingCalls = 0;
  int snapshotCalls = 0;
  SequenceId? lastSetSamplingSequenceId;
  EngineSampling? lastSampling;
  List<PrefillRequest> lastPrefillRequests = const [];
  List<SampleRequest> lastSampleRequests = const [];
  IsolateCancellationToken? lastPrefillCancellationToken;
  IsolateCancellationToken? lastSampleCancellationToken;
  void Function()? onClear;
  void Function()? onPrefillBatch;

  @override
  int get maxSequences => 4;

  @override
  final int maxBatchTokens;

  @override
  RequestSequenceResult acquire(SequenceRequest request) {
    throw UnimplementedError();
  }

  @override
  ClearSequenceResult clear(SequenceId id) {
    clearCalls += 1;
    onClear?.call();
    if (_clearResult is ClearSequenceSucceeded) {
      _positionMinBySequence.remove(id);
      _positionMaxBySequence.remove(id);
    }
    return _clearResult;
  }

  @override
  StepBatchResult stepBatch(
    StepRequest request, {
    IsolateCancellationToken? cancellationToken,
  }) {
    stepBatchCalls += 1;
    lastStepRequest = request;
    lastStepCancellationToken = cancellationToken;
    if (request.prefills.isNotEmpty) {
      prefillBatchCalls += 1;
      lastPrefillRequests = request.prefills;
      lastPrefillCancellationToken = cancellationToken;
      onPrefillBatch?.call();
    }
    if (request.samples.isNotEmpty) {
      sampleBatchCalls += 1;
      lastSampleRequests = request.samples;
      lastSampleCancellationToken = cancellationToken;
    }
    final override = stepResult;
    if (override != null) return override;
    if (cancellationToken?.isCancellationRequested ?? false) {
      return const StepBatchFailed(message: 'cancelled', stackTrace: '');
    }
    return StepBatchSucceeded(
      samples:
          sampleResults ??
          [for (final sample in request.samples) _sampleSequence(sample)],
      prefills:
          prefillResults ??
          [for (final prefill in request.prefills) _prefillSequence(prefill)],
    );
  }

  @override
  KvSnapshotResult kvSnapshot() {
    snapshotCalls += 1;
    return _snapshotResult ??
        KvSnapshotSucceeded(_snapshot ?? _snapshotState());
  }

  KvSnapshot _snapshotState() {
    return KvSnapshot(
      contextSize: 8,
      sequences: [
        for (final entry in _positionMaxBySequence.entries)
          if (entry.value >= 0)
            SequenceKvState(
              sequenceId: entry.key,
              positionMin: _positionMinBySequence[entry.key] ?? 0,
              positionMax: entry.value,
            ),
      ],
    );
  }

  PrefillSequenceResult _prefillSequence(PrefillRequest request) {
    final previous = _positionMaxBySequence[request.sequenceId] ?? -1;
    final positionMin = previous + 1;
    final positionMax = previous + request.tokens.length;
    _positionMinBySequence.putIfAbsent(request.sequenceId, () => positionMin);
    _positionMaxBySequence[request.sequenceId] = positionMax;
    if (!request.retainLogits) {
      return PrefillSequenceSucceeded(
        sequenceId: request.sequenceId,
        positionMin: positionMin,
        positionMax: positionMax,
      );
    }
    return PrefillSequenceWithLogitsSucceeded(
      sequenceId: request.sequenceId,
      positionMin: positionMin,
      positionMax: positionMax,
      logitsTicket: LogitsTicket(
        sequenceId: request.sequenceId,
        position: positionMax,
        batchIndex: 0,
        generation: positionMax,
      ),
    );
  }

  @override
  RebuildSamplerResult rebuildSampler(
    SequenceId id,
    TokenizedString acceptedTokens,
  ) {
    rebuildSamplerCalls += 1;
    lastRebuildSamplerTokens = acceptedTokens;
    return rebuildSamplerResult;
  }

  @override
  ReleaseSequenceResult release(SequenceId id) {
    throw UnimplementedError();
  }

  @override
  RemoveRangeResult removeRange(
    SequenceId id, {
    required int start,
    required int end,
  }) {
    removeRangeCalls += 1;
    lastRemoveRangeStart = start;
    lastRemoveRangeEnd = end;
    if (_removeRangeResult is RemoveRangeSucceeded) {
      final current = _positionMaxBySequence[id] ?? -1;
      if (current >= start) {
        _positionMaxBySequence[id] = start - 1;
      }
      final min = _positionMinBySequence[id];
      if (min != null && end <= min) {
        _positionMinBySequence[id] = min - (end - start);
      }
    }
    return _removeRangeResult;
  }

  SampleSequenceResult _sampleSequence(SampleRequest request) {
    final position = request.logitsTicket.position + 1;
    _positionMinBySequence.putIfAbsent(
      request.logitsTicket.sequenceId,
      () => position,
    );
    _positionMaxBySequence[request.logitsTicket.sequenceId] = position;
    return SampleSequenceToken(
      sequenceId: request.logitsTicket.sequenceId,
      token: 1,
      position: position,
      nextLogitsTicket: LogitsTicket(
        sequenceId: request.logitsTicket.sequenceId,
        position: position,
        batchIndex: request.logitsTicket.batchIndex,
        generation: request.logitsTicket.generation + 1,
      ),
    );
  }

  @override
  SetSamplingResult setSampling(SequenceId id, EngineSampling sampling) {
    setSamplingCalls += 1;
    lastSetSamplingSequenceId = id;
    lastSampling = sampling;
    return _setSamplingResult;
  }

  void clearPositions() {
    _positionMinBySequence.clear();
    _positionMaxBySequence.clear();
  }

  Uint8List readCheckpointBytes = Uint8List(0);
  RestoreCheckpointResult restoreCheckpointResult =
      const RestoreCheckpointSucceeded();
  int readCheckpointCalls = 0;
  int restoreCheckpointCalls = 0;
  Uint8List? lastRestoredBytes;

  @override
  ReadCheckpointResult readCheckpoint(SequenceId id) {
    readCheckpointCalls += 1;
    return ReadCheckpointSucceeded(readCheckpointBytes);
  }

  @override
  RestoreCheckpointResult restoreCheckpoint(SequenceId id, Uint8List bytes) {
    restoreCheckpointCalls += 1;
    lastRestoredBytes = bytes;
    return restoreCheckpointResult;
  }
}

final class _ReleasingAllocator implements Allocator {
  _ReleasingAllocator({
    required List<Lease> leases,
    this.result = const ReleaseLeaseSucceeded(),
  }) : _leases = [...leases];

  final List<Lease> _leases;
  final ReleaseLeaseResult result;
  final released = <Lease>[];

  void readmit(Lease lease) => _leases.add(lease);

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
  int effectiveLimitFor(Lease lease) => contextSize;

  @override
  bool owns(Lease lease) => _leases.any((owned) => identical(owned, lease));

  @override
  ReleaseLeaseResult release(Lease lease) {
    released.add(lease);
    if (result is ReleaseLeaseSucceeded) _leases.remove(lease);
    return result;
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
