import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_posix/bestie_posix.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  late FileSystem fs;
  late PosixExecutableLinkDataSource dataSource;

  setUp(() {
    fs = MemoryFileSystem();
    dataSource = PosixExecutableLinkDataSource(fileSystem: fs);
  });

  test('symlinks the dispatch name to the multicall', () {
    fs.file('/opt/bin/coreutils').createSync(recursive: true);

    final result = dataSource.link(
      linkPath: '/opt/bin/ls',
      targetPath: '/opt/bin/coreutils',
    );

    expect(result, isA<ExecutableLinkCreated>());
    final link = fs.link('/opt/bin/ls');
    expect(link.existsSync(), isTrue);
    expect(link.targetSync(), '/opt/bin/coreutils');
  });

  test('reports failure when the link path already exists', () {
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    fs.file('/opt/bin/ls').createSync();

    final result = dataSource.link(
      linkPath: '/opt/bin/ls',
      targetPath: '/opt/bin/coreutils',
    );

    expect(result, isA<ExecutableLinkFailed>());
    expect((result as ExecutableLinkFailed).reason, isNotEmpty);
  });
}
