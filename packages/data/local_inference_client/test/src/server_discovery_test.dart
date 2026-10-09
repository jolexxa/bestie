import 'dart:async';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:fake_async/fake_async.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_client/src/server_discovery.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockServerSpawner extends Mock implements ServerSpawner {}

void main() {
  const lockFile = '/bestie/run/inference.lock';
  const logFile = '/bestie/logs/server.log';
  const launch = LocalServerLaunch(
    command: ProgramCommand(executable: 'dart', arguments: ['run', 'server']),
    bestieDir: '/bestie',
    logFile: logFile,
  );
  const handshake = HealthResponse(
    protocolVersion: bestieProtocolVersion,
    serverVersion: '0.1.0',
    pid: 42,
  );

  late MemoryFileSystem fileSystem;
  late _MockServerSpawner spawner;
  late List<Duration> handshakes;
  late http.Response Function() healthAnswer;

  void lockPort(int port) => fileSystem.file(lockFile)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      const InferenceLockFile(
        pid: 42,
        port: 0,
        protocolVersion: bestieProtocolVersion,
      ).copyWith(port: port).toJson(),
    );

  ServerDiscovery discoveryIn(FakeAsync async) {
    final started = async.elapsed;
    return ServerDiscovery(
      api: ServerApi(
        client: MockClient((request) async {
          handshakes.add(async.elapsed - started);
          return healthAnswer();
        }),
        healthTimeout: const Duration(seconds: 5),
      ),
      fileSystem: fileSystem,
      lockFile: lockFile,
      launch: launch,
      spawner: spawner,
      clock: async.getClock(DateTime(2026)),
      startTimeout: const Duration(seconds: 3),
    );
  }

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    spawner = _MockServerSpawner();
    handshakes = [];
    healthAnswer = () => http.Response(handshake.toJson(), 200);
    when(
      () => spawner.spawn(any(), any()),
    ).thenAnswer((_) async => const ServerSpawned(pid: 42));
  });

  test('finds the server the lock file names', () {
    fakeAsync((async) {
      lockPort(4100);
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(
          async,
        ).find().then((result) => found = result),
      );
      async.flushMicrotasks();

      expect(found, isA<ServerFound>());
      expect((found! as ServerFound).port, 4100);
      expect((found! as ServerFound).health.pid, 42);
      verifyNever(() => spawner.spawn(any(), any()));
    });
  });

  test('reports a server that speaks another protocol', () {
    fakeAsync((async) {
      lockPort(4100);
      healthAnswer = () => http.Response(
        handshake.copyWith(protocolVersion: 99).toJson(),
        200,
      );
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(
          async,
        ).find().then((result) => found = result),
      );
      async.flushMicrotasks();

      expect(
        (found! as ServerSpeaksOtherProtocol).health.protocolVersion,
        99,
      );
    });
  });

  test('asks a stalled server twice before starting another', () {
    fakeAsync((async) {
      lockPort(4100);
      final answers = [
        http.Response('', 503),
        http.Response(handshake.toJson(), 200),
      ];
      healthAnswer = () => answers.removeAt(0);
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(
          async,
        ).find().then((result) => found = result),
      );
      async.flushMicrotasks();

      expect(found, isA<ServerFound>());
      verifyNever(() => spawner.spawn(any(), any()));
    });
  });

  test('starts a server and waits for it to write its lock file', () {
    fakeAsync((async) {
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(async).find().then((result) => found = result),
      );
      async.flushMicrotasks();

      verify(
        () => spawner.spawn('dart', [
          'run',
          'server',
          '--bestie-dir',
          '/bestie',
          '--log',
          logFile,
        ]),
      ).called(1);
      expect(fileSystem.directory('/bestie/logs').existsSync(), isTrue);

      async.elapse(const Duration(milliseconds: 250));
      expect(found, isNull);

      lockPort(4100);
      async.elapse(const Duration(milliseconds: 400));

      expect((found! as ServerFound).port, 4100);
    });
  });

  test('polls with a backoff that tops out at a second', () {
    fakeAsync((async) {
      lockPort(4100);
      healthAnswer = () => http.Response('', 503);

      unawaited(discoveryIn(async).find());
      async.elapse(const Duration(seconds: 3));

      expect(handshakes, [
        Duration.zero,
        Duration.zero,
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 700),
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 2500),
      ]);
    });
  });

  test('gives up on a server that never starts', () {
    fakeAsync((async) {
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(
          async,
        ).find().then((result) => found = result),
      );
      async.elapse(const Duration(seconds: 3));
      expect(found, isNull);
      async.elapse(const Duration(seconds: 1));

      expect(
        (found! as ServerNotStarted).reason,
        'The local model server did not start within 3 seconds; '
        'see $logFile.',
      );
    });
  });

  test('reports a server that could not be started', () {
    fakeAsync((async) {
      when(
        () => spawner.spawn(any(), any()),
      ).thenAnswer((_) async => const ServerSpawnRefused('no such file'));
      ServerDiscoveryResult? found;

      unawaited(
        discoveryIn(
          async,
        ).find().then((result) => found = result),
      );
      async.flushMicrotasks();

      expect((found! as ServerNotStarted).reason, 'no such file');
    });
  });

  test('treats an unreadable lock file as no server', () {
    fakeAsync((async) {
      fileSystem.file(lockFile)
        ..createSync(recursive: true)
        ..writeAsStringSync('{');

      unawaited(discoveryIn(async).find());
      async.flushMicrotasks();

      expect(handshakes, isEmpty);
      verify(() => spawner.spawn(any(), any())).called(1);
    });
  });

  test('starts the server even when its log folder cannot be made', () {
    fakeAsync((async) {
      fileSystem.file('/bestie/logs').createSync(recursive: true);

      unawaited(discoveryIn(async).find());
      async.flushMicrotasks();

      verify(() => spawner.spawn(any(), any())).called(1);
    });
  });

  test('shares one search between concurrent callers', () {
    fakeAsync((async) {
      final discovery = discoveryIn(async);
      final found = <ServerDiscoveryResult>[];

      unawaited(discovery.find().then(found.add));
      unawaited(discovery.find().then(found.add));
      async.flushMicrotasks();
      lockPort(4100);
      async.elapse(const Duration(milliseconds: 100));

      expect(found, hasLength(2));
      expect(identical(found.first, found.last), isTrue);
      verify(() => spawner.spawn(any(), any())).called(1);

      unawaited(discovery.find());
      async.flushMicrotasks();
      verifyNever(() => spawner.spawn(any(), any()));
    });
  });
}
