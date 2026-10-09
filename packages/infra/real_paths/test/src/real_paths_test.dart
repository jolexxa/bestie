import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:real_paths/real_paths.dart';
import 'package:test/test.dart';

class _MockFileSystem extends Mock implements FileSystem {}

class _MockFile extends Mock implements File {}

void main() {
  late MemoryFileSystem fileSystem;
  late RealPaths realPaths;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work/real').createSync(recursive: true);
    fileSystem.file('/work/real/notes.md').createSync();
    fileSystem.link('/work/linked').createSync('/work/real');
    fileSystem.link('/work/notes.md').createSync('/work/real/notes.md');
    realPaths = RealPaths(fileSystem);
  });

  group('canonicalize', () {
    test('leaves a real file as it is', () {
      expect(
        realPaths.canonicalize('/work/real/notes.md'),
        '/work/real/notes.md',
      );
    });

    test('follows a link to its file', () {
      expect(realPaths.canonicalize('/work/notes.md'), '/work/real/notes.md');
    });

    test('has nothing for a path that does not exist', () {
      expect(realPaths.canonicalize('/work/missing.md'), isNull);
    });
  });

  group('resolve', () {
    test('leaves a real file as it is', () {
      expect(realPaths.resolve('/work/real/notes.md'), '/work/real/notes.md');
    });

    test('follows a link to its file', () {
      expect(realPaths.resolve('/work/notes.md'), '/work/real/notes.md');
    });

    test('follows a linked directory to the file under it', () {
      expect(realPaths.resolve('/work/linked/notes.md'), '/work/real/notes.md');
    });

    test('follows a chain of links to the end', () {
      fileSystem.link('/work/again.md').createSync('/work/notes.md');

      expect(realPaths.resolve('/work/again.md'), '/work/real/notes.md');
    });

    test('keeps a new name under a linked directory', () {
      expect(realPaths.resolve('/work/linked/new.md'), '/work/real/new.md');
    });

    test('keeps every missing level under the deepest that exists', () {
      expect(
        realPaths.resolve('/work/linked/a/b/new.md'),
        '/work/real/a/b/new.md',
      );
    });

    test('steps out of a linked directory from its target', () {
      fileSystem.directory('/elsewhere/deep').createSync(recursive: true);
      fileSystem.link('/work/deep').createSync('/elsewhere/deep');

      expect(realPaths.resolve('/work/deep/../new.md'), '/elsewhere/new.md');
    });

    test('names a dangling link itself', () {
      fileSystem.link('/work/dangling.md').createSync('/work/gone.md');

      expect(realPaths.resolve('/work/dangling.md'), '/work/dangling.md');
    });

    test('tidies a path where nothing exists', () {
      expect(
        realPaths.resolve('/nowhere/./at/../all.md'),
        '/nowhere/all.md',
      );
    });

    test('tidies a path when not even its root resolves', () {
      final fileSystem = _MockFileSystem();
      final file = _MockFile();
      when(() => fileSystem.path).thenReturn(p.windows);
      when(() => fileSystem.file(any<String>())).thenReturn(file);
      when(file.resolveSymbolicLinksSync).thenThrow(
        const FileSystemException('The system cannot find the drive.'),
      );

      expect(
        RealPaths(fileSystem).resolve(r'Q:\work\.\notes.md'),
        r'Q:\work\notes.md',
      );
    });
  });
}
