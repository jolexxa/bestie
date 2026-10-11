import 'package:bestie_platform_macos/bestie_platform_macos.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

class MockStatvfsReader extends Mock implements StatvfsReader {}

void main() {
  late MockStatvfsReader reader;
  late MacOSDiskSpaceDataSource dataSource;

  setUp(() {
    reader = MockStatvfsReader();
    dataSource = MacOSDiskSpaceDataSource(reader: reader);
  });

  test('reports the bytes available to unprivileged users', () {
    when(() => reader.statvfs('/models')).thenReturn(
      const StatvfsSucceeded(
        StatvfsSnapshot(
          fragmentSize: 4096,
          blocks: 1000,
          blocksFree: 500,
          blocksAvailable: 250,
        ),
      ),
    );

    expect(dataSource.availableBytes('/models'), 250 * 4096);
  });

  test('reports no space when the filesystem cannot be read', () {
    when(
      () => reader.statvfs('/missing'),
    ).thenReturn(
      const StatvfsFailed(
        PosixFailure(function: 'statvfs', errno: 2, message: 'No such file'),
      ),
    );

    expect(dataSource.availableBytes('/missing'), 0);
  });
}
