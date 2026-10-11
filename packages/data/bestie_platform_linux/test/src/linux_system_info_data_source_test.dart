@TestOn('!windows')
library;

import 'package:bestie_platform_linux/bestie_platform_linux.dart';
import 'package:test/test.dart';

void main() {
  test('reads the host memory and leaves unified memory to the backend', () {
    final snapshot = LinuxSystemInfoDataSource().readSystemInfo();

    expect(snapshot.logicalCoreCount, greaterThan(0));
    expect(snapshot.totalRamBytes, greaterThan(0));
    expect(
      snapshot.availableRamBytes,
      lessThanOrEqualTo(snapshot.totalRamBytes),
    );
    expect(snapshot.platformAlwaysUnified, isFalse);
  });
}
