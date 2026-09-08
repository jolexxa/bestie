import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockFileSystem extends Mock implements FileSystem {}

class _MockDirectory extends Mock implements Directory {}

class _MockFile extends Mock implements File {}

class _MockRandomAccessFile extends Mock implements RandomAccessFile {}

const _boom = FileSystemException('permission denied');

/// A file that answers for [path] and nothing else until a test says so.
_MockFile _fileAt(String path) {
  final file = _MockFile();
  final absolute = _MockFile();
  when(() => file.path).thenReturn(path);
  when(() => absolute.path).thenReturn(path);
  when(() => file.absolute).thenReturn(absolute);
  return file;
}

_MockFileSystem _fileSystemWith({Directory? directory, File? file}) {
  final fileSystem = _MockFileSystem();
  when(() => fileSystem.path).thenReturn(p.Context(style: p.Style.posix));
  if (directory != null) {
    when(() => fileSystem.directory(any<dynamic>())).thenReturn(directory);
  }
  if (file != null) {
    when(() => fileSystem.file(any<dynamic>())).thenReturn(file);
  }
  return fileSystem;
}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  group('looksBinary', () {
    test('calls a file it cannot read binary, and closes it anyway', () async {
      // Reading may fail after the open succeeded. Refusing to hand back
      // "this is text" is the safe answer, and the handle still has to go.
      final handle = _MockRandomAccessFile();
      when(() => handle.readInto(any())).thenThrow(_boom);
      when(handle.close).thenAnswer((_) async => handle);
      final file = _fileAt('/work/notes.txt');
      when(file.open).thenAnswer((_) async => handle);

      final files = FilesDataSource(
        fileSystem: _fileSystemWith(file: file),
        workingDirectory: '/work',
      );

      expect(await files.looksBinary('notes.txt'), isTrue);
      verify(handle.close).called(1);
    });
  });

  group('children', () {
    test('skips an entry the listing failed on and keeps going', () async {
      final good = _fileAt('/work/src/a.dart');
      when(good.length).thenAnswer((_) async => 5);

      Stream<FileSystemEntity> listing() async* {
        yield good;
        throw _boom;
      }

      final directory = _MockDirectory();
      when(
        () => directory.list(followLinks: any(named: 'followLinks')),
      ).thenAnswer((_) => listing());
      final files = FilesDataSource(
        fileSystem: _fileSystemWith(directory: directory),
        workingDirectory: '/work',
      );

      final entries = await files.children('src').toList();

      expect(entries.map((e) => e.name), ['a.dart']);
      expect(entries.single.size, 5);
    });

    test('sizes a file that went away at zero rather than failing', () async {
      // Listed a moment ago, gone by the time it is measured — one entry
      // disappearing should not end the sweep.
      final vanished = _fileAt('/work/src/gone.dart');
      when(vanished.length).thenThrow(_boom);

      final directory = _MockDirectory();
      when(
        () => directory.list(followLinks: any(named: 'followLinks')),
      ).thenAnswer((_) => Stream.value(vanished));
      final files = FilesDataSource(
        fileSystem: _fileSystemWith(directory: directory),
        workingDirectory: '/work',
      );

      final entries = await files.children('src').toList();

      expect(entries.single.name, 'gone.dart');
      expect(entries.single.size, 0);
    });

    test('yields nothing when the listing refuses outright', () async {
      final directory = _MockDirectory();
      when(
        () => directory.list(followLinks: any(named: 'followLinks')),
      ).thenThrow(_boom);
      final files = FilesDataSource(
        fileSystem: _fileSystemWith(directory: directory),
        workingDirectory: '/work',
      );

      expect(await files.children('src').toList(), isEmpty);
    });
  });
}
