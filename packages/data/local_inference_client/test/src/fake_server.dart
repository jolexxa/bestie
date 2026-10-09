import 'dart:async';
import 'dart:convert';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';

class MockServerSpawner extends Mock implements ServerSpawner {}

/// A local inference server played over mock HTTP clients.
final class FakeServer {
  FakeServer() {
    lockOn(port);
    writeIndex(const [indexedModel]);
    when(
      () => spawner.spawn(any(), any()),
    ).thenAnswer((_) async => const ServerSpawnRefused('not here'));
  }

  static const lockFile = '/bestie/run/inference.lock';

  static const indexFile = '/bestie/models/index.json';

  static const indexedModel = ModelIndexEntry(
    localId: 'qwen',
    path: '/models/qwen.gguf',
    displayName: 'Qwen',
    profileId: ModelProfileId.qwen3,
    architecture: 'qwen3',
    fileType: 'Q4_K_M',
    sizeBytes: 1,
    trainedContextLength: 40960,
    reasoning: ModelReasoningNone(),
    defaultSampling: ModelSamplingDefaults(),
    provenance: ModelScanned(root: '/models'),
    fingerprint: '00000000',
  );

  final fileSystem = MemoryFileSystem.test();
  final spawner = MockServerSpawner();
  final requests = <http.Request>[];
  final sessions = <StreamController<List<int>>>[];
  int port = 4100;
  int protocolVersion = bestieProtocolVersion;
  int? busyOwner;
  int sessionStatus = 200;

  /// How many session requests in a row find the server shutting down.
  int sessionsShuttingDown = 0;
  FutureOr<http.Response> Function(http.Request request)? loadAnswer;
  AgentOpenResult Function(String agentId) leaseAnswer = (_) =>
      const AgentOpened(claimedTokens: 0);

  void lockOn(int port) => fileSystem.file(lockFile)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'pid': 42,
        'port': port,
        'protocol_version': bestieProtocolVersion,
      }),
    );

  /// Writes the model index the app keeps, listing [entries].
  void writeIndex(List<ModelIndexEntry> entries) => fileSystem.file(indexFile)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      ModelIndex(version: ModelIndex.currentVersion, models: entries).toJson(),
    );

  void removeLock() => fileSystem.file(lockFile).deleteSync();

  /// The requests that reached [path], as `METHOD path`.
  List<String> callsTo(String path) => [
    for (final request in requests)
      if (request.url.path == path) '${request.method} ${request.url.path}',
  ];

  void emit(SessionEvent event) =>
      sessions.last.add(utf8.encode('data: ${event.toJson()}\n\n'));

  Future<void> endSession() => sessions.last.close();

  LocalInferenceClient client() => LocalInferenceClient(
    client: MockClient(_answer),
    sessionClientFactory: _sessionClient,
    fileSystem: fileSystem,
    lockFile: lockFile,
    indexFile: indexFile,
    launch: const LocalServerLaunch(
      command: ProgramCommand(executable: 'bestie_server'),
      bestieDir: '/bestie',
      logFile: '/bestie/logs/server.log',
    ),
    pid: 77,
    spawner: spawner,
    startTimeout: Duration.zero,
  );

  http.Client _sessionClient() => MockClient.streaming((request, _) async {
    if (sessionsShuttingDown > 0) {
      sessionsShuttingDown--;
      return http.StreamedResponse(
        Stream.value(utf8.encode(_shuttingDown)),
        503,
      );
    }
    if (busyOwner case final ownerPid?) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(ServerBusy(ownerPid: ownerPid).toJson())),
        ServerBusy.statusCode,
      );
    }
    final body = StreamController<List<int>>();
    sessions.add(body);
    final opened = SessionOpened(ownerToken: 'token-${sessions.length}');
    body.add(utf8.encode('data: ${opened.toJson()}\n\n'));
    return http.StreamedResponse(body.stream, sessionStatus);
  });

  static final String _shuttingDown = jsonEncode({
    'error': {
      'message': 'The server is shutting down.',
      'type': 'server_error',
      'code': 'shutting_down',
    },
  });

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == bestieHealthPath) {
      return http.Response(
        HealthResponse(
          protocolVersion: protocolVersion,
          serverVersion: '0.1.0',
          pid: 42,
        ).toJson(),
        200,
      );
    }
    if (path == bestieModelPath) {
      return request.method == 'POST' ? _load(request) : http.Response('', 200);
    }
    final agentId = Uri.decodeComponent(path.split('/').last);
    return request.method == 'POST'
        ? http.Response(leaseAnswer(agentId).toJson(), 200)
        : http.Response('', 204);
  }

  FutureOr<http.Response> _load(http.Request request) {
    if (loadAnswer case final answer?) return answer(request);
    final load = ModelLoadRequestMapper.fromJson(request.body);
    return http.Response(
      ModelReady(
        localId: load.localId,
        contextSize: load.contextCap ?? 8192,
        maxAgents: load.maxAgents,
        deviceBytes: 1,
      ).toJson(),
      200,
    );
  }
}
