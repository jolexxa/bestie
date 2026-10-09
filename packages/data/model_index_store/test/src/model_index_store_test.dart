import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:test/test.dart';

const _folder = '/home/me/.bestie/models';
const _path = '$_folder/index.json';

const _index = ModelIndex(
  version: ModelIndex.currentVersion,
  models: [
    ModelIndexEntry(
      localId: 'qwen3-1.7b-q4_k_m-1a2b3c4d',
      path: '/home/me/.bestie/models/Qwen/Qwen3-1.7B-GGUF/Qwen3-1.7B.gguf',
      displayName: 'Qwen3 1.7B',
      profileId: ModelProfileId.qwen3,
      architecture: 'qwen3',
      fileType: 'Q4_K_M',
      sizeBytes: 1107409472,
      trainedContextLength: 40960,
      reasoning: ModelReasoningToggle(),
      defaultSampling: ModelSamplingDefaults(temperature: 0.6),
      provenance: ModelDownloaded(
        repo: 'Qwen/Qwen3-1.7B-GGUF',
        revision: 'abc123',
        file: 'Qwen3-1.7B.gguf',
      ),
      fingerprint: '1a2b3c4d',
    ),
  ],
);

void main() {
  late MemoryFileSystem fileSystem;
  late List<String> operations;

  setUp(() {
    operations = [];
    fileSystem = MemoryFileSystem.test(
      opHandle: (context, operation) => operations.add('$operation $context'),
    );
  });

  ModelIndexStore store([FileSystem? system]) =>
      ModelIndexStore(path: _path, fileSystem: system ?? fileSystem);

  group('ModelIndexStore', () {
    test('reads nothing before the first write', () async {
      expect(await store().read(), isA<StoreAbsent<ModelIndex>>());
    });

    test(
      'writes the index through a temporary file and reads it back',
      () async {
        expect(await store().write(_index), isA<StoreWritten>());

        expect(fileSystem.directory(_folder).listSync(), [
          isA<File>().having((file) => file.path, 'path', _path),
        ]);
        expect(
          operations,
          contains(matches(RegExp(r'^FileSystemOp\.write .+\.tmp$'))),
        );
        expect(operations, isNot(contains('FileSystemOp.write $_path')));
        final read = await store().read();
        expect((read as StoreLoaded<ModelIndex>).value, _index);
      },
    );

    test('writes snake case JSON the server can read', () async {
      await store().write(_index);

      final json = fileSystem.file(_path).readAsStringSync();
      expect(json, contains('"local_id": "qwen3-1.7b-q4_k_m-1a2b3c4d"'));
      expect(ModelIndexMapper.fromJson(json), _index);
    });

    test('gives every write its own temporary file', () async {
      final temporaries = <String>{};
      final watched = MemoryFileSystem.test(
        opHandle: (context, operation) {
          if (operation == FileSystemOp.write) temporaries.add(context);
        },
      );

      await Future.wait([
        store(watched).write(_index),
        store(watched).write(_index),
      ]);

      expect(temporaries, hasLength(2));
      expect(temporaries, everyElement(endsWith('.tmp')));
      expect(watched.directory(_folder).listSync(), hasLength(1));
    });

    test('replaces an earlier index', () async {
      await store().write(_index);
      const empty = ModelIndex(version: ModelIndex.currentVersion, models: []);

      await store().write(empty);

      expect(
        (await store().read() as StoreLoaded<ModelIndex>).value,
        empty,
      );
    });

    test('reports a file that is not JSON as corrupt', () async {
      fileSystem.file(_path)
        ..createSync(recursive: true)
        ..writeAsStringSync('{nope');

      final read = await store().read();

      expect(
        (read as StoreCorrupt<ModelIndex>).reason,
        startsWith('$_path is not valid JSON'),
      );
    });

    test('reports JSON of the wrong shape as corrupt', () async {
      fileSystem.file(_path)
        ..createSync(recursive: true)
        ..writeAsStringSync('{"version": 1}');

      final read = await store().read();

      expect(
        (read as StoreCorrupt<ModelIndex>).reason,
        startsWith('$_path does not match its schema'),
      );
    });

    test('reports a file it cannot open as unreadable', () async {
      fileSystem.file(_path).createSync(recursive: true);
      final failing = MemoryFileSystem.test(
        opHandle: (context, operation) {
          if (operation == FileSystemOp.read) {
            throw FileSystemException('Permission denied', context);
          }
        },
      );
      failing.file(_path).createSync(recursive: true);

      final read = await store(failing).read();

      expect(
        (read as StoreUnreadable<ModelIndex>).reason,
        'Permission denied: $_path',
      );
    });

    test('reports a failed write and leaves no index behind', () async {
      fileSystem.file('/home/me/.bestie/models')
        ..createSync(recursive: true)
        ..writeAsStringSync('a file where the folder should be');

      final written = await store().write(_index);

      expect(written, isA<StoreWriteFailed>());
      expect((written as StoreWriteFailed).reason, endsWith(_path));
    });
  });
}
