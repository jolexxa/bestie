import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockDiskQuery disk;
  late WindowsDiskSpaceDataSource dataSource;

  setUp(() {
    disk = MockDiskQuery();
    dataSource = WindowsDiskSpaceDataSource(disk: disk);
  });

  test('reports the space available to the user, not the volume total', () {
    when(() => disk.space(any())).thenReturn(
      const DiskSpaceSucceeded(
        DiskSpace(
          availableBytes: 120,
          totalBytes: 500,
          freeBytes: 300,
        ),
      ),
    );

    expect(dataSource.availableBytes(r'C:\Users\tester'), 120);
    verify(() => disk.space(r'C:\Users\tester')).called(1);
  });

  test('reports nothing available when the volume cannot be read', () {
    when(() => disk.space(any())).thenReturn(const DiskSpaceFailed(failure));

    expect(dataSource.availableBytes(r'Z:\nope'), 0);
  });
}
