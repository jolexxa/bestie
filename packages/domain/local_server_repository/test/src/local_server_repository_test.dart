import 'dart:async';

import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockClient extends Mock implements LocalInferenceClient {}

const _ready = ModelReady(
  localId: 'qwen3-8b-3fa9c2d1',
  contextSize: 32768,
  maxAgents: 4,
  deviceBytes: 6100000000,
);

const _attached = LocalServerAttached(ownerToken: 'token', port: 4242);

PoolSnapshotEvent _pool(int leased) => PoolSnapshotEvent(
  contextSize: 32768,
  maxAgents: 4,
  agents: [
    for (var index = 0; index < leased; index++)
      PoolAgent(
        id: 'agent:$index',
        kind: AgentLeaseKind.subagent,
        claimedTokens: 8192,
        usedTokens: 0,
      ),
  ],
);

void main() {
  late _MockClient client;
  late StreamController<LocalServerConnection> connections;
  late StreamController<ModelStatus> models;
  late StreamController<PoolSnapshotEvent> pools;
  late LocalServerRepository repository;

  setUp(() {
    client = _MockClient();
    connections = StreamController.broadcast(sync: true);
    models = StreamController.broadcast(sync: true);
    pools = StreamController.broadcast(sync: true);
    when(() => client.connection).thenReturn(const LocalServerDisconnected());
    when(() => client.modelStatus).thenReturn(const ModelUnloaded());
    when(() => client.connectionChanges).thenAnswer((_) => connections.stream);
    when(() => client.modelStatusChanges).thenAnswer((_) => models.stream);
    when(() => client.poolSnapshots).thenAnswer((_) => pools.stream);
    repository = LocalServerRepository(client: client);
  });

  tearDown(() => repository.dispose());

  test('opens with what the client already knows', () async {
    expect(repository.current, isA<ServerIdle>());
    expect(await repository.status.first, same(repository.current));
  });

  test('is starting while the server is taken', () {
    connections.add(const LocalServerAttaching());
    expect(repository.current, isA<ServerStarting>());

    connections.add(_attached);
    expect(repository.current, isA<ServerStarting>(), reason: 'no model yet');
  });

  test('says who else holds the server', () {
    connections.add(const LocalServerBusy(ownerPid: 4121));

    expect((repository.current as ServerOwnedElsewhere).ownerPid, 4121);
  });

  test('says which protocol a running server speaks', () {
    connections.add(
      const LocalServerVersionMismatch(
        protocolVersion: 2,
        serverVersion: '0.2.0',
      ),
    );

    final incompatible = repository.current as ServerIncompatible;
    expect(incompatible.protocolVersion, 2);
    expect(incompatible.serverVersion, '0.2.0');
  });

  test('says why the server could not be started or held', () {
    connections.add(const LocalServerSpawnFailed(reason: 'missing'));
    expect((repository.current as ServerFailed).reason, 'missing');

    connections.add(const LocalServerDisconnected(reason: 'ended'));
    expect((repository.current as ServerFailed).reason, 'ended');

    connections.add(const LocalServerDisconnected());
    expect(repository.current, isA<ServerIdle>());
  });

  test('follows the model getting ready', () {
    connections.add(_attached);

    models.add(const ModelFitting(localId: 'qwen'));
    final fitting = repository.current as ServerLoading;
    expect(fitting.localId, 'qwen');
    expect(fitting.progress, isNull);

    models.add(const ModelLoading(localId: 'qwen', progress: 0.5));
    expect((repository.current as ServerLoading).progress, 0.5);

    models.add(const ModelFailed(localId: 'qwen', reason: 'oom'));
    final failed = repository.current as ServerLoadFailed;
    expect(failed.localId, 'qwen');
    expect(failed.reason, 'oom');
  });

  test('serves the ready model with its agent pool', () {
    connections.add(_attached);
    models.add(_ready);

    expect((repository.current as ServerServing).pool, isNull);

    pools.add(_pool(2));
    final serving = repository.current as ServerServing;
    expect(serving.localId, _ready.localId);
    expect(serving.contextSize, 32768);
    expect(serving.maxAgents, 4);
    expect(serving.deviceBytes, 6100000000);
    expect(serving.pool?.leased, 2);
    expect(serving.pool?.maxAgents, 4);
  });

  test('forgets the pool once the model or the session is gone', () {
    connections.add(_attached);
    models.add(_ready);
    pools.add(_pool(1));
    connections.add(_attached);
    expect((repository.current as ServerServing).pool?.leased, 1);

    models
      ..add(const ModelLoading(localId: 'other', progress: 0.1))
      ..add(_ready);
    expect((repository.current as ServerServing).pool, isNull);

    pools.add(_pool(3));
    connections
      ..add(const LocalServerDisconnected())
      ..add(_attached);
    expect((repository.current as ServerServing).pool, isNull);
  });
}
