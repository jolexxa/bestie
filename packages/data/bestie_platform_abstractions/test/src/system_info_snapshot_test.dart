import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

SystemInfoSnapshot _snapshot({
  required int totalRamBytes,
  required int availableRamBytes,
}) => SystemInfoSnapshot(
  logicalCoreCount: 8,
  totalRamBytes: totalRamBytes,
  availableRamBytes: availableRamBytes,
  platformAlwaysUnified: false,
);

void main() {
  test('a snapshot reports what it was read with', () {
    const snapshot = SystemInfoSnapshot(
      logicalCoreCount: 8,
      totalRamBytes: 16,
      availableRamBytes: 4,
      platformAlwaysUnified: true,
    );

    expect(snapshot.logicalCoreCount, 8);
    expect(snapshot.totalRamBytes, 16);
    expect(snapshot.availableRamBytes, 4);
    expect(snapshot.platformAlwaysUnified, isTrue);
  });

  group('RAM usage derived from a snapshot', () {
    test('is the difference between total and available', () {
      final stat = _snapshot(
        totalRamBytes: 16000,
        availableRamBytes: 4000,
      ).ramStat;

      expect(stat.usedBytes, 12000);
      expect(stat.totalBytes, 16000);
      expect(stat.availablePercent, 25);
    });

    test('rounds the available percentage', () {
      final stat = _snapshot(
        totalRamBytes: 3000,
        availableRamBytes: 1000,
      ).ramStat;

      expect(stat.availablePercent, 33);
    });

    // A host that reports no memory at all would otherwise divide by zero.
    test('is empty rather than undefined when no total is reported', () {
      final stat = _snapshot(totalRamBytes: 0, availableRamBytes: 0).ramStat;

      expect(stat.usedBytes, 0);
      expect(stat.totalBytes, 0);
      expect(stat.availablePercent, 0);
    });

    // Some hosts report more available than total for a moment after a
    // reclaim; a percentage over 100 would render as a broken gauge.
    test('never reports more than all of memory available', () {
      final stat = _snapshot(
        totalRamBytes: 16000,
        availableRamBytes: 20000,
      ).ramStat;

      expect(stat.availablePercent, 100);
    });
  });
}
