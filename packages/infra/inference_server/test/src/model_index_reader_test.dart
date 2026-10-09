import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:inference_server/inference_server.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/index.dart';

final class _MockFileSystem extends Mock implements FileSystem {}

final class _MockFile extends Mock implements File {}

void main() {
  const path = '/bestie/models/index.json';
  late MemoryFileSystem fileSystem;
  late ModelIndexReader reader;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    reader = ModelIndexReader(fileSystem: fileSystem, path: path);
  });

  test('reads the index and finds entries by id', () async {
    writeIndex(fileSystem, path, [qwenEntry]);

    final read = await reader.read() as ModelIndexRead;

    expect(read.index.models.single.localId, qwenEntry.localId);
    expect(read.entryFor(qwenEntry.localId)?.path, qwenEntry.path);
    expect(read.entryFor('missing'), isNull);
    expect(read.skippedEntries, 0);
  });

  test('leaves out entries it cannot load and keeps the rest', () async {
    writeIndexWithUnknownProfile(fileSystem, path, [qwenEntry]);

    final read = await reader.read() as ModelIndexRead;

    expect(read.index.models, [qwenEntry]);
    expect(read.skippedEntries, 1);
    expect(read.entryFor(unknownProfileId), isNull);
  });

  test('a missing index means no models', () async {
    expect(await reader.read(), isA<ModelIndexMissing>());
  });

  test('an index that is not JSON is malformed', () async {
    fileSystem.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('{nope');

    expect(await reader.read(), isA<ModelIndexMalformed>());
  });

  test('an index of the wrong shape is malformed', () async {
    fileSystem.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('{"version": 1}');

    expect(await reader.read(), isA<ModelIndexMalformed>());
  });

  test('an index that cannot be read is malformed', () async {
    final failingFileSystem = _MockFileSystem();
    final file = _MockFile();
    when(() => failingFileSystem.file(path)).thenReturn(file);
    when(file.existsSync).thenReturn(true);
    when(file.readAsString).thenThrow(const FileSystemException('denied'));

    expect(
      await ModelIndexReader(fileSystem: failingFileSystem, path: path).read(),
      isA<ModelIndexMalformed>().having(
        (malformed) => malformed.message,
        'message',
        'denied',
      ),
    );
  });
}
