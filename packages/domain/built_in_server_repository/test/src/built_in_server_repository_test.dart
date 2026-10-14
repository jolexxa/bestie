import 'dart:async';

import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockBuiltInServerClient extends Mock
    implements BuiltInServerClient {}

const _attached = BuiltInServerAttached(ownerToken: 'token', port: 4242);

const _ready = ModelReady(
  localId: 'qwen3-8b',
  contextSize: 32768,
  maxAgents: 4,
  deviceBytes: 6100000000,
);

const _pool = PoolSnapshotEvent(
  contextSize: 32768,
  maxAgents: 4,
  agents: [
    PoolAgent(
      id: 'primary',
      kind: AgentLeaseKind.primary,
      claimedTokens: 8192,
      usedTokens: 10,
    ),
  ],
);

void main() {
  setUpAll(() => registerFallbackValue(ModelLoadOptions.defaults));

  late _MockBuiltInServerClient client;
  late StreamController<BuiltInServerConnection> connections;
  late StreamController<ModelStatus> models;
  late StreamController<PoolSnapshotEvent> pools;
  late BuiltInServerRepository repository;

  setUp(() {
    client = _MockBuiltInServerClient();
    connections = StreamController<BuiltInServerConnection>.broadcast();
    models = StreamController<ModelStatus>.broadcast();
    pools = StreamController<PoolSnapshotEvent>.broadcast();
    when(() => client.connectionChanges).thenAnswer((_) => connections.stream);
    when(() => client.modelStatusChanges).thenAnswer((_) => models.stream);
    when(() => client.poolSnapshots).thenAnswer((_) => pools.stream);
    when(client.attach).thenAnswer((_) async => _attached);
    when(client.release).thenAnswer((_) async {});
    when(client.close).thenAnswer((_) async {});
    when(() => client.configure(any())).thenReturn(null);
    repository = BuiltInServerRepository(client: client);
  });

  tearDown(() async {
    await connections.close();
    await models.close();
    await pools.close();
  });

  group('status', () {
    test('starts offline', () {
      expect(repository.status, isA<ServerOffline>());
      expect((repository.status as ServerOffline).reason, isNull);
    });

    test('follows the connection to the server', () async {
      final seen = <BuiltInServerStatus>[];
      final subscription = repository.statusStream.listen(seen.add);
      await pumpEventQueue();

      connections
        ..add(const BuiltInServerAttaching())
        ..add(_attached)
        ..add(const BuiltInServerDisconnected(reason: 'server went away'));
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        isA<ServerOffline>(),
        isA<ServerStarting>(),
        isA<ServerIdle>(),
        isA<ServerOffline>().having(
          (status) => status.reason,
          'reason',
          'server went away',
        ),
      ]);
    });

    test('says why the server could not be taken', () async {
      connections.add(const BuiltInServerBusy(ownerPid: 12));
      await pumpEventQueue();
      expect((repository.status as ServerTaken).ownerPid, 12);

      connections.add(
        const BuiltInServerVersionMismatch(
          protocolVersion: 2,
          serverVersion: '1.4.0',
        ),
      );
      await pumpEventQueue();
      final incompatible = repository.status as ServerIncompatible;
      expect(incompatible.protocolVersion, 2);
      expect(incompatible.serverVersion, '1.4.0');

      connections.add(const BuiltInServerSpawnFailed(reason: 'no binary'));
      await pumpEventQueue();
      expect((repository.status as ServerFailed).reason, 'no binary');
    });

    test('follows the model while the server is held', () async {
      connections.add(_attached);
      models.add(const ModelFitting(localId: 'qwen3-8b'));
      await pumpEventQueue();
      expect((repository.status as ServerFitting).localId, 'qwen3-8b');

      models.add(const ModelLoading(localId: 'qwen3-8b', progress: 0.5));
      await pumpEventQueue();
      final loading = repository.status as ServerLoading;
      expect(loading.localId, 'qwen3-8b');
      expect(loading.progress, 0.5);

      models.add(_ready);
      await pumpEventQueue();
      final serving = repository.status as ServerServing;
      expect(serving.localId, 'qwen3-8b');
      expect(serving.contextSize, 32768);
      expect(serving.maxAgents, 4);
      expect(serving.deviceBytes, 6100000000);
      expect(serving.leased, isNull);

      models.add(const ModelFailed(localId: 'qwen3-8b', reason: 'oom'));
      await pumpEventQueue();
      final failed = repository.status as ServerModelFailed;
      expect(failed.localId, 'qwen3-8b');
      expect(failed.reason, 'oom');

      models.add(const ModelUnloaded());
      await pumpEventQueue();
      expect(repository.status, isA<ServerIdle>());
    });

    test('counts the agents leased on the served model', () async {
      connections.add(_attached);
      models.add(_ready);
      pools.add(_pool);
      await pumpEventQueue();

      expect((repository.status as ServerServing).leased, 1);
    });

    test('leaves the model out while the server is not held', () async {
      models.add(_ready);
      await pumpEventQueue();

      expect(repository.status, isA<ServerOffline>());
    });
  });

  test('start takes the server', () async {
    await repository.start();

    verify(client.attach).called(1);
  });

  test('stop lets the server go', () async {
    await repository.stop();

    verify(client.release).called(1);
  });

  test('restart lets the server go, then takes it again', () async {
    await repository.restart();

    verifyInOrder([client.release, client.attach]);
  });

  test('configure hands the load options to the client', () {
    const options = ModelLoadOptions(contextCap: 8192);

    repository.configure(options);

    verify(() => client.configure(options)).called(1);
  });

  test('dispose closes the client and stops following it', () async {
    await repository.dispose();

    verify(client.close).called(1);
    expect(connections.hasListener, isFalse);
    expect(models.hasListener, isFalse);
    expect(pools.hasListener, isFalse);
    await expectLater(repository.statusStream, emitsThrough(emitsDone));
  });
}
