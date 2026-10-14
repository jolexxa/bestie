import 'package:bestie_platform_macos/bestie_platform_macos.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

class MockPosixMach extends Mock implements PosixMach {}

class MockPosixSysctl extends Mock implements PosixSysctl {}

const _pageSize = 16384;
const _totalBytes = 34359738368;

const _stats = MachVmStatistics(
  freeCount: 352597,
  activeCount: 736733,
  inactiveCount: 582580,
  wireCount: 313916,
  internalPageCount: 845256,
  purgeableCount: 29078,
  compressorPageCount: 56338,
);

void main() {
  late MockPosixMach mach;
  late MockPosixSysctl sysctl;
  late MacOSSystemInfoDataSource dataSource;

  setUp(() {
    mach = MockPosixMach();
    sysctl = MockPosixSysctl();
    dataSource = MacOSSystemInfoDataSource(mach: mach, sysctl: sysctl);

    when(() => mach.hostVmStatistics()).thenReturn(_stats);
    when(() => sysctl.byNameInt64('hw.memsize')).thenReturn(_totalBytes);
    when(() => sysctl.byNameInt32('hw.pagesize')).thenReturn(_pageSize);
  });

  test('reports all of the machine memory and that it is unified', () {
    final snapshot = dataSource.readSystemInfo();

    expect(snapshot.totalRamBytes, _totalBytes);
    expect(snapshot.platformAlwaysUnified, isTrue);
    expect(snapshot.logicalCoreCount, greaterThan(0));
  });

  test('counts free, active and inactive pages as available', () {
    expect(
      dataSource.readSystemInfo().availableRamBytes,
      (352597 + 736733 + 582580) * _pageSize,
    );
  });

  test('never counts wired or compressed pages as available', () {
    when(() => mach.hostVmStatistics()).thenReturn(
      const MachVmStatistics(
        freeCount: 0,
        activeCount: 0,
        inactiveCount: 0,
        wireCount: 1000,
        internalPageCount: 1000,
        purgeableCount: 0,
        compressorPageCount: 1000,
      ),
    );

    expect(dataSource.readSystemInfo().availableRamBytes, 0);
  });

  test('never reports more available than the machine has', () {
    when(() => sysctl.byNameInt64('hw.memsize')).thenReturn(_pageSize);

    expect(dataSource.readSystemInfo().availableRamBytes, _pageSize);
  });

  test('reads the host by default', testOn: 'mac-os', () {
    final snapshot = MacOSSystemInfoDataSource().readSystemInfo();

    expect(snapshot.availableRamBytes, greaterThan(0));
    expect(
      snapshot.availableRamBytes,
      lessThanOrEqualTo(snapshot.totalRamBytes),
    );
  });

  group('when the host refuses to answer', () {
    test('reports no memory without the VM statistics', () {
      when(() => mach.hostVmStatistics()).thenReturn(null);

      expect(dataSource.readSystemInfo().availableRamBytes, 0);
    });

    test('reports no memory without the page size', () {
      when(() => sysctl.byNameInt32('hw.pagesize')).thenReturn(null);

      expect(dataSource.readSystemInfo().availableRamBytes, 0);
    });

    test('reports no memory without the machine size', () {
      when(() => sysctl.byNameInt64('hw.memsize')).thenReturn(null);

      final snapshot = dataSource.readSystemInfo();

      expect(snapshot.totalRamBytes, 0);
      expect(snapshot.availableRamBytes, 0);
    });
  });
}
