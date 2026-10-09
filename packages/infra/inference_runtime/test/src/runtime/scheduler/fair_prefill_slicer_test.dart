import 'package:inference_runtime/src/runtime/scheduler/sequence_scheduler.dart';
import 'package:test/test.dart';

void main() {
  group('FairPrefillSlicer', () {
    test('allocates capacity round-robin across equally weighted streams', () {
      final slicer = FairPrefillSlicer();

      expect(
        slicer.allocate(
          maxBatchTokens: 4,
          streams: const [
            FairPrefillStream(key: #first, remainingTokenCount: 6, weight: 1),
            FairPrefillStream(key: #second, remainingTokenCount: 3, weight: 1),
            FairPrefillStream(key: #third, remainingTokenCount: 3, weight: 1),
          ],
        ),
        [2, 1, 1],
      );
    });

    test('skips exhausted streams and keeps later streams moving', () {
      final slicer = FairPrefillSlicer();

      expect(
        slicer.allocate(
          maxBatchTokens: 6,
          streams: const [
            FairPrefillStream(key: #first, remainingTokenCount: 1, weight: 1),
            FairPrefillStream(key: #second, remainingTokenCount: 5, weight: 1),
            FairPrefillStream(key: #third, remainingTokenCount: 5, weight: 1),
          ],
        ),
        [1, 3, 2],
      );
    });

    test('returns zero slices when capacity is exhausted', () {
      final slicer = FairPrefillSlicer();

      expect(
        slicer.allocate(
          maxBatchTokens: 0,
          streams: const [
            FairPrefillStream(key: #first, remainingTokenCount: 1, weight: 1),
            FairPrefillStream(key: #second, remainingTokenCount: 1, weight: 1),
          ],
        ),
        [0, 0],
      );
    });

    test('favors streams with larger allocation weights', () {
      final slicer = FairPrefillSlicer();

      expect(
        slicer.allocate(
          maxBatchTokens: 12,
          streams: const [
            FairPrefillStream(
              key: #primary,
              remainingTokenCount: 100,
              weight: 10,
            ),
            FairPrefillStream(key: #first, remainingTokenCount: 10, weight: 1),
            FairPrefillStream(key: #second, remainingTokenCount: 10, weight: 1),
          ],
        ),
        [10, 1, 1],
      );
    });

    test('carries debt across small allocations', () {
      final slicer = FairPrefillSlicer();

      List<int> allocate() {
        return slicer.allocate(
          maxBatchTokens: 1,
          streams: const [
            FairPrefillStream(
              key: #primary,
              remainingTokenCount: 10,
              weight: 2,
            ),
            FairPrefillStream(key: #first, remainingTokenCount: 10, weight: 1),
            FairPrefillStream(key: #second, remainingTokenCount: 10, weight: 1),
          ],
        );
      }

      expect(allocate(), [1, 0, 0]);
      expect(allocate(), [0, 1, 0]);
      expect(allocate(), [0, 0, 1]);
      expect(allocate(), [1, 0, 0]);
    });
  });
}
