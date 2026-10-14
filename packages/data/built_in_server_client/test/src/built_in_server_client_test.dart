import 'dart:async';
import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:built_in_server_client/src/bestie_server_dialect.dart';
import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/model_load_options.dart';
import 'package:built_in_server_client/src/server_api.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

void main() {
  const qwen = ProviderModelLoadRequest(
    modelId: 'qwen',
    contextWindow: 40960,
    maxAgents: 3,
  );
  const capped = ModelLoadOptions(contextCap: 16384);
  const primary = AgentIdentity(
    id: 'primary:1',
    kind: AgentIdentityKind.primary,
  );
  const subagent = AgentIdentity(
    id: 'subagent:2',
    kind: AgentIdentityKind.subagent,
  );
  final primaryPath = bestieAgentPath(primary.id);
  final subagentPath = bestieAgentPath(subagent.id);

  ModelIndexEntry modelReasoning(String id, ModelReasoning reasoning) =>
      FakeServer.indexedModel.copyWith(
        localId: id,
        displayName: 'Model $id',
        reasoning: reasoning,
      );

  late FakeServer server;
  late BuiltInServerClient connection;

  Future<ProviderModel> loaded([
    ProviderModelLoadRequest request = qwen,
  ]) async =>
      (await connection.load(request).result as ProviderModelLoaded).model;

  Future<ProviderFailure> failed([
    ProviderModelLoadRequest request = qwen,
  ]) async => (await connection.load(request).result as ProviderModelLoadFailed)
      .failure;

  Future<void> serving(ProviderModel model) async {
    server.emit(
      ModelStatusEvent(
        status: ModelReady(
          localId: 'qwen',
          contextSize: model.contextWindow,
          maxAgents: model.maxAgents,
          deviceBytes: model.deviceBytes!,
        ),
      ),
    );
    await pumpEventQueue();
  }

  OpenAiCompletionClient clientOf(ProviderModel model) =>
      (model.runtime as CompletionAgentRuntime).client
          as OpenAiCompletionClient;

  String? ownerTokenOf(ProviderModel model) =>
      clientOf(model).headers[bestieOwnerHeader];

  setUp(() {
    server = FakeServer();
    connection = server.client();
  });

  tearDown(() => connection.close());

  test('is named for the palette and always ready', () {
    expect(connection.id, 'local');
    expect(connection.displayName, 'Built-in server');
    expect(connection.availability, const ProviderReady());
  });

  test('has no credits', () async {
    expect(await connection.credits(), isA<CreditsUnsupported>());
  });

  group('configure', () {
    test('reports each change, and only changes', () async {
      final reported = <ProviderAvailability>[];
      final listening = connection.reconfigured.listen(reported.add);

      connection
        ..configure(capped)
        ..configure(capped)
        ..configure(ModelLoadOptions.defaults);
      await pumpEventQueue();

      expect(reported, const [ProviderReady(), ProviderReady()]);
      await listening.cancel();
    });

    test('caps every load from then on', () async {
      await serving(await loaded());

      connection.configure(capped);
      await loaded();

      expect(
        [
          for (final sent in server.requests)
            if (sent.url.path == bestieModelPath && sent.method == 'POST')
              ModelLoadRequestMapper.fromJson(sent.body).contextCap,
        ],
        [null, 16384],
      );
    });
  });

  group('attach', () {
    Future<List<BuiltInServerConnection>> changesDuring(
      Future<void> Function() act,
    ) async {
      final changes = <BuiltInServerConnection>[];
      final listening = connection.connectionChanges.listen(changes.add);
      await act();
      await pumpEventQueue();
      await listening.cancel();
      return changes;
    }

    test('holds the owner session and tells where that left things', () async {
      final changes = await changesDuring(() async {
        expect(
          await connection.attach(),
          isA<BuiltInServerAttached>().having(
            (attached) => attached.ownerToken,
            'ownerToken',
            'token-1',
          ),
        );
      });

      expect(changes, [
        isA<BuiltInServerAttaching>(),
        isA<BuiltInServerAttached>(),
      ]);
    });

    test('reports a server another bestie holds', () async {
      server.busyOwner = 12;

      final changes = await changesDuring(() async {
        expect(await connection.attach(), isA<BuiltInServerBusy>());
      });

      expect(changes, [
        isA<BuiltInServerAttaching>(),
        isA<BuiltInServerBusy>().having(
          (busy) => busy.ownerPid,
          'ownerPid',
          12,
        ),
      ]);
    });

    test('reports the server ending the session', () async {
      await connection.attach();

      final changes = await changesDuring(server.endSession);

      expect(changes, [isA<BuiltInServerDisconnected>()]);
    });

    test('reports a release and a close', () async {
      await connection.attach();

      final releasing = await changesDuring(connection.release);
      await connection.attach();
      final closing = await changesDuring(connection.close);

      expect(releasing, [isA<BuiltInServerDisconnected>()]);
      expect(closing, [isA<BuiltInServerDisconnected>()]);
    });

    test('streams the model status the session reports', () async {
      await connection.attach();
      final statuses = <ModelStatus>[];
      final listening = connection.modelStatusChanges.listen(statuses.add);

      server.emit(const ModelStatusEvent(status: ModelFitting(localId: 'q')));
      await pumpEventQueue();
      await listening.cancel();

      expect(statuses, const [ModelFitting(localId: 'q')]);
    });
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

      final listed = await connection.models() as ProviderModelsListed;

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

      final listed = await connection.models() as ProviderModelsListed;

      expect(listed.models.single.id, 'qwen');
      expect(server.requests, isEmpty);
      verifyNever(() => server.spawner.spawn(any(), any()));
    });

    test('are none before the index exists', () async {
      server.fileSystem.file(FakeServer.indexFile).deleteSync();

      final listed = await connection.models() as ProviderModelsListed;

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

      final listed = await connection.models() as ProviderModelsListed;

      expect(listed.models, isEmpty);
    });

    test('fail when the index is damaged', () async {
      server.fileSystem.file(FakeServer.indexFile).writeAsStringSync('{');

      final listed = await connection.models() as ProviderModelsFailed;

      expect(listed.failure, isA<ProviderResponseMalformed>());
      expect(listed.failure.message, startsWith('The model index is damaged:'));
    });

    test('fail when the index cannot be read', () async {
      server.fileSystem.file(FakeServer.indexFile).writeAsBytesSync([0xff]);

      final listed = await connection.models() as ProviderModelsFailed;

      expect(
        listed.failure.message,
        startsWith("The model index can't be read:"),
      );
    });
  });

  group('load', () {
    test('finds the server, takes the owner session and loads the model, '
        'reporting its progress', () async {
      server.loadAnswer = (load) async {
        server
          ..emit(
            const ModelStatusEvent(status: ModelFitting(localId: 'other')),
          )
          ..emit(const ModelStatusEvent(status: ModelFitting(localId: 'qwen')))
          ..emit(
            const ModelStatusEvent(
              status: ModelLoading(localId: 'other', progress: 0.9),
            ),
          )
          ..emit(
            const ModelStatusEvent(
              status: ModelLoading(localId: 'qwen', progress: 0.25),
            ),
          );
        await pumpEventQueue();
        return http.Response(
          const ModelReady(
            localId: 'qwen',
            contextSize: 16384,
            maxAgents: 3,
            deviceBytes: 7,
          ).toJson(),
          200,
        );
      };

      connection.configure(capped);
      final load = connection.load(qwen);
      final progress = load.progress.toList();
      final model = (await load.result as ProviderModelLoaded).model;

      expect(await progress, const [
        ProviderModelMeasuring(),
        ProviderModelLoading(0.25),
      ]);
      expect(model.contextWindow, 16384);
      expect(model.maxAgents, 3);
      expect(model.deviceBytes, 7);
      final runtime = model.runtime as CompletionAgentRuntime;
      expect(runtime.options.modelId, 'qwen');
      expect(runtime.options.contextWindow, 16384);
      expect(runtime.options.maxAgents, 3);
      final client = clientOf(model);
      expect(client.baseUrl, ServerApi.urlFor(4100, '/v1'));
      expect(client.headers, {bestieOwnerHeader: 'token-1'});
      expect(client.dialect, isA<BestieServerDialect>());
      expect(
        ModelLoadRequestMapper.fromJson(
          server.requests
              .firstWhere((sent) => sent.url.path == bestieModelPath)
              .body,
        ),
        const ModelLoadRequest(
          localId: 'qwen',
          maxAgents: 3,
          contextCap: 16384,
        ),
      );
    });

    test('keeps the session it holds', () async {
      await loaded();

      expect(ownerTokenOf(await loaded()), 'token-1');
      expect(server.sessions, hasLength(1));
    });

    test('shares one attempt between concurrent loads', () async {
      final models = await Future.wait<ProviderModel>([loaded(), loaded()]);

      expect(models.map(ownerTokenOf), ['token-1', 'token-1']);
      expect(server.sessions, hasLength(1));
    });

    test('ignores a repeated opening of the session', () async {
      await loaded();

      server.emit(const SessionOpened(ownerToken: 'other'));
      await pumpEventQueue();

      expect(ownerTokenOf(await loaded()), 'token-1');
    });

    test('keeps a model that already serves the same request', () async {
      await serving(await loaded());

      await loaded();

      expect(server.callsTo(bestieModelPath), ['POST $bestieModelPath']);
    });

    test('reloads for a different request', () async {
      await serving(await loaded());

      await loaded(
        const ProviderModelLoadRequest(
          modelId: 'qwen',
          contextWindow: 40960,
          maxAgents: 1,
        ),
      );

      expect(server.callsTo(bestieModelPath), hasLength(2));
    });

    test('fails when the model does not load, keeping the server', () async {
      server.loadAnswer = (_) => http.Response('', 500);

      expect(
        await failed(),
        const ProviderServerFailed(
          'The local model server answered HTTP 500.',
        ),
      );
      expect(server.sessions.single.hasListener, isTrue);
    });

    test('loads on the same session after a failed load', () async {
      server.loadAnswer = (_) => http.Response('', 500);
      await failed();
      server.loadAnswer = null;

      expect(ownerTokenOf(await loaded()), 'token-1');
    });

    test('fails when another bestie owns the server', () async {
      server.busyOwner = 12;

      final load = connection.load(qwen);

      expect(
        (await load.result as ProviderModelLoadFailed).failure.message,
        bestieServerBusyMessage(12),
      );
      expect(await load.progress.toList(), isEmpty);
    });

    test('tries again after a refusal', () async {
      server.busyOwner = 12;
      await failed();
      server.busyOwner = null;

      expect(ownerTokenOf(await loaded()), 'token-1');
    });

    test('fails when the server will not open a session', () async {
      server.sessionStatus = 500;

      expect(
        (await failed()).message,
        'The local model server answered the session with HTTP 500.',
      );
    });

    test('looks again when the server shuts down as it is asked', () async {
      server.sessionsShuttingDown = 2;

      await loaded();

      expect(server.callsTo(bestieHealthPath), hasLength(3));
    });

    test('gives up once three servers in a row shut down', () async {
      server.sessionsShuttingDown = 3;

      expect((await failed()).message, 'The server is shutting down.');
      expect(server.callsTo(bestieHealthPath), hasLength(3));
    });

    test('fails when the server speaks another protocol', () async {
      server.protocolVersion = 99;

      expect(
        (await failed()).message,
        startsWith('The running local model server speaks protocol 99;'),
      );
    });

    test('fails when the server cannot be started', () async {
      server.removeLock();

      expect(
        (await failed()).message,
        'Could not start the local model server: not here',
      );
      verify(() => server.spawner.spawn('bestie_server', any())).called(1);
    });
  });

  group('a loaded model', () {
    test('is lost when the server ends the session, and loading again '
        'follows the restarted server', () async {
      final first = await loaded();
      var lost = false;
      unawaited(first.lost.then((_) => lost = true));
      server.emit(const ModelStatusEvent(status: ModelUnloaded()));
      await pumpEventQueue();
      expect(lost, isFalse);

      server
        ..port = 4200
        ..lockOn(4200);
      await server.endSession();
      await pumpEventQueue();
      expect(lost, isTrue);

      final second = await loaded();
      final client = clientOf(second);
      expect(client.baseUrl, ServerApi.urlFor(4200, '/v1'));
      expect(ownerTokenOf(second), 'token-2');
    });

    test('is lost once the connection closes', () async {
      final model = await loaded();

      await connection.close();

      await expectLater(model.lost, completes);
    });

    test('unloads the model and keeps the server when released', () async {
      final model = await loaded();
      var lost = false;
      unawaited(model.lost.then((_) => lost = true));

      await model.release();

      expect(server.callsTo(bestieModelPath).last, 'DELETE $bestieModelPath');
      expect(server.sessions.single.hasListener, isTrue);
      expect(lost, isFalse);
    });

    test('leaves the model to a newer load when released', () async {
      final first = await loaded();
      final second = await loaded(
        const ProviderModelLoadRequest(
          modelId: 'qwen',
          contextWindow: 40960,
          maxAgents: 1,
        ),
      );

      await first.release();

      expect(server.callsTo(bestieModelPath), everyElement(startsWith('POST')));
      await second.release();
      expect(server.callsTo(bestieModelPath).last, 'DELETE $bestieModelPath');
    });

    test('is loaded again on the same session after a release', () async {
      await serving(await loaded());
      await (await loaded()).release();

      expect(ownerTokenOf(await loaded()), 'token-1');
      expect(server.callsTo(bestieModelPath), [
        'POST $bestieModelPath',
        'DELETE $bestieModelPath',
        'POST $bestieModelPath',
      ]);
    });

    test('is unloaded without a request once the session ended', () async {
      final model = await loaded();
      await server.endSession();
      await pumpEventQueue();

      await model.release();

      expect(server.callsTo(bestieModelPath), ['POST $bestieModelPath']);
    });
  });

  group('releasing the server', () {
    test('does nothing before any attach', () async {
      await connection.release();

      expect(server.requests, isEmpty);
    });

    test('abandons an attach in flight and hangs up what it took', () async {
      final load = connection.load(qwen);
      await connection.release();

      expect(await load.result, isA<ProviderModelLoadFailed>());
      expect(server.sessions.single.hasListener, isFalse);
    });

    test('lets a later load take a new session', () async {
      final first = connection.load(qwen);
      final releasing = connection.release();
      final second = connection.load(qwen);

      expect(await first.result, isA<ProviderModelLoadFailed>());
      await releasing;
      final model = (await second.result as ProviderModelLoaded).model;

      expect(ownerTokenOf(model), 'token-2');
      expect(server.sessions.first.hasListener, isFalse);
      expect(server.sessions.last.hasListener, isTrue);
    });

    test('drops loads asked for before a later release', () async {
      await loaded();
      final releasing = connection.release();
      final dropped = connection.load(qwen);
      final releasingAgain = connection.release();

      expect(await dropped.result, isA<ProviderModelLoadFailed>());
      await Future.wait<void>([releasing, releasingAgain]);

      expect(server.sessions, hasLength(1));
    });
  });

  group('owner session', () {
    test('reports the pool snapshots it streams', () async {
      await loaded();
      final snapshots = connection.poolSnapshots.toList();
      const snapshot = PoolSnapshotEvent(
        contextSize: 8192,
        maxAgents: 3,
        agents: [],
      );

      server.emit(snapshot);
      await pumpEventQueue();
      await connection.close();

      expect(await snapshots, [snapshot]);
    });

    test('forgets its leases when the server ends it', () async {
      await loaded();
      final holder = Object();
      await connection.openLease(holder, primary);

      await server.endSession();
      await pumpEventQueue();
      await loaded();
      await connection.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('tells when this bestie stops holding the server', () async {
      await expectLater(connection.untilDetached(), completes);

      await loaded();
      var detached = false;
      unawaited(connection.untilDetached().then((_) => detached = true));
      await pumpEventQueue();
      expect(detached, isFalse);

      await server.endSession();
      await pumpEventQueue();
      expect(detached, isTrue);
    });
  });

  group('leases', () {
    final holder = Object();
    final other = Object();

    test('need the owner session', () async {
      final opened = await connection.openLease(holder, primary);

      expect(
        (opened as AgentSessionFailed).message,
        'This bestie does not hold the local server.',
      );
    });

    test('open and close for the holder', () async {
      await loaded();

      expect(
        await connection.openLease(holder, primary),
        isA<AgentSessionOpened>(),
      );
      await connection.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'DELETE $primaryPath',
      ]);
    });

    test('are not closed by a holder that does not hold them', () async {
      await loaded();
      await connection.openLease(holder, primary);

      await connection.closeLease(other, primary.id);

      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('taken over by another holder are closed first', () async {
      await loaded();
      await connection.openLease(holder, primary);

      await connection.openLease(other, primary);
      await connection.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'DELETE $primaryPath',
        'POST $primaryPath',
      ]);
    });

    test('reopened by the same holder are not closed first', () async {
      await loaded();
      await connection.openLease(holder, primary);

      await connection.openLease(holder, primary);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'POST $primaryPath',
      ]);
    });

    test('that were refused are not held', () async {
      await loaded();
      server.leaseAnswer = (_) => const AgentNoCapacity();

      expect(
        await connection.openLease(holder, subagent),
        isA<AgentSessionNoCapacity>(),
      );
      await connection.closeLease(holder, subagent.id);

      expect(server.callsTo(subagentPath), ['POST $subagentPath']);
    });

    test('are all released for their holder', () async {
      await loaded();
      await connection.openLease(holder, primary);
      await connection.openLease(holder, subagent);
      await connection.openLease(
        other,
        const AgentIdentity(id: 'primary:9', kind: AgentIdentityKind.primary),
      );

      await connection.releaseLeases(holder);

      expect(server.callsTo(primaryPath).last, 'DELETE $primaryPath');
      expect(server.callsTo(subagentPath).last, 'DELETE $subagentPath');
      expect(server.callsTo(bestieAgentPath('primary:9')), [
        'POST ${bestieAgentPath('primary:9')}',
      ]);
    });

    test('are forgotten without a request once detached', () async {
      await loaded();
      await connection.openLease(holder, primary);
      server.busyOwner = 12;
      await server.endSession();
      await pumpEventQueue();

      await connection.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('keep their order when one fails', () async {
      await loaded();
      server.leaseAnswer = (_) => throw StateError('boom');

      final results = await Future.wait([
        connection.openLease(holder, primary),
        connection.openLease(holder, subagent),
      ]);

      expect(results, everyElement(isA<AgentSessionFailed>()));
    });
  });

  group('close', () {
    test('hangs up the owner session', () async {
      await loaded();

      await connection.close();

      expect(server.sessions.single.hasListener, isFalse);
    });

    test('works without a session', () async {
      await connection.close();

      expect(server.requests, isEmpty);
    });

    test('hangs up a session taken while closing', () async {
      final load = connection.load(qwen);

      await connection.close();

      expect(await load.result, isA<ProviderModelLoadFailed>());
      expect(server.sessions.single.hasListener, isFalse);
    });

    test('waits for a release under way', () async {
      await loaded();
      final releasing = connection.release();

      await connection.close();
      await releasing;

      expect(server.callsTo(bestieModelPath), [
        'POST $bestieModelPath',
        'DELETE $bestieModelPath',
      ]);
      expect(server.sessions.single.hasListener, isFalse);
    });

    test('happens once however often it is asked for', () async {
      await loaded();

      expect(identical(connection.close(), connection.close()), isTrue);
    });

    test('leaves the connection unable to load or release again', () async {
      await connection.close();

      expect(
        await failed(),
        BuiltInServerClient.failureFor(
          const BuiltInServerDisconnected(),
        ),
      );
      await connection.release();
      expect(server.sessions, isEmpty);
    });
  });

  test('explains every connection loading cannot go on from', () {
    String messageFor(BuiltInServerConnection connection) =>
        BuiltInServerClient.failureFor(connection).message;

    expect(
      messageFor(const BuiltInServerBusy(ownerPid: 12)),
      'Another bestie (pid 12) is using Bestie Server. '
      'Close it to use it here.',
    );
    expect(
      messageFor(
        const BuiltInServerVersionMismatch(
          protocolVersion: 2,
          serverVersion: '0.2.0',
        ),
      ),
      'The running local model server speaks protocol 2; this bestie speaks '
      '$bestieProtocolVersion. It exits once its owner closes and it sits '
      'idle.',
    );
    expect(
      messageFor(const BuiltInServerSpawnFailed(reason: 'missing')),
      'Could not start the local model server: missing',
    );
    expect(
      messageFor(const BuiltInServerDisconnected(reason: 'reset')),
      'reset',
    );
    for (final unexplained in const <BuiltInServerConnection>[
      BuiltInServerDisconnected(),
      BuiltInServerAttaching(),
      BuiltInServerAttached(ownerToken: 'token', port: 4100),
    ]) {
      expect(
        messageFor(unexplained),
        'The local model server is not connected.',
      );
    }
    expect(
      BuiltInServerClient.failureFor(const BuiltInServerAttaching()),
      isA<ProviderServerFailed>(),
    );
  });

  test('marks a server another bestie holds as occupied', () {
    for (final held in const <BuiltInServerConnection>[
      BuiltInServerBusy(ownerPid: 12),
      BuiltInServerVersionMismatch(protocolVersion: 2, serverVersion: '0.2.0'),
    ]) {
      expect(BuiltInServerClient.failureFor(held), isA<ProviderOccupied>());
    }
    expect(
      BuiltInServerClient.failureFor(
        const BuiltInServerSpawnFailed(reason: 'missing'),
      ),
      isA<ProviderServerFailed>(),
    );
  });
}
