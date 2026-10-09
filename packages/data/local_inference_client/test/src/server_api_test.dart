import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  const owner = LocalServerAttached(ownerToken: 'token', port: 4100);
  const ready = ModelReady(
    localId: 'qwen',
    contextSize: 8192,
    maxAgents: 3,
    deviceBytes: 1024,
  );
  const request = ModelLoadRequest(localId: 'qwen', maxAgents: 3);
  const primary = AgentIdentity(
    id: 'primary:1',
    kind: AgentIdentityKind.primary,
  );
  const subagent = AgentIdentity(
    id: 'subagent:2',
    kind: AgentIdentityKind.subagent,
  );
  final requests = <http.Request>[];

  ServerApi apiAnswering(
    FutureOr<http.Response> Function(http.Request request) answer, {
    Duration healthTimeout = const Duration(seconds: 5),
  }) => ServerApi(
    client: MockClient((request) async {
      requests.add(request);
      return answer(request);
    }),
    healthTimeout: healthTimeout,
  );

  http.Response error(int status, String message) => http.Response(
    jsonEncode({
      'error': {'message': message},
    }),
    status,
  );

  setUp(requests.clear);

  test('addresses the server on loopback', () {
    expect(
      ServerApi.urlFor(4100, '/v1'),
      Uri.parse('http://127.0.0.1:4100/v1'),
    );
  });

  group('health', () {
    test('reads the handshake', () async {
      final api = apiAnswering(
        (_) => http.Response(
          const HealthResponse(
            protocolVersion: 1,
            serverVersion: '0.1.0',
            pid: 7,
          ).toJson(),
          200,
        ),
      );

      final health = await api.health(4100);

      expect(health?.pid, 7);
      expect(requests.single.url.path, bestieHealthPath);
    });

    test('is null when the server answers with an error', () async {
      final api = apiAnswering((_) => http.Response('', 500));

      expect(await api.health(4100), isNull);
    });

    test('is null when nothing answers', () async {
      final api = apiAnswering(
        (_) => throw http.ClientException('refused'),
      );

      expect(await api.health(4100), isNull);
    });

    test('is null when the server stalls past the timeout', () async {
      final api = apiAnswering(
        (_) => Completer<http.Response>().future,
        healthTimeout: const Duration(milliseconds: 10),
      );

      expect(await api.health(4100), isNull);
    });
  });

  group('load', () {
    test('loads as the owner and returns the ready model', () async {
      final api = apiAnswering((_) => http.Response(ready.toJson(), 200));

      final loaded = await api.load(owner, request);

      expect((loaded as ModelLoaded).ready, ready);
      final sent = requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, bestieModelPath);
      expect(sent.headers[bestieOwnerHeader], 'token');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(ModelLoadRequestMapper.fromJson(sent.body), request);
    });

    test('fails when the server answers with another status', () async {
      final api = apiAnswering(
        (_) => http.Response(
          const ModelFailed(localId: 'qwen', reason: 'oom').toJson(),
          200,
        ),
      );

      final loaded = await api.load(owner, request);

      expect(
        (loaded as ModelLoadFailed).reason,
        'The server answered the load with ModelFailed.',
      );
    });

    test('reports the error the server gives', () async {
      final api = apiAnswering((_) => error(409, 'not the owner'));

      final loaded = await api.load(owner, request);

      expect((loaded as ModelLoadFailed).reason, 'not the owner');
    });

    test('reports an unreachable server', () async {
      final api = apiAnswering(
        (_) => throw http.ClientException('refused'),
      );

      final loaded = await api.load(owner, request);

      expect((loaded as ModelLoadFailed).reason, 'refused');
    });
  });

  group('unload', () {
    test('unloads as the owner', () async {
      final api = apiAnswering((_) => http.Response('', 200));

      expect(await api.unload(owner), isA<ModelUnloadSucceeded>());
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, bestieModelPath);
      expect(requests.single.headers[bestieOwnerHeader], 'token');
    });

    test('reports the error the server gives', () async {
      final api = apiAnswering((_) => error(403, 'not the owner'));

      final unloaded = await api.unload(owner);

      expect((unloaded as ModelUnloadFailed).reason, 'not the owner');
    });

    test('reports an unreachable server', () async {
      final api = apiAnswering(
        (_) => throw http.ClientException('refused'),
      );

      final unloaded = await api.unload(owner);

      expect((unloaded as ModelUnloadFailed).reason, 'refused');
    });
  });

  group('openLease', () {
    http.Response answered(AgentOpenResult result) =>
        http.Response(result.toJson(), 200);

    test('opens a primary lease as the owner', () async {
      final api = apiAnswering(
        (_) => answered(const AgentOpened(claimedTokens: 0)),
      );

      final opened = await api.openLease(owner, primary);

      expect((opened as AgentSessionOpened).claimedTokens, 0);
      final sent = requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, bestieAgentPath('primary:1'));
      expect(sent.headers[bestieOwnerHeader], 'token');
      expect(
        AgentOpenRequestMapper.fromJson(sent.body).kind,
        AgentLeaseKind.primary,
      );
    });

    test('opens a subagent lease with its claim', () async {
      final api = apiAnswering(
        (_) => answered(const AgentOpened(claimedTokens: 4096)),
      );

      final opened = await api.openLease(owner, subagent);

      expect((opened as AgentSessionOpened).claimedTokens, 4096);
      expect(
        AgentOpenRequestMapper.fromJson(requests.single.body).kind,
        AgentLeaseKind.subagent,
      );
    });

    test('reports a full pool', () async {
      final api = apiAnswering((_) => answered(const AgentNoCapacity()));

      expect(
        await api.openLease(owner, subagent),
        isA<AgentSessionNoCapacity>(),
      );
    });

    test('reports a claim the context cannot hold', () async {
      final api = apiAnswering(
        (_) => answered(const AgentInsufficientClaim()),
      );

      expect(
        await api.openLease(owner, subagent),
        isA<AgentSessionInsufficientClaim>(),
      );
    });

    test('fails with the error the server gives', () async {
      final api = apiAnswering((_) => error(503, 'no model loaded'));

      final opened = await api.openLease(owner, primary);

      expect((opened as AgentSessionFailed).message, 'no model loaded');
    });

    test('fails when the server is unreachable', () async {
      final api = apiAnswering(
        (_) => throw http.ClientException('refused'),
      );

      final opened = await api.openLease(owner, primary);

      expect((opened as AgentSessionFailed).message, 'refused');
    });
  });

  group('closeLease', () {
    test('closes the lease as the owner', () async {
      final api = apiAnswering((_) => http.Response('', 204));

      await api.closeLease(owner, 'subagent:2');

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, bestieAgentPath('subagent:2'));
      expect(requests.single.headers[bestieOwnerHeader], 'token');
    });

    test('shrugs off an unreachable server', () async {
      final api = apiAnswering(
        (_) => throw http.ClientException('refused'),
      );

      await expectLater(api.closeLease(owner, 'subagent:2'), completes);
    });
  });
}
