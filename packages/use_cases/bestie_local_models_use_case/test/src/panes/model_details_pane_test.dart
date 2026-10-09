import 'package:bestie_local_models_use_case/src/panes/model_details_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  late MockLocalModelsOperations operations;
  final ready = serving();

  void showing(
    ModelLibrary library, {
    String? running,
    LocalServerStatus server = const ServerStarting(),
  }) => stubOperations(
    operations,
    currentLibrary: library,
    inUseId: running,
    server: Stream.value(server),
  );

  setUp(() => operations = MockLocalModelsOperations());

  ModelDetailsPane pane([String localId = 'qwen3-8b']) =>
      ModelDetailsPane(operations: operations, localId: localId);

  Map<String, String> factsOf(PaneContent content) => {
    for (final row in content.rows) row.label: spansText(row.cells.single),
  };

  test('is titled by the model, or its id once it is gone', () {
    showing(ModelLibrary(downloaded: [supportedModel()]));
    expect(pane().title, 'Qwen 3 8B');
    expect(pane('gone').title, 'gone');
    expect(pane().filter, PaneFilter.none);
  });

  test('lists everything bestie read from a runnable GGUF', () async {
    showing(ModelLibrary(downloaded: [supportedModel()]));
    final content = await pane().content('').first;
    expect(content.sections.single.columns.first.width, 16);
    expect(factsOf(content), {
      'Name': 'Qwen 3 8B',
      'File': '~/.bestie/models/qwen3-8b-q4_k_m.gguf',
      'Source': 'Hugging Face · lmstudio-community/Qwen3-8B-GGUF',
      'Architecture': 'qwen3 → Qwen 3 prompt format',
      'Parameters': '8.2B',
      'Quant': 'Q4_K_M · 4.68 GB',
      'Trained context': '40,960 tokens',
      'Reasoning': 'On by default · can be turned off',
      'Sampling': 'temp 0.6 · top_p 0.95 · top_k 20 (from the GGUF)',
      'Fingerprint': '3fa9c2d1',
    });
  });

  test('leaves out what the GGUF does not say', () async {
    showing(
      ModelLibrary(
        inFolders: [
          supportedModel(
            parameterCount: null,
            sampling: const ModelSamplingDefaults(),
            source: const ScannedSource(root: '$homeDir/models'),
          ),
        ],
      ),
    );
    final facts = factsOf(await pane().content('').first);
    expect(facts.keys, isNot(contains('Parameters')));
    expect(facts.keys, isNot(contains('Sampling')));
    expect(facts['Source'], 'Your folder · ~/models');
  });

  test('says a hand-placed file was not downloaded by bestie', () async {
    showing(
      ModelLibrary(
        inFolders: [
          supportedModel(
            source: const UntrackedSource(root: '$homeDir/.bestie/models'),
          ),
        ],
      ),
    );
    expect(
      factsOf(await pane().content('').first)['Source'],
      "Bestie's models folder · not downloaded by bestie",
    );
  });

  test('says why an unsupported GGUF cannot run', () async {
    showing(ModelLibrary(inFolders: [unsupportedModel()]));
    final facts = factsOf(await pane('granite').content('').first);
    expect(facts, {
      'Name': 'granite-4.0-h-micro',
      'File': '~/models/granite-4.0-h-micro.gguf',
      'Source': 'Your folder · ~/models',
      'Size': '1.97 GB',
      'Problem': 'Not supported yet: granitehybrid architecture',
      'Fingerprint': '77aa0011',
    });
  });

  test('every row offers using and deleting the model, not details', () async {
    showing(ModelLibrary(downloaded: [supportedModel()]));
    final content = await pane().content('').first;
    for (final row in content.rows) {
      expect(actionLabels(row), ['Use this model', 'Delete']);
    }
  });

  test('a model in use can only be deleted from its details', () async {
    showing(ModelLibrary(downloaded: [supportedModel()]), running: 'qwen3-8b');
    final content = await pane().content('').first;
    expect(content.rows.first.actions.map((action) => action.label), [
      'Delete',
    ]);
  });

  test('says when the model has left the library', () async {
    showing(readyLibrary);
    final content = await pane().content('').first;
    expect(content.rows, isEmpty);
    expect(content.sections.single.notes.map(noteText), [
      '',
      'This model is no longer in the library.',
    ]);
  });

  group('band', () {
    test('is empty for a model not in use', () async {
      showing(ModelLibrary(downloaded: [supportedModel()]), server: ready);
      expect(await pane().status.first, isNull);
    });

    test('says how the server fitted the model in use', () async {
      showing(
        ModelLibrary(downloaded: [supportedModel()]),
        running: 'qwen3-8b',
        server: ready,
      );
      final band = await pane().status.first;
      expect(band!.glyph, '●');
      expect(
        spansText(band.spans),
        'In use · fitted to ctx 32,768 with 4 agents · 6.10 GB on the device',
      );
    });

    test('just says in use while the server serves another model', () async {
      showing(
        ModelLibrary(downloaded: [supportedModel()]),
        running: 'qwen3-8b',
        server: serving(localId: 'other'),
      );
      expect(spansText((await pane().status.first)!.spans), 'In use');
    });

    test('just says in use until the server has it ready', () async {
      showing(
        ModelLibrary(downloaded: [supportedModel()]),
        running: 'qwen3-8b',
        server: const ServerLoading(localId: 'qwen3-8b', progress: 0.5),
      );
      expect(spansText((await pane().status.first)!.spans), 'In use');
    });
  });
}
