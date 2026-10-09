import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:test/test.dart';

void main() {
  late WorkspacePaths paths;

  setUp(() {
    final fileSystem = MemoryFileSystem.test();
    fileSystem.file('/work/real.md').createSync(recursive: true);
    fileSystem.link('/work/link.md').createSync('/work/real.md');
    paths = WorkspacePaths(
      files: FilesDataSource(fileSystem: fileSystem, workingDirectory: '/work'),
    );
  });

  test('targets the file a link leads to', () {
    expect(paths.targetOf('link.md'), '/work/real.md');
  });

  test('targets a new file where it will land', () {
    expect(paths.targetOf('drafts/new.md'), '/work/drafts/new.md');
  });
}
