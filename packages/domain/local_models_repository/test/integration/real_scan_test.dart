@Tags(['integration'])
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Scans `$BESTIE_GGUF_DIR` (default `~/Dropbox/AI/models`) as a user folder
/// and prints every entry. Run with `dart test --run-skipped -t integration`.
void main() {
  final home = Platform.environment['HOME'] ?? '';
  final folder =
      Platform.environment['BESTIE_GGUF_DIR'] ?? '$home/Dropbox/AI/models';

  test(
    'scans a real models folder',
    skip: 'Reads local model files; run with --run-skipped.',
    () async {
      final modelsDir = Directory.systemTemp.createTempSync('bestie-models');
      addTearDown(() => modelsDir.deleteSync(recursive: true));
      final client = http.Client();
      addTearDown(client.close);
      final repository = LocalModelsRepository(
        modelsDir: modelsDir.path,
        hub: HubClient(client: client),
        downloader: ModelDownloader(),
        indexStore: ModelIndexStore(
          path: p.join(modelsDir.path, ModelIndex.fileName),
        ),
        ledgerStore: DownloadLedgerStore(
          path: p.join(modelsDir.path, DownloadLedger.fileName),
        ),
        folders: [folder],
      );
      addTearDown(repository.dispose);

      final stopwatch = Stopwatch()..start();
      await repository.start();
      stopwatch.stop();
      final library = repository.current;

      expect(library.inFolders, isNotEmpty);
      stdout.writeln(
        'Scanned ${library.inFolders.length} GGUFs in '
        '${stopwatch.elapsedMilliseconds} ms\n',
      );
      for (final model in library.inFolders) {
        stdout.writeln(_describe(model));
      }
      final index = ModelIndexMapper.fromJson(
        File(p.join(modelsDir.path, ModelIndex.fileName)).readAsStringSync(),
      );
      stdout.writeln('\nindex.json lists ${index.models.length} models');
      expect(index.models, hasLength(library.runnable.length));
    },
  );
}

String _describe(LocalModel model) => switch (model) {
  SupportedModel() =>
    '✓ ${model.id}\n'
        '    ${model.displayName} · ${model.architecture} → '
        '${model.profile.name} · ${model.quant.label} '
        '(${model.quant.tier.name}) · ctx ${model.contextLength} · '
        'reasoning ${_reasoning(model.reasoning)}',
  UnsupportedModel() =>
    '⊘ ${model.id}\n'
        '    ${model.displayName} · ${_why(model.reason)}',
};

String _why(UnsupportedReason reason) => switch (reason) {
  ArchitectureUnsupported(:final architecture) =>
    'architecture $architecture is not supported',
  TemplateUnrecognized(:final architecture) =>
    "template is not the $architecture family's",
  NotAChatModel(:final task) => 'a $task model, not a chat model',
  QuantUnsupported(:final fileType) => 'file type $fileType is not supported',
  MetadataMissing(:final key) => 'missing $key',
  HeaderUnreadable(:final reason) => 'unreadable header: $reason',
  ShardsMissing(:final found, :final expected) =>
    'only $found of $expected shards',
};

String _reasoning(ModelReasoning reasoning) => switch (reasoning) {
  ModelReasoningNone() => 'none',
  ModelReasoningToggle() => 'toggle',
  ModelReasoningAlways() => 'always',
  ModelReasoningEfforts(:final efforts) => 'efforts ${efforts.join('/')}',
};
