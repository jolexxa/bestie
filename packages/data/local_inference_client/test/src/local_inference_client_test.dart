import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/local_provider.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

void main() {
  const qwen = ModelLoadRequest(localId: 'qwen', maxAgents: 3);
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

  late FakeServer server;
  late LocalInferenceClient client;

  setUp(() {
    server = FakeServer();
    client = server.client();
  });

  tearDown(() => client.close());

  group('attach', () {
    test('finds the server and takes the owner session', () async {
      final changes = <LocalServerConnection>[];
      client.connectionChanges.listen(changes.add);

      final attached = await client.attach();

      expect(attached, isA<LocalServerAttached>());
      expect((attached as LocalServerAttached).ownerToken, 'token-1');
      expect(attached.port, 4100);
      expect(client.connection, same(attached));
      expect(changes, [isA<LocalServerAttaching>(), same(attached)]);
    });

    test('keeps the session it holds', () async {
      final first = await client.attach();

      expect(await client.attach(), same(first));
      expect(server.sessions, hasLength(1));
    });

    test('shares one attempt between concurrent callers', () async {
      final attempts = await Future.wait([
        client.attach(),
        client.attach(),
      ]);

      expect(attempts.first, same(attempts.last));
      expect(server.sessions, hasLength(1));
    });

    test('reports another bestie owning the server', () async {
      server.busyOwner = 12;

      final attached = await client.attach();

      expect((attached as LocalServerBusy).ownerPid, 12);
    });

    test('reports a session the server would not open', () async {
      server.sessionStatus = 500;

      final attached = await client.attach();

      expect(
        (attached as LocalServerDisconnected).reason,
        'The local model server answered the session with HTTP 500.',
      );
    });

    test('looks again when the server shuts down as it is asked', () async {
      server.sessionsShuttingDown = 2;

      final attached = await client.attach();

      expect(attached, isA<LocalServerAttached>());
      expect(server.callsTo(bestieHealthPath), hasLength(3));
    });

    test('gives up once three servers in a row shut down', () async {
      server.sessionsShuttingDown = 3;

      final attached = await client.attach();

      expect(
        (attached as LocalServerDisconnected).reason,
        'The server is shutting down.',
      );
      expect(server.callsTo(bestieHealthPath), hasLength(3));
    });

    test('reports a server that speaks another protocol', () async {
      server.protocolVersion = 99;

      final attached = await client.attach();

      expect(attached, isA<LocalServerVersionMismatch>());
      expect((attached as LocalServerVersionMismatch).protocolVersion, 99);
      expect(attached.serverVersion, '0.1.0');
    });

    test('reports a server that could not be started', () async {
      server.removeLock();

      final attached = await client.attach();

      expect((attached as LocalServerSpawnFailed).reason, 'not here');
      verify(() => server.spawner.spawn('bestie_server', any())).called(1);
    });

    test('tries again after a refusal', () async {
      server.busyOwner = 12;
      await client.attach();
      server.busyOwner = null;

      final attached = await client.attach();

      expect((attached as LocalServerAttached).ownerToken, 'token-1');
    });
  });

  group('owner session', () {
    test('reports the model status it streams', () async {
      await client.attach();
      final statuses = client.modelStatusChanges.toList();
      const loading = ModelLoading(localId: 'qwen', progress: 0.5);

      server.emit(const ModelStatusEvent(status: loading));
      await pumpEventQueue();

      expect(client.modelStatus, loading);
      await client.close();
      expect(await statuses, [loading]);
    });

    test('reports the pool snapshots it streams', () async {
      await client.attach();
      final snapshots = client.poolSnapshots.toList();
      const snapshot = PoolSnapshotEvent(
        contextSize: 8192,
        maxAgents: 3,
        agents: [],
      );

      server.emit(snapshot);
      await pumpEventQueue();
      await client.close();

      expect(await snapshots, [snapshot]);
    });

    test(
      'disconnects and forgets its leases when the server ends it',
      () async {
        await client.attach();
        final holder = Object();
        await client.openLease(holder, primary);

        await server.endSession();
        await pumpEventQueue();

        expect(
          (client.connection as LocalServerDisconnected).reason,
          'The local model server ended the session.',
        );
        await client.attach();
        await client.closeLease(holder, primary.id);
        expect(server.callsTo(primaryPath), ['POST $primaryPath']);
      },
    );

    test('tells when this bestie stops holding the server', () async {
      await expectLater(client.untilDetached(), completes);

      await client.attach();
      var detached = false;
      unawaited(client.untilDetached().then((_) => detached = true));
      server.emit(const ModelStatusEvent(status: ModelUnloaded()));
      await pumpEventQueue();
      expect(detached, isFalse);

      await server.endSession();
      await pumpEventQueue();
      expect(detached, isTrue);
    });

    test('tells it has stopped holding the server once closed', () async {
      await client.attach();
      final detached = client.untilDetached();

      await client.close();

      await expectLater(detached, completes);
    });

    test('ignores a repeated opening', () async {
      await client.attach();

      server.emit(const SessionOpened(ownerToken: 'other'));
      await pumpEventQueue();

      expect((client.connection as LocalServerAttached).ownerToken, 'token-1');
    });
  });

  group('load', () {
    test('needs the owner session', () async {
      final loaded = await client.load(qwen);

      expect(
        (loaded as ModelLoadFailed).reason,
        'This bestie does not hold the local server.',
      );
    });

    test('loads the model', () async {
      await client.attach();

      final loaded = await client.load(qwen);

      expect((loaded as ModelLoaded).ready.localId, 'qwen');
      expect(server.callsTo(bestieModelPath), ['POST $bestieModelPath']);
    });

    test('keeps a model that already serves the same request', () async {
      await client.attach();
      final first = await client.load(qwen) as ModelLoaded;
      server.emit(ModelStatusEvent(status: first.ready));
      await pumpEventQueue();

      final again = await client.load(qwen);

      expect((again as ModelLoaded).ready, first.ready);
      expect(server.callsTo(bestieModelPath), hasLength(1));
    });

    test('reloads for a different request', () async {
      await client.attach();
      final first = await client.load(qwen) as ModelLoaded;
      server.emit(ModelStatusEvent(status: first.ready));
      await pumpEventQueue();

      await client.load(
        const ModelLoadRequest(localId: 'qwen', maxAgents: 3, contextCap: 4096),
      );

      expect(server.callsTo(bestieModelPath), hasLength(2));
    });

    test('loads again after a failed load', () async {
      await client.attach();
      final first = await client.load(qwen) as ModelLoaded;
      server.emit(ModelStatusEvent(status: first.ready));
      await pumpEventQueue();
      server.loadAnswer = (_) => http.Response('', 500);
      await client.load(qwen.copyWith(maxAgents: 9));
      server.loadAnswer = null;

      await client.load(qwen);

      expect(server.callsTo(bestieModelPath), hasLength(3));
    });
  });

  group('leases', () {
    final holder = Object();
    final other = Object();

    test('need the owner session', () async {
      final opened = await client.openLease(holder, primary);

      expect(
        (opened as AgentSessionFailed).message,
        'This bestie does not hold the local server.',
      );
    });

    test('open and close for the holder', () async {
      await client.attach();

      expect(
        await client.openLease(holder, primary),
        isA<AgentSessionOpened>(),
      );
      await client.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'DELETE $primaryPath',
      ]);
    });

    test('are not closed by a holder that does not hold them', () async {
      await client.attach();
      await client.openLease(holder, primary);

      await client.closeLease(other, primary.id);

      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('taken over by another holder are closed first', () async {
      await client.attach();
      await client.openLease(holder, primary);

      await client.openLease(other, primary);
      await client.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'DELETE $primaryPath',
        'POST $primaryPath',
      ]);
    });

    test('reopened by the same holder are not closed first', () async {
      await client.attach();
      await client.openLease(holder, primary);

      await client.openLease(holder, primary);

      expect(server.callsTo(primaryPath), [
        'POST $primaryPath',
        'POST $primaryPath',
      ]);
    });

    test('that were refused are not held', () async {
      await client.attach();
      server.leaseAnswer = (_) => const AgentNoCapacity();

      expect(
        await client.openLease(holder, subagent),
        isA<AgentSessionNoCapacity>(),
      );
      await client.closeLease(holder, subagent.id);

      expect(server.callsTo(subagentPath), ['POST $subagentPath']);
    });

    test('are all released for their holder', () async {
      await client.attach();
      await client.openLease(holder, primary);
      await client.openLease(holder, subagent);
      await client.openLease(
        other,
        const AgentIdentity(
          id: 'primary:9',
          kind: AgentIdentityKind.primary,
        ),
      );

      await client.releaseLeases(holder);

      expect(server.callsTo(primaryPath).last, 'DELETE $primaryPath');
      expect(server.callsTo(subagentPath).last, 'DELETE $subagentPath');
      expect(
        server.callsTo(bestieAgentPath('primary:9')),
        ['POST ${bestieAgentPath('primary:9')}'],
      );
    });

    test('are forgotten without a request once detached', () async {
      await client.attach();
      await client.openLease(holder, primary);
      server.busyOwner = 12;
      await server.endSession();
      await pumpEventQueue();

      await client.closeLease(holder, primary.id);

      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('keep their order when one fails', () async {
      await client.attach();
      server.leaseAnswer = (_) => throw StateError('boom');

      final results = await Future.wait([
        client.openLease(holder, primary),
        client.openLease(holder, subagent),
      ]);

      expect(results, everyElement(isA<AgentSessionFailed>()));
    });
  });

  group('release', () {
    test('unloads, hangs up and reports the client disconnected', () async {
      await client.attach();
      final holder = Object();
      await client.openLease(holder, primary);
      final first = await client.load(qwen) as ModelLoaded;
      server.emit(ModelStatusEvent(status: first.ready));
      await pumpEventQueue();
      final changes = <LocalServerConnection>[];
      final statuses = <ModelStatus>[];
      client.connectionChanges.listen(changes.add);
      client.modelStatusChanges.listen(statuses.add);

      await client.release();
      await pumpEventQueue();

      expect(server.callsTo(bestieModelPath).last, 'DELETE $bestieModelPath');
      expect(server.sessions.single.hasListener, isFalse);
      expect(changes, [isA<LocalServerDisconnected>()]);
      expect((client.connection as LocalServerDisconnected).reason, isNull);
      expect(client.modelStatus, const ModelUnloaded());
      expect(statuses, [const ModelUnloaded()]);
      await client.closeLease(holder, primary.id);
      expect(server.callsTo(primaryPath), ['POST $primaryPath']);
    });

    test('leaves the client ready to attach again', () async {
      await client.attach();
      final first = await client.load(qwen) as ModelLoaded;
      server.emit(ModelStatusEvent(status: first.ready));
      await pumpEventQueue();
      await client.release();

      final again = await client.attach();
      await client.load(qwen);

      expect((again as LocalServerAttached).ownerToken, 'token-2');
      expect(server.callsTo(bestieModelPath), [
        'POST $bestieModelPath',
        'DELETE $bestieModelPath',
        'POST $bestieModelPath',
      ]);
    });

    test('does nothing without a session', () async {
      final changes = <LocalServerConnection>[];
      client.connectionChanges.listen(changes.add);

      await client.release();

      expect(changes, isEmpty);
      expect(server.requests, isEmpty);
    });

    test('abandons an attach in flight and hangs up what it took', () async {
      final attaching = client.attach();
      final releasing = client.release();

      expect(await attaching, isA<LocalServerDisconnected>());
      await releasing;

      expect(client.connection, isA<LocalServerDisconnected>());
      expect(server.sessions.single.hasListener, isFalse);
      expect(await client.load(qwen), isA<ModelLoadFailed>());
    });

    test('lets an attach asked for after it take a new session', () async {
      final first = client.attach();
      final releasing = client.release();
      final second = client.attach();

      expect(await first, isA<LocalServerDisconnected>());
      await releasing;
      final attached = await second;

      expect((attached as LocalServerAttached).ownerToken, 'token-2');
      expect(client.connection, same(attached));
      expect(server.sessions.first.hasListener, isFalse);
      expect(server.sessions.last.hasListener, isTrue);
    });

    test('drops attaches asked for before a later release', () async {
      await client.attach();
      final releasing = client.release();
      final dropped = client.attach();
      final releasingAgain = client.release();

      expect(await dropped, isA<LocalServerDisconnected>());
      await Future.wait([releasing, releasingAgain]);

      expect(client.connection, isA<LocalServerDisconnected>());
      expect(server.sessions, hasLength(1));
    });

    test('forgets why the last attempt failed', () async {
      server.removeLock();
      await client.attach();
      final changes = <LocalServerConnection>[];
      client.connectionChanges.listen(changes.add);

      await client.release();

      expect(changes, [const LocalServerDisconnected()]);
      expect(client.connection, const LocalServerDisconnected());
    });

    test('forgets a server that would not open a session', () async {
      server.busyOwner = 12;
      await client.attach();

      await client.release();
      server.busyOwner = null;

      expect(
        await client.attach(),
        isA<LocalServerAttached>(),
      );
    });

    test('forgets a server that speaks another protocol', () async {
      server.protocolVersion = 99;
      await client.attach();

      await client.release();

      expect(client.connection, const LocalServerDisconnected());
    });

    test('finishes before a later attach takes a new session', () async {
      await client.attach();

      final releasing = client.release();
      final attaching = client.attach();
      await releasing;

      expect(
        (await attaching as LocalServerAttached).ownerToken,
        'token-2',
      );
      expect(server.sessions.first.hasListener, isFalse);
    });
  });

  group('close', () {
    test('hangs up and reports the client disconnected', () async {
      await client.attach();
      final changes = <LocalServerConnection>[];
      client.connectionChanges.listen(changes.add);

      await client.close();

      expect(changes, [isA<LocalServerDisconnected>()]);
      expect(
        (client.connection as LocalServerDisconnected).reason,
        isNull,
      );
      expect(server.sessions.single.hasListener, isFalse);
    });

    test('works without a session', () async {
      await client.close();

      expect(client.connection, isA<LocalServerDisconnected>());
    });

    test('hangs up a session taken while closing', () async {
      final attaching = client.attach();

      await client.close();

      expect(await attaching, isA<LocalServerDisconnected>());
      expect(server.sessions.single.hasListener, isFalse);
      expect(client.connection, isA<LocalServerDisconnected>());
    });

    test('waits for a release under way', () async {
      await client.attach();
      final releasing = client.release();

      await client.close();
      await releasing;

      expect(server.callsTo(bestieModelPath), ['DELETE $bestieModelPath']);
      expect(server.sessions.single.hasListener, isFalse);
    });

    test('happens once however often it is asked for', () async {
      await client.attach();

      expect(identical(client.close(), client.close()), isTrue);
    });

    test('leaves the client unable to attach or release again', () async {
      await client.close();

      expect(
        await client.attach(),
        isA<LocalServerDisconnected>(),
      );
      await client.release();
      expect(server.sessions, isEmpty);
    });
  });

  test('serves the local provider', () {
    final provider = client.provider(
      descriptor: const ProviderDescriptor(
        id: 'local',
        displayName: 'Local models',
        requiresApiKey: false,
        dialect: InferenceDialect.bestie,
      ),
      options: () => const LocalProviderOptions(),
    );

    expect(provider, isA<LocalProvider>());
    expect(provider.id, 'local');
  });
}
