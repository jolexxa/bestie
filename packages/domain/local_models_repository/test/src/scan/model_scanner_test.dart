import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/scan/model_scanner.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/gguf_writer.dart';

void main() {
  late MemoryFileSystem fileSystem;

  setUp(() => fileSystem = MemoryFileSystem.test());

  Future<List<LocalModel>> scan(
    List<String> roots, {
    FileSystem? system,
  }) => ModelScanner(fileSystem: system ?? fileSystem).scan(roots);

  test('describes a runnable model from its header', () async {
    writeGguf(
      fileSystem,
      '/models/Qwen3-1.7B-Q4_K_M.gguf',
      extra: {
        'qwen3.pooling_type': TestValue.uint32(0),
        'general.sampling.temp': TestValue.float32(0.5),
        'general.sampling.top_k': TestValue.int32(20),
        'general.sampling.top_p': TestValue.float32(0.25),
        'general.sampling.min_p': TestValue.float32(0.125),
      },
    );

    final models = await scan(['/models']);

    final model = models.single as SupportedModel;
    expect(model.id, matches(RegExp(r'^qwen3-1\.7b-q4_k_m-[0-9a-f]{8}$')));
    expect(model.id, endsWith(model.fingerprint));
    expect(model.path, '/models/Qwen3-1.7B-Q4_K_M.gguf');
    expect(model.displayName, 'Qwen3 1.7B');
    expect(
      model.sizeBytes,
      fileSystem.file('/models/Qwen3-1.7B-Q4_K_M.gguf').lengthSync(),
    );
    expect(model.profile, ModelProfileId.qwen3);
    expect(model.architecture, 'qwen3');
    expect(model.quant, QuantType.q4KMedium);
    expect(model.contextLength, 40960);
    expect(model.parameterCount, 64);
    expect(model.reasoning, const ModelReasoningToggle());
    expect(
      model.sampling,
      const ModelSamplingDefaults(
        temperature: 0.5,
        topK: 20,
        topP: 0.25,
        minP: 0.125,
      ),
    );
    final source = model.source as ScannedSource;
    expect(source.root, '/models');
    expect(source.inferredRepo, isNull);
  });

  test('prefers the parameter count the header states', () async {
    writeGguf(
      fileSystem,
      '/models/a.gguf',
      extra: {'general.parameter_count': TestValue.uint64(1700000000)},
    );

    final model = (await scan(['/models'])).single as SupportedModel;

    expect(model.parameterCount, 1700000000);
  });

  test('keeps a model id across scans and tells copies apart', () async {
    writeGguf(fileSystem, '/models/a/Qwen3-1.7B-Q4_K_M.gguf');
    writeGguf(fileSystem, '/models/b/Qwen3-1.7B-Q4_K_M.gguf', padding: 1);

    final first = await scan(['/models']);
    final second = await scan(['/models']);

    expect(first.map((model) => model.id), second.map((model) => model.id));
    expect(first[0].id, isNot(first[1].id));
  });

  test('names a model after its file when the header has no name', () async {
    writeGguf(
      fileSystem,
      '/models/my-model-Q8_0.gguf',
      name: null,
      fileType: 7,
    );

    final model = (await scan(['/models'])).single;

    expect(model.displayName, 'my-model-Q8_0');
    expect(model.id, startsWith('my-model-q8_0-'));
  });

  group('lists what it cannot run, with the reason', () {
    Future<UnsupportedReason> reasonFor(void Function() write) async {
      write();
      return ((await scan(['/models'])).single as UnsupportedModel).reason;
    }

    test('an architecture no profile runs', () async {
      final reason = await reasonFor(
        () => writeGguf(
          fileSystem,
          '/models/granite.gguf',
          architecture: 'granitehybrid',
        ),
      );

      expect((reason as ArchitectureUnsupported).architecture, 'granitehybrid');
    });

    test('a chat architecture that pools its output', () async {
      final embedder = await reasonFor(
        () => writeGguf(
          fileSystem,
          '/models/Qwen3-Embedding-0.6B-Q8_0.gguf',
          extra: {'qwen3.pooling_type': TestValue.uint32(3)},
        ),
      );

      expect((embedder as NotAChatModel).task, 'feature-extraction');
    });

    test('a model that pools to a rank', () async {
      final reranker = await reasonFor(
        () => writeGguf(
          fileSystem,
          '/models/Qwen3-Reranker-0.6B-Q8_0.gguf',
          extra: {'qwen3.pooling_type': TestValue.uint32(4)},
        ),
      );

      expect((reranker as NotAChatModel).task, 'text-ranking');
    });

    test('no architecture at all', () async {
      final reason = await reasonFor(
        () => writeGguf(fileSystem, '/models/a.gguf', architecture: null),
      );

      expect((reason as MetadataMissing).key, 'general.architecture');
    });

    test('no file type', () async {
      final reason = await reasonFor(
        () => writeGguf(fileSystem, '/models/a.gguf', fileType: null),
      );

      expect((reason as MetadataMissing).key, 'general.file_type');
    });

    test('an unknown file type', () async {
      final reason = await reasonFor(
        () => writeGguf(fileSystem, '/models/a.gguf', fileType: 33),
      );

      expect((reason as QuantUnsupported).fileType, 33);
    });

    test('no trained context length', () async {
      final reason = await reasonFor(
        () => writeGguf(fileSystem, '/models/a.gguf', contextLength: null),
      );

      expect((reason as MetadataMissing).key, 'qwen3.context_length');
    });

    test('a file that is not a GGUF', () async {
      fileSystem.file('/models/broken-Q4_K_M.gguf')
        ..createSync(recursive: true)
        ..writeAsStringSync('not a gguf at all');

      final model = (await scan(['/models'])).single as UnsupportedModel;

      expect(model.reason, isA<HeaderUnreadable>());
      expect((model.reason as HeaderUnreadable).reason, contains('bad magic'));
      expect(model.displayName, 'broken-Q4_K_M');
      expect(model.id, matches(RegExp(r'^broken-q4_k_m-[0-9a-f]{8}$')));
      expect(model.sizeBytes, 17);
    });

    test('a file it cannot open', () async {
      writeGguf(fileSystem, '/models/a.gguf');
      final locked = MemoryFileSystem.test(
        opHandle: (path, operation) {
          if (operation == FileSystemOp.open && path == '/models/a.gguf') {
            throw FileSystemException('Permission denied', path);
          }
        },
      );
      writeGguf(locked, '/models/a.gguf');

      final model = (await scan(['/models'], system: locked)).single;

      expect(
        ((model as UnsupportedModel).reason as HeaderUnreadable).reason,
        contains('Permission denied'),
      );
    });

    test('a file that goes away while it is read', () async {
      var opens = 0;
      final flaky = MemoryFileSystem.test(
        opHandle: (path, operation) {
          if (operation == FileSystemOp.open && path == '/models/a.gguf') {
            if (++opens > 1) throw FileSystemException('Vanished', path);
          }
        },
      );
      writeGguf(flaky, '/models/a.gguf');

      final model = (await scan(['/models'], system: flaky)).single;

      expect(
        (model as UnsupportedModel).reason,
        isA<HeaderUnreadable>().having(
          (reason) => reason.reason,
          'reason',
          'Vanished',
        ),
      );
    });
  });

  group('split models', () {
    test(
      'are listed once, by their first file, with every file counted',
      () async {
        writeGguf(
          fileSystem,
          '/models/big-Q8_0-00001-of-00002.gguf',
          fileType: 7,
        );
        fileSystem.file('/models/big-Q8_0-00002-of-00002.gguf')
          ..createSync()
          ..writeAsBytesSync(List.filled(1000, 1));

        final model = (await scan(['/models'])).single as SupportedModel;

        expect(model.path, '/models/big-Q8_0-00001-of-00002.gguf');
        expect(
          model.sizeBytes,
          fileSystem.file(model.path).lengthSync() + 1000,
        );
        expect(model.parameterCount, isNull);
      },
    );

    test('count the parameters of every file', () async {
      writeGguf(
        fileSystem,
        '/models/big-Q8_0-00001-of-00002.gguf',
        fileType: 7,
      );
      writeGguf(
        fileSystem,
        '/models/big-Q8_0-00002-of-00002.gguf',
        fileType: 7,
      );

      final model = (await scan(['/models'])).single as SupportedModel;

      expect(model.parameterCount, 128);
    });

    test('cannot run with a file missing', () async {
      writeGguf(
        fileSystem,
        '/models/big-Q8_0-00001-of-00003.gguf',
        fileType: 7,
      );
      fileSystem.file('/models/big-Q8_0-00003-of-00003.gguf').createSync();

      final model = (await scan(['/models'])).single as UnsupportedModel;

      expect(
        model.reason,
        isA<ShardsMissing>()
            .having((reason) => reason.found, 'found', 2)
            .having((reason) => reason.expected, 'expected', 3),
      );
    });
  });

  group('walks', () {
    test('every subfolder, skipping projectors and partial files', () async {
      writeGguf(fileSystem, '/models/org/repo/model-Q4_K_M.gguf');
      writeGguf(fileSystem, '/models/org/repo/mmproj-model-f16.gguf');
      writeGguf(fileSystem, '/models/org/repo/next.gguf.part');
      fileSystem.file('/models/notes.txt').createSync(recursive: true);

      final models = await scan(['/models']);

      expect(models.map((model) => model.path), [
        '/models/org/repo/model-Q4_K_M.gguf',
      ]);
      expect(
        (models.single.source as ScannedSource).inferredRepo!.repo,
        'org/repo',
      );
    });

    test('each file once, under the first folder that holds it', () async {
      writeGguf(fileSystem, '/models/nested/a.gguf');

      final models = await scan(['/models', '/models/nested', '/missing']);

      expect(models, hasLength(1));
      expect((models.single.source as ScannedSource).root, '/models');
    });

    test('into linked files but not linked folders', () async {
      writeGguf(fileSystem, '/blobs/model.gguf');
      fileSystem
          .link('/models/linked.gguf')
          .createSync(
            '/blobs/model.gguf',
            recursive: true,
          );
      fileSystem.link('/models/loop').createSync('/models');
      fileSystem.link('/models/dangling.gguf').createSync('/nowhere.gguf');

      final models = await scan(['/models']);

      expect(models.map((model) => model.path), ['/models/linked.gguf']);
    });

    test('past folders it cannot list', () async {
      expect(await scan(['/missing']), isEmpty);
    });

    test('past hidden entries and node_modules', () async {
      writeGguf(fileSystem, '/models/.cache/hidden-Q4_K_M.gguf');
      writeGguf(fileSystem, '/models/._resource-Q4_K_M.gguf');
      writeGguf(fileSystem, '/models/app/node_modules/dep-Q4_K_M.gguf');
      writeGguf(fileSystem, '/models/app/model-Q4_K_M.gguf');

      final models = await scan(['/models']);

      expect(models.map((model) => model.path), [
        '/models/app/model-Q4_K_M.gguf',
      ]);
    });

    test('to a split quant in its own folder, naming its repo', () async {
      writeGguf(
        fileSystem,
        '/models/org/repo/Q8_0/big-Q8_0-00001-of-00002.gguf',
        fileType: 7,
      );
      writeGguf(
        fileSystem,
        '/models/org/repo/Q8_0/big-Q8_0-00002-of-00002.gguf',
        fileType: 7,
      );

      final model = (await scan(['/models'])).single;

      expect(
        (model.source as ScannedSource).inferredRepo!.repo,
        'org/repo',
      );
    });
  });

  test("cannot run a model whose template is not its family's", () async {
    writeGguf(
      fileSystem,
      '/models/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      architecture: 'qwen2',
      chatTemplate: deepSeekTemplate,
    );

    final model = (await scan(['/models'])).single as UnsupportedModel;

    expect(
      (model.reason as TemplateUnrecognized).architecture,
      'qwen2',
    );
  });

  test('skips adapters and LoRAs, keeping what says it is a model', () async {
    writeGguf(
      fileSystem,
      '/models/lora-Q8_0.gguf',
      extra: {'general.type': TestValue.string('adapter')},
    );
    writeGguf(
      fileSystem,
      '/models/model-Q4_K_M.gguf',
      extra: {'general.type': TestValue.string('model')},
    );

    final models = await scan(['/models']);

    expect(models.map((model) => model.path), ['/models/model-Q4_K_M.gguf']);
  });

  group('across scans', () {
    late ModelScanner scanner;

    setUp(() => scanner = ModelScanner(fileSystem: fileSystem));

    test('reuses what it read of a file that has not changed', () async {
      const path = '/models/a/model-Q4_K_M.gguf';
      writeGguf(fileSystem, path, name: 'Before');
      final modified = fileSystem.file(path).lastModifiedSync();
      await scanner.scan(['/models']);
      writeGguf(fileSystem, path, name: 'Aftr!!');
      fileSystem.file(path).setLastModifiedSync(modified);

      final again = (await scanner.scan(['/models/a'])).single;

      expect(again.displayName, 'Before');
      expect((again.source as ScannedSource).root, '/models/a');
    });

    test('reads a file again once it changes', () async {
      const path = '/models/model-Q4_K_M.gguf';
      writeGguf(fileSystem, path, name: 'Before');
      await scanner.scan(['/models']);
      writeGguf(fileSystem, path, name: 'Aftr!!');
      fileSystem
          .file(path)
          .setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));

      final again = (await scanner.scan(['/models'])).single;

      expect(again.displayName, 'Aftr!!');
    });

    test('reads a file again that could not be opened before', () async {
      late final MemoryFileSystem flaky;
      flaky = MemoryFileSystem.test(
        opHandle: (path, operation) {
          if (operation == FileSystemOp.open &&
              path == '/models/a.gguf' &&
              flaky.file('/busy').existsSync()) {
            throw FileSystemException('Busy', path);
          }
        },
      );
      writeGguf(flaky, '/models/a.gguf');
      flaky.file('/busy').createSync();
      final flakyScanner = ModelScanner(fileSystem: flaky);

      final first = (await flakyScanner.scan(['/models'])).single;
      flaky.file('/busy').deleteSync();
      final second = (await flakyScanner.scan(['/models'])).single;

      expect(first, isA<UnsupportedModel>());
      expect(second, isA<SupportedModel>());
    });
  });
}
