import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/http.dart';
import '../helpers/lock_holder.dart';
import '../helpers/mocks.dart';

void main() {
  late Directory bestieDir;
  late MockModelEngine engine;
  late MockModelEngineStarter starter;
  late MockServerLog log;
  late StreamController<void> shutdownRequests;

  setUp(() {
    bestieDir = Directory.systemTemp.createTempSync('server_launch_');
    engine = MockModelEngine();
    when(engine.close).thenAnswer((_) async {});
    log = MockServerLog();
    starter = MockModelEngineStarter();
    when(() => starter.start(log)).thenAnswer(
      (_) async => ModelEngineStarted(engine),
    );
    shutdownRequests = StreamController<void>.broadcast();
  });

  tearDown(() async {
    await shutdownRequests.close();
    bestieDir.deleteSync(recursive: true);
  });

  ServerLaunch launch({
    Duration startupGrace = const Duration(minutes: 1),
    Duration lockWait = Duration.zero,
    Future<HttpServer> Function()? bind,
  }) => ServerLaunch(
    bestieDir: bestieDir.path,
    startupGrace: startupGrace,
    lockWait: lockWait,
    engineStarter: starter,
    log: log,
    fileSystem: const LocalFileSystem(),
    serverVersion: '1.0.0',
    pid: 1234,
    shutdownRequests: shutdownRequests.stream,
    bind: bind,
  );

  void expectLockFree(String lockPath) {
    final acquisition = InferenceLock.acquire(lockPath);
    expect(acquisition, isA<InferenceLockAcquired>());
    (acquisition as InferenceLockAcquired).lock.release();
  }

  Future<InferenceLockFile> published(String lockPath) async {
    final file = File(lockPath);
    while (!file.existsSync() || file.lengthSync() == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return InferenceLockFileMapper.fromJson(file.readAsStringSync());
  }

  test('names its lock and index inside the bestie directory', () {
    final server = launch();

    expect(server.lockPath, p.join(bestieDir.path, 'run', 'inference.lock'));
    expect(
      server.indexPath,
      p.join(bestieDir.path, 'models', 'index.json'),
    );
  });

  test('serves on loopback until asked to stop', () async {
    final server = launch();
    final running = server.run();
    final holder = await published(server.lockPath);
    final client = TestClient(holder.port);

    final health = await client.send('GET', bestieHealthPath);
    final session = await client.events(bestieSessionPath);
    final opened = await session.nextJson();
    shutdownRequests.add(null);
    final exit = await running;
    client.close();

    expect(holder.pid, 1234);
    expect(holder.protocolVersion, bestieProtocolVersion);
    expect(HealthResponseMapper.fromJson(health.body).pid, 1234);
    expect(opened['owner_token'], hasLength(32));
    expect(
      exit,
      isA<ServerStopped>().having(
        (stopped) => stopped.reason,
        'reason',
        ServerStopReason.requested,
      ),
    );
    expect(exit.exitCode, 0);
    verify(engine.close).called(1);
    expectLockFree(server.lockPath);
  });

  test('defaults to a short startup grace and lock wait', () {
    final server = ServerLaunch(
      bestieDir: bestieDir.path,
      engineStarter: starter,
      log: log,
      fileSystem: const LocalFileSystem(),
      serverVersion: '1.0.0',
      pid: 1234,
      shutdownRequests: shutdownRequests.stream,
    );

    expect(server.startupGrace, const Duration(seconds: 30));
    expect(server.lockWait, const Duration(seconds: 10));
  });

  test('stops unclaimed when only probes arrive within the grace', () async {
    final server = launch(startupGrace: const Duration(milliseconds: 300));
    final running = server.run();
    final client = TestClient((await published(server.lockPath)).port);
    addTearDown(client.close);

    final health = await client.send('GET', bestieHealthPath);
    final exit = await running;

    expect(health.status, HttpStatus.ok);
    expect(
      exit,
      isA<ServerStopped>().having(
        (stopped) => stopped.reason,
        'reason',
        ServerStopReason.unclaimed,
      ),
    );
    verify(engine.close).called(1);
  });

  test('stops as soon as its last connection closes', () async {
    final server = launch();
    final running = server.run();
    final client = TestClient((await published(server.lockPath)).port);
    addTearDown(client.close);

    final session = await client.events(bestieSessionPath);
    await session.nextJson();
    await session.hangUp();
    final exit = await running;

    expect(
      exit,
      isA<ServerStopped>().having(
        (stopped) => stopped.reason,
        'reason',
        ServerStopReason.drained,
      ),
    );
    expect(exit.exitCode, 0);
    verify(() => log.info('Shutting down (drained).')).called(1);
    expectLockFree(server.lockPath);
  });

  test('waits for a server that is letting go of the lock', () async {
    final server = launch(
      startupGrace: Duration.zero,
      lockWait: const Duration(seconds: 30),
    );
    final holder = await LockHolder.hold(server.lockPath);

    final running = server.run();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await holder.release();
    final exit = await running;

    expect(exit, isA<ServerStopped>());
    verify(
      () => log.info(
        'Waiting for the server holding ${server.lockPath} '
        'to let go.',
      ),
    ).called(1);
  });

  test('refuses to run beside another server', () async {
    final server = launch();
    final holder = await LockHolder.hold(server.lockPath);
    addTearDown(holder.release);

    final exit = await server.run();

    expect(
      exit,
      isA<ServerAlreadyRunning>().having(
        (running) => running.holder?.pid,
        'holder pid',
        holder.pid,
      ),
    );
    expect(exit.exitCode, 75);
    verifyNever(() => starter.start(log));
  });

  test('fails when the lock cannot be opened', () async {
    File(p.join(bestieDir.path, 'run')).writeAsStringSync('in the way');

    final exit = await launch().run();

    expect(exit, isA<ServerLockFailed>());
    expect(exit.exitCode, 73);
  });

  test('fails when the engine libraries are missing', () async {
    when(() => starter.start(log)).thenAnswer(
      (_) async => const ModelEngineLibrariesMissing(message: 'no dylib'),
    );
    final server = launch();

    final exit = await server.run();

    expect(
      exit,
      isA<ServerLibrariesMissing>().having(
        (missing) => missing.message,
        'message',
        'no dylib',
      ),
    );
    expect(exit.exitCode, 72);
    verify(() => log.error('no dylib')).called(1);
    expectLockFree(server.lockPath);
  });

  test('fails when the engine cannot start', () async {
    when(() => starter.start(log)).thenAnswer(
      (_) async => const ModelEngineFailedToStart(message: 'no isolate'),
    );

    final exit = await launch().run();

    expect(
      exit,
      isA<ServerEngineFailed>().having(
        (failed) => failed.message,
        'message',
        'no isolate',
      ),
    );
    expect(exit.exitCode, 70);
  });

  test('fails when it cannot listen, giving the lock back', () async {
    final server = launch(
      bind: () async => throw const SocketException('no ports'),
    );

    final exit = await server.run();

    expect(
      exit,
      isA<ServerBindFailed>().having(
        (failed) => failed.message,
        'message',
        'no ports',
      ),
    );
    expect(exit.exitCode, 69);
    verify(engine.close).called(1);
    expectLockFree(server.lockPath);
  });
}
