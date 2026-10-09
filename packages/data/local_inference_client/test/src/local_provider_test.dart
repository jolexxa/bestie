import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemCreateEvent, FileSystemEvent;

import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/local_provider.dart';
import 'package:local_inference_client/src/model_index_file.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

class MockFileSystem extends Mock implements FileSystem {}

class MockFile extends Mock implements File {}

class MockDirectory extends Mock implements Directory {}

void main() {
  const descriptor = ProviderDescriptor(
    id: 'local',
    displayName: 'Local models',
    requiresApiKey: false,
    dialect: InferenceDialect.bestie,
  );
  const request = ModelActivationRequest(
    modelId: 'qwen',
    contextWindow: 40960,
    maxAgents: 3,
  );

  ModelIndexEntry modelReasoning(String id, ModelReasoning reasoning) =>
      FakeServer.indexedModel.copyWith(
        localId: id,
        displayName: 'Model $id',
        reasoning: reasoning,
      );

  late FakeServer server;
  late LocalInferenceClient client;

  LocalProvider providerWith({int? contextCap, ModelIndexFile? index}) =>
      LocalProvider(
        link: client,
        index:
            index ??
            ModelIndexFile(
              fileSystem: server.fileSystem,
              path: FakeServer.indexFile,
            ),
        descriptor: descriptor,
        options: () => LocalProviderOptions(
          contextCap: contextCap,
        ),
      );

  setUp(() {
    server = FakeServer();
    client = server.client();
  });

  tearDown(() => client.close());

  test('is named by its descriptor', () {
    final provider = providerWith();

    expect(provider.id, 'local');
    expect(provider.displayName, 'Local models');
  });

  test('has neither credits nor key info', () async {
    final provider = providerWith();

    expect(await provider.credits(), isA<CreditsUnsupported>());
    expect(await provider.keyInfo(), isA<KeyInfoUnsupported>());
  });

  test('runs models over the OpenAI-compatible protocol', () {
    expect(providerWith().protocols, {InferenceProtocolId.openAiCompat});
  });

  group('models', () {
    test('lists the indexed models with their reasoning', () async {
      server.writeIndex([
        modelReasoning('none', const ModelReasoningNone()),
        modelReasoning('always', const ModelReasoningAlways()),
        modelReasoning('toggle', const ModelReasoningToggle()),
        modelReasoning(
          'medium',
          const ModelReasoningEfforts(efforts: ['low', 'medium', 'high']),
        ),
        modelReasoning(
          'cheap',
          const ModelReasoningEfforts(efforts: ['low', 'high']),
        ),
      ]);

      final listed = await providerWith().models() as ProviderModelsListed;

      final models = listed.models;
      expect(models.map((model) => model.id), [
        'none',
        'always',
        'toggle',
        'medium',
        'cheap',
      ]);
      expect(models.first.name, 'Model none');
      expect(models.first.contextLength, 40960);
      expect(models.first.supportsTools, isTrue);
      expect(models[0].reasoning, isNull);
      expect(models[1].reasoning, isA<ProviderReasoningFixed>());
      expect(
        (models[2].reasoning! as ProviderReasoningToggle).enabledByDefault,
        isTrue,
      );
      final medium = models[3].reasoning! as ProviderReasoningEfforts;
      expect(medium.efforts, ['low', 'medium', 'high']);
      expect(medium.canDisable, isFalse);
      expect(medium.defaultEffort, 'medium');
      expect(
        (models[4].reasoning! as ProviderReasoningEfforts).defaultEffort,
        'low',
      );
    });

    test('are listed without finding or starting the server', () async {
      server.removeLock();

      final listed = await providerWith().models() as ProviderModelsListed;

      expect(listed.models.single.id, 'qwen');
      expect(server.requests, isEmpty);
      verifyNever(() => server.spawner.spawn(any(), any()));
    });

    test('are none before the index exists', () async {
      server.fileSystem.file(FakeServer.indexFile).deleteSync();

      final listed = await providerWith().models() as ProviderModelsListed;

      expect(listed.models, isEmpty);
    });

    test('leave out entries this version cannot load', () async {
      server.fileSystem
          .file(FakeServer.indexFile)
          .writeAsStringSync(
            jsonEncode({
              'version': ModelIndex.currentVersion,
              'models': [
                FakeServer.indexedModel.toMap()..['profile_id'] = 'llama2',
              ],
            }),
          );

      final listed = await providerWith().models() as ProviderModelsListed;

      expect(listed.models, isEmpty);
    });

    test('fail when the index is damaged', () async {
      server.fileSystem.file(FakeServer.indexFile).writeAsStringSync('{');

      final listed = await providerWith().models() as ProviderModelsFailed;

      expect(listed.failure.kind, InferenceFailureKind.malformedResponse);
      expect(listed.failure.message, startsWith('The model index is damaged:'));
    });

    test('fail when the index cannot be read', () async {
      server.fileSystem.file(FakeServer.indexFile).writeAsBytesSync([0xff]);

      final listed = await providerWith().models() as ProviderModelsFailed;

      expect(
        listed.failure.message,
        startsWith("The model index can't be read:"),
      );
    });

    test('change whenever the index is written', () async {
      final fileSystem = MockFileSystem();
      final file = MockFile();
      final folder = MockDirectory();
      final events = StreamController<FileSystemEvent>();
      when(() => fileSystem.file(FakeServer.indexFile)).thenReturn(file);
      when(() => file.parent).thenReturn(folder);
      when(() => folder.createSync(recursive: true)).thenReturn(null);
      when(folder.watch).thenAnswer((_) => events.stream);
      final provider = providerWith(
        index: ModelIndexFile(
          fileSystem: fileSystem,
          path: FakeServer.indexFile,
        ),
      );
      var changes = 0;
      final watching = provider.modelsChanged.listen((_) => changes++);

      events.add(FileSystemCreateEvent(FakeServer.indexFile, false));
      await pumpEventQueue();
      await watching.cancel();

      expect(changes, 1);
    });
  });

  group('activate', () {
    test('loads the model, reporting its progress', () async {
      server.loadAnswer = (load) async {
        server
          ..emit(
            const ModelStatusEvent(
              status: ModelLoading(localId: 'other', progress: 0.9),
            ),
          )
          ..emit(
            const ModelStatusEvent(
              status: ModelLoading(localId: 'qwen', progress: 0.25),
            ),
          )
          ..emit(
            const ModelStatusEvent(
              status: ModelLoading(localId: 'qwen', progress: 0.75),
            ),
          );
        await pumpEventQueue();
        return http.Response(
          const ModelReady(
            localId: 'qwen',
            contextSize: 16384,
            maxAgents: 3,
            deviceBytes: 1,
          ).toJson(),
          200,
        );
      };
      final provider = providerWith(contextCap: 16384);

      final activation = provider.activate(request);
      final progress = activation.progress.toList();
      final activated = await activation.result;
      await pumpEventQueue();

      expect((activated as ModelActivated).contextWindow, 16384);
      expect(
        activated.endpoint,
        InferenceEndpoint(
          baseUrl: ServerApi.urlFor(4100, '/v1'),
          headers: const {bestieOwnerHeader: 'token-1'},
          dialect: InferenceDialect.bestie,
        ),
      );
      expect(await progress, [0.25, 0.75]);
      final load = ModelLoadRequestMapper.fromJson(
        server.requests
            .firstWhere((sent) => sent.url.path == bestieModelPath)
            .body,
      );
      expect(
        load,
        const ModelLoadRequest(
          localId: 'qwen',
          maxAgents: 3,
          contextCap: 16384,
        ),
      );
    });

    test(
      'is lost when the server ends the session, and activating again '
      'follows the restarted server',
      () async {
        final provider = providerWith();
        final first = provider.activate(request);
        await first.result;
        var lost = false;
        unawaited(first.lost.then((_) => lost = true));
        await pumpEventQueue();
        expect(lost, isFalse);

        server
          ..port = 4200
          ..lockOn(4200);
        await server.endSession();
        await pumpEventQueue();
        expect(lost, isTrue);

        final second = await provider.activate(request).result;
        final endpoint = (second as ModelActivated).endpoint;
        expect(endpoint.baseUrl, ServerApi.urlFor(4200, '/v1'));
        expect(endpoint.headers, {bestieOwnerHeader: 'token-2'});
      },
    );

    test('is lost when the provider lets go of the server', () async {
      final provider = providerWith();
      final activation = provider.activate(request);
      await activation.result;

      await provider.deactivate();

      await expectLater(activation.lost, completes);
    });

    test('runs with the options set when it is activated', () async {
      var contextCap = 4096;
      final provider = LocalProvider(
        link: client,
        index: ModelIndexFile(
          fileSystem: server.fileSystem,
          path: FakeServer.indexFile,
        ),
        descriptor: descriptor,
        options: () => LocalProviderOptions(
          contextCap: contextCap,
        ),
      );
      contextCap = 2048;

      await provider.activate(request).result;

      final load = ModelLoadRequestMapper.fromJson(
        server.requests
            .firstWhere((sent) => sent.url.path == bestieModelPath)
            .body,
      );
      expect(load.contextCap, 2048);
    });

    test('fails when the model does not load', () async {
      server.loadAnswer = (_) => http.Response('', 500);

      final activation = providerWith().activate(request);
      final activated = await activation.result as ModelActivationFailed;

      expect(activated.failure.kind, InferenceFailureKind.server);
      expect(
        activated.failure.message,
        'The local model server answered HTTP 500.',
      );
      expect(await activation.progress.toList(), isEmpty);
    });

    test('fails when the server is owned by another bestie', () async {
      server.busyOwner = 12;

      final activation = providerWith().activate(request);
      final activated = await activation.result as ModelActivationFailed;

      expect(
        activated.failure.message,
        'Another bestie (pid 12) is using Bestie Server. '
        'Close it to use it here.',
      );
      expect(await activation.progress.toList(), isEmpty);
    });
  });

  test('explains every connection activation cannot go on from', () {
    String messageFor(LocalServerConnection connection) =>
        LocalProvider.failureFor(connection).message;

    expect(
      messageFor(const LocalServerBusy(ownerPid: 12)),
      'Another bestie (pid 12) is using Bestie Server. '
      'Close it to use it here.',
    );
    expect(
      messageFor(
        const LocalServerVersionMismatch(
          protocolVersion: 2,
          serverVersion: '0.2.0',
        ),
      ),
      'The running local model server speaks protocol 2; this bestie speaks '
      '$bestieProtocolVersion. It exits once its owner closes and it sits '
      'idle.',
    );
    expect(
      messageFor(const LocalServerSpawnFailed(reason: 'missing')),
      'Could not start the local model server: missing',
    );
    expect(
      messageFor(const LocalServerDisconnected(reason: 'reset')),
      'reset',
    );
    for (final unexplained in const <LocalServerConnection>[
      LocalServerDisconnected(),
      LocalServerAttaching(),
      LocalServerAttached(ownerToken: 'token', port: 4100),
    ]) {
      expect(
        messageFor(unexplained),
        'The local model server is not connected.',
      );
    }
    expect(
      LocalProvider.failureFor(const LocalServerAttaching()).kind,
      InferenceFailureKind.server,
    );
  });

  test('lets go of the server when deactivated', () async {
    final provider = providerWith();
    await provider.activate(request).result;

    await provider.deactivate();

    expect(client.connection, isA<LocalServerDisconnected>());
    expect(server.callsTo(bestieModelPath).last, 'DELETE $bestieModelPath');
  });

  test('opens agent sessions over the owner session', () {
    expect(
      providerWith().openSessions(contextWindow: 8192),
      isA<AgentSessions>(),
    );
  });
}
