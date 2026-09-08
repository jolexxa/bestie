import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockMemoryQuery memory;
  late MockProcessorQuery processors;
  late WindowsSystemInfoDataSource dataSource;

  setUp(() {
    memory = MockMemoryQuery();
    processors = MockProcessorQuery();
    dataSource = WindowsSystemInfoDataSource(
      memory: memory,
      processors: processors,
    );

    when(() => memory.status()).thenReturn(
      const MemoryStatusSucceeded(
        MemoryStatus(totalBytes: 34359738368, availableBytes: 17179869184),
      ),
    );
    when(() => processors.activeCount()).thenReturn(
      const ProcessorCountSucceeded(16),
    );
  });

  test('reports what the host answered', () {
    final snapshot = dataSource.readSystemInfo();

    expect(snapshot.logicalCoreCount, 16);
    expect(snapshot.totalRamBytes, 34359738368);
    expect(snapshot.availableRamBytes, 17179869184);
    expect(snapshot.platformAlwaysUnified, isFalse);
  });

  group('when the host refuses to answer', () {
    test('assumes one processor rather than none', () {
      when(
        () => processors.activeCount(),
      ).thenReturn(const ProcessorCountFailed(failure));

      expect(dataSource.readSystemInfo().logicalCoreCount, 1);
    });

    test('reports no memory rather than a wrong figure', () {
      when(() => memory.status()).thenReturn(
        const MemoryStatusFailed(failure),
      );

      final snapshot = dataSource.readSystemInfo();

      expect(snapshot.totalRamBytes, 0);
      expect(snapshot.availableRamBytes, 0);
      expect(snapshot.ramStat.availablePercent, 0);
    });
  });
}
