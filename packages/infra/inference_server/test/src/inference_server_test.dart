import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:file/memory.dart';
import 'package:inference/inference.dart';
import 'package:inference_server/inference_server.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/http.dart';
import '../helpers/index.dart';
import '../helpers/mocks.dart';

const _indexPath = '/bestie/models/index.json';
const Map<String, String> _owner = {bestieOwnerHeader: 'token-1'};
const _chatPath = '/v1/chat/completions';

const _hello = {
  'messages': [
    {'role': 'user', 'content': 'hi'},
  ],
};

const _usage = CompletionUsage(
  promptTokens: 3,
  completionTokens: 2,
  cachedTokens: 1,
);

void main() {
  late MemoryFileSystem fileSystem;
  late MockModelEngine engine;
  late MockServerLifetime lifetime;
  late bool shuttingDown;
  late ModelHost host;
  late InferenceServer server;
  late HttpServer http;
  late TestClient client;
  late StreamController<PoolSnapshot> poolChanges;
  late MockLoadedModel model;

  late MockCompletionRuntime runtime;
  late OwnerSessions owners;
  late MockServerLog log;
  late int inFlight;

  setUpAll(() {
    registerFallbackValue(
      const ModelEngineRequest(entry: qwenEntry, maxAgents: 1),
    );
    registerFallbackValue(
      const CompletionRequest(
        messages: [],
        reasoningMode: 'off',
        sampling: EngineSampling(),
      ),
    );
  });

  setUp(() async {
    fileSystem = MemoryFileSystem.test();
    writeIndex(fileSystem, _indexPath, [qwenEntry, gemmaEntry]);
    engine = MockModelEngine();
    lifetime = MockServerLifetime();
    inFlight = 0;
    shuttingDown = false;
    when(() => lifetime.shuttingDown).thenAnswer((_) => shuttingDown);
    when(lifetime.opened).thenAnswer((_) => inFlight++);
    when(lifetime.closed).thenAnswer((_) => inFlight--);
    log = MockServerLog();
    poolChanges = StreamController<PoolSnapshot>.broadcast();
    model = MockLoadedModel.serving(
      contextSize: 4096,
      maxAgents: 2,
      poolChanges: poolChanges,
    );
    runtime = model.runtime as MockCompletionRuntime;
    when(() => engine.load(any())).thenAnswer(
      (_) => Stream.fromIterable([
        const ModelEngineFitted(contextSize: 4096),
        ModelEngineLoaded(model: model),
      ]),
    );
    final index = ModelIndexReader(fileSystem: fileSystem, path: _indexPath);
    host = ModelHost(engine: engine, index: index);
    var tokens = 0;
    var completions = 0;
    owners = OwnerSessions(mintToken: () => 'token-${++tokens}');
    server = InferenceServer(
      host: host,
      index: index,
      owners: owners,
      lifetime: lifetime,
      log: log,
      serverVersion: '1.2.3',
      pid: 99,
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
      mintCompletionId: () => '${++completions}',
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(server.serve(http));
    client = TestClient(http.port);
  });

  tearDown(() async {
    client.close();
    await http.close(force: true);
    await server.close();
    await poolChanges.close();
  });

  Future<EventReader> openSession({int? pid = 42}) async {
    final session = await client.events(
      bestieSessionPath,
      headers: {bestieOwnerPidHeader: ?pid?.toString()},
    );
    await session.nextJson();
    await session.nextJson();
    return session;
  }

  Future<void> loadModel() =>
      host.load(const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 2));

  void completes(List<CompletionEvent> events) {
    when(() => runtime.complete(any())).thenAnswer(
      (_) async => CompletionStarted(Stream.fromIterable(events)),
    );
  }

  CompletionRequest sentRequest() =>
      verify(() => runtime.complete(captureAny())).captured.single
          as CompletionRequest;

  group('handshake', () {
    test('reports the protocol, version, and pid', () async {
      final reply = await client.send('GET', bestieHealthPath);

      expect(reply.status, HttpStatus.ok);
      expect(
        HealthResponseMapper.fromJson(reply.body),
        const HealthResponse(
          protocolVersion: 1,
          serverVersion: '1.2.3',
          pid: 99,
        ),
      );
    });

    test('is a probe that holds nothing up', () async {
      await client.send('GET', bestieHealthPath);

      verifyNever(lifetime.opened);
    });

    test('holds the server up while answering', () async {
      final reply = await client.send('GET', bestieModelPath);
      await untilCalled(lifetime.closed);

      expect(reply.status, HttpStatus.ok);
      verify(lifetime.opened).called(1);
      verify(lifetime.closed).called(1);
      expect(inFlight, 0);
    });

    test('turns every request away once shutting down', () async {
      shuttingDown = true;

      final replies = [
        await client.send('GET', bestieHealthPath),
        await client.send('GET', bestieSessionPath),
        await client.send('POST', _chatPath, body: _hello),
      ];

      expect(
        [for (final reply in replies) reply.status],
        everyElement(HttpStatus.serviceUnavailable),
      );
      expect(
        [for (final reply in replies) reply.errorCode],
        everyElement('shutting_down'),
      );
      verifyNever(lifetime.opened);
      expect(owners.owner, isNull);
    });

    test('a connection that cannot be taken claims no session', () async {
      final request = MockHttpRequest();
      final response = MockHttpResponse();
      final headers = MockHttpHeaders();
      when(() => request.method).thenReturn('GET');
      when(() => request.uri).thenReturn(Uri(path: bestieSessionPath));
      when(() => request.headers).thenReturn(headers);
      when(() => request.response).thenReturn(response);
      when(
        () => response.detachSocket(writeHeaders: any(named: 'writeHeaders')),
      ).thenThrow(const SocketException('gone'));

      await server.serve(Stream.value(request));

      expect(owners.owner, isNull);
      verify(() => log.error(any(that: contains('gone')))).called(1);
      final session = await openSession();
      await session.hangUp();
    });

    test('answers unknown routes with not found', () async {
      final reply = await client.send('GET', '/v2/nothing');

      expect(reply.status, HttpStatus.notFound);
      expect(reply.errorCode, 'not_found');
    });

    test('answers the wrong method with method not allowed', () async {
      final reply = await client.send('PUT', bestieHealthPath);

      expect(reply.status, HttpStatus.methodNotAllowed);
      expect(reply.errorCode, 'method_not_allowed');
    });
  });

  group('models', () {
    test('lists the index, marking the loaded model', () async {
      await loadModel();

      final reply = await client.send('GET', '/v1/models');
      final list = BestieModelListMapper.fromJson(reply.body);

      expect(
        [
          for (final model in reply.object['data']! as List)
            (model as Map)['created'],
        ],
        [5, 5],
      );
      expect(
        [for (final model in list.data) model.id],
        ['qwen3-1.7b', 'gemma'],
      );
      expect(
        [for (final model in list.data) model.bestie.loaded],
        [true, false],
      );
      expect(list.data.first.contextLength, 40960);
      expect(list.data.first.bestie.reasoning, const ModelReasoningToggle());
    });

    test('lists only the entries it can load, and logs the rest', () async {
      writeIndexWithUnknownProfile(fileSystem, _indexPath, [gemmaEntry]);

      final reply = await client.send('GET', '/v1/models');

      expect(
        [
          for (final model in BestieModelListMapper.fromJson(reply.body).data)
            model.id,
        ],
        ['gemma'],
      );
      verify(
        () => log.error('Skipped 1 index entries it cannot load.'),
      ).called(1);
    });

    test('lists nothing before an index exists', () async {
      fileSystem.file(_indexPath).deleteSync();

      final reply = await client.send('GET', '/v1/models');

      expect(BestieModelListMapper.fromJson(reply.body).data, isEmpty);
    });

    test('fails on an unreadable index', () async {
      fileSystem.file(_indexPath).writeAsStringSync('{');

      final reply = await client.send('GET', '/v1/models');

      expect(reply.status, HttpStatus.internalServerError);
      expect(reply.errorCode, 'index_unreadable');
    });
  });

  group('owner session', () {
    test('opens with the token, the model status, and the pool', () async {
      await loadModel();

      final session = await client.events(
        bestieSessionPath,
        headers: {bestieOwnerPidHeader: '42'},
      );

      expect(
        SessionEventMapper.fromJson(jsonEncode(await session.nextJson())),
        const SessionOpened(ownerToken: 'token-1'),
      );
      expect(
        SessionEventMapper.fromJson(jsonEncode(await session.nextJson())),
        isA<ModelStatusEvent>().having(
          (event) => event.status,
          'status',
          isA<ModelReady>(),
        ),
      );
      expect(
        SessionEventMapper.fromJson(jsonEncode(await session.nextJson())),
        const PoolSnapshotEvent(contextSize: 4096, maxAgents: 2, agents: []),
      );
      expect(inFlight, 1);
      await session.hangUp();
    });

    test('refuses a second client with the owner pid', () async {
      final session = await openSession();

      final reply = await client.send(
        'GET',
        bestieSessionPath,
        headers: {bestieOwnerPidHeader: '43'},
      );

      expect(reply.status, ServerBusy.statusCode);
      expect(
        ServerErrorMapper.fromJson(reply.body),
        const ServerBusy(ownerPid: 42),
      );
      await session.hangUp();
    });

    test('names an owner without a pid as pid 0', () async {
      final session = await openSession(pid: null);

      final reply = await client.send('GET', bestieSessionPath);

      expect(
        ServerErrorMapper.fromJson(reply.body),
        const ServerBusy(ownerPid: 0),
      );
      await session.hangUp();
    });

    test('streams model status and pool changes to the owner', () async {
      final session = await openSession();

      await loadModel();
      poolChanges.add(
        const PoolSnapshot(
          contextSize: 4096,
          maxAgents: 2,
          agents: [
            PrimaryPoolLease(id: 'primary:1', usedTokens: 10),
            SubagentPoolLease(
              id: 'sub:1',
              usedTokens: 5,
              claimedTokens: 2048,
            ),
          ],
          borrowedTokens: 512,
        ),
      );

      final events = [
        for (var count = 0; count < 4; count++)
          SessionEventMapper.fromJson(jsonEncode(await session.nextJson())),
      ];
      expect(events, [
        const ModelStatusEvent(status: ModelFitting(localId: 'qwen3-1.7b')),
        const ModelStatusEvent(
          status: ModelLoading(localId: 'qwen3-1.7b', progress: 0),
        ),
        isA<ModelStatusEvent>(),
        const PoolSnapshotEvent(
          contextSize: 4096,
          maxAgents: 2,
          agents: [
            PoolAgent(
              id: 'primary:1',
              kind: AgentLeaseKind.primary,
              claimedTokens: 0,
              usedTokens: 10,
            ),
            PoolAgent(
              id: 'sub:1',
              kind: AgentLeaseKind.subagent,
              claimedTokens: 2048,
              usedTokens: 5,
            ),
          ],
          borrowedTokens: 512,
        ),
      ]);
      await session.hangUp();
    });

    test('hanging up releases every lease and frees the session', () async {
      await loadModel();
      final session = await openSession();
      await session.nextJson();

      await session.hangUp();
      await untilCalled(() => runtime.closeAll());
      await pumpEventQueue();

      expect(inFlight, 0);
      expect(owners.owner, isNull);
      final next = await openSession();
      await next.hangUp();
    });

    test('closing the server ends the session', () async {
      final session = await openSession();

      await server.close();

      expect(await session.rest(), isEmpty);
    });
  });

  group('model routes', () {
    test('require the owner token', () async {
      final session = await openSession();

      final replies = [
        await client.send('POST', bestieModelPath, body: '{}'),
        await client.send(
          'DELETE',
          bestieModelPath,
          headers: {bestieOwnerHeader: 'wrong'},
        ),
        await client.send('POST', bestieAgentPath('a'), body: '{}'),
        await client.send('DELETE', bestieAgentPath('a')),
      ];

      expect(
        [for (final reply in replies) reply.status],
        [
          for (final _ in replies) HttpStatus.forbidden,
        ],
      );
      expect(replies.first.errorCode, 'owner_required');
      await session.hangUp();
    });

    test('loads a model and answers when it is ready', () async {
      final session = await openSession();

      final reply = await client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: const ModelLoadRequest(
          localId: 'qwen3-1.7b',
          maxAgents: 2,
        ).toMap(),
      );

      expect(reply.status, HttpStatus.ok);
      expect(
        ModelStatusMapper.fromJson(reply.body),
        const ModelReady(
          localId: 'qwen3-1.7b',
          contextSize: 4096,
          maxAgents: 2,
          deviceBytes: 1234,
        ),
      );
      await session.hangUp();
    });

    test('refuses a load body that is not a load request', () async {
      final session = await openSession();

      final notJson = await client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: '{',
      );
      final wrongShape = await client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: '{"max_agents": 1}',
      );

      expect(
        [notJson.status, wrongShape.status],
        [
          HttpStatus.badRequest,
          HttpStatus.badRequest,
        ],
      );
      expect(wrongShape.errorCode, 'invalid_request');
      await session.hangUp();
    });

    test('maps refused loads to their statuses', () async {
      final session = await openSession();

      Future<Reply> load(String localId, {int maxAgents = 1}) => client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: ModelLoadRequest(localId: localId, maxAgents: maxAgents).toMap(),
      );
      final invalid = await load('qwen3-1.7b', maxAgents: 0);
      final unknown = await load('nope');
      fileSystem.file(_indexPath).writeAsStringSync('{');
      final unreadable = await load('qwen3-1.7b');

      expect(
        [invalid.status, unknown.status, unreadable.status],
        [
          HttpStatus.badRequest,
          HttpStatus.notFound,
          HttpStatus.internalServerError,
        ],
      );
      expect(
        [invalid.errorCode, unknown.errorCode, unreadable.errorCode],
        ['invalid_request', 'model_not_found', 'index_unreadable'],
      );
      await session.hangUp();
    });

    test('reports a failed load', () async {
      when(() => engine.load(any())).thenAnswer(
        (_) => Stream.value(const ModelEngineFailed(reason: 'too big')),
      );
      final session = await openSession();

      final reply = await client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: const ModelLoadRequest(
          localId: 'qwen3-1.7b',
          maxAgents: 1,
        ).toMap(),
      );

      expect(reply.status, HttpStatus.internalServerError);
      expect(reply.errorCode, 'model_load_failed');
      await session.hangUp();
    });

    test('answers a load in flight at shutdown as shutting down', () async {
      final loading = StreamController<ModelEngineEvent>();
      when(() => engine.load(any())).thenAnswer((_) => loading.stream);
      final session = await openSession();
      final reply = client.send(
        'POST',
        bestieModelPath,
        headers: _owner,
        body: const ModelLoadRequest(
          localId: 'qwen3-1.7b',
          maxAgents: 1,
        ).toMap(),
      );
      await untilCalled(() => engine.load(any()));

      await http.close();
      await server.close();

      expect((await reply).status, HttpStatus.serviceUnavailable);
      expect((await reply).errorCode, 'shutting_down');
      await session.rest();
      expect(host.status, isA<ModelUnloaded>());
      await loading.close();
    });

    test('unloads the model', () async {
      await loadModel();
      final session = await openSession();

      final reply = await client.send(
        'DELETE',
        bestieModelPath,
        headers: _owner,
      );

      expect(ModelStatusMapper.fromJson(reply.body), const ModelUnloaded());
      verify(model.unload).called(1);
      await session.hangUp();
    });

    test('reports the model status to anyone', () async {
      final reply = await client.send('GET', bestieModelPath);

      expect(ModelStatusMapper.fromJson(reply.body), const ModelUnloaded());
    });
  });

  group('agent routes', () {
    late EventReader session;

    setUp(() async => session = await openSession());

    tearDown(() => session.hangUp());

    Future<Reply> openAgent(String id, {Object? body}) => client.send(
      'POST',
      bestieAgentPath(id),
      headers: _owner,
      body:
          body ?? const AgentOpenRequest(kind: AgentLeaseKind.subagent).toMap(),
    );

    test('need a loaded model', () async {
      final opened = await openAgent('sub:1');
      final closed = await client.send(
        'DELETE',
        bestieAgentPath('sub:1'),
        headers: _owner,
      );

      expect(
        [opened.status, closed.status],
        [
          HttpStatus.serviceUnavailable,
          HttpStatus.serviceUnavailable,
        ],
      );
      expect(opened.errorCode, 'model_not_loaded');
    });

    test('open leases of each kind', () async {
      await loadModel();
      when(() => runtime.openSubagent(any())).thenAnswer(
        (_) async => const AgentLeaseOpened(claimedTokens: 2048),
      );
      when(() => runtime.openPrimary(any())).thenAnswer(
        (_) async => const AgentLeaseOpened(claimedTokens: 0),
      );

      final subagent = await openAgent('sub:1');
      await openAgent(
        'primary:1',
        body: const AgentOpenRequest(kind: AgentLeaseKind.primary).toMap(),
      );

      expect(
        AgentOpenResultMapper.fromJson(subagent.body),
        const AgentOpened(claimedTokens: 2048),
      );
      verifyInOrder([
        () => runtime.openSubagent('sub:1'),
        () => runtime.openPrimary('primary:1'),
      ]);
    });

    test('answer refused leases with their reason', () async {
      await loadModel();
      when(() => runtime.openSubagent('full')).thenAnswer(
        (_) async => const AgentLeaseNoCapacity(),
      );
      when(() => runtime.openSubagent('tight')).thenAnswer(
        (_) async => const AgentLeaseInsufficientClaim(),
      );

      expect(
        AgentOpenResultMapper.fromJson((await openAgent('full')).body),
        const AgentNoCapacity(),
      );
      expect(
        AgentOpenResultMapper.fromJson((await openAgent('tight')).body),
        const AgentInsufficientClaim(),
      );
    });

    test('report a backend failure to lease', () async {
      await loadModel();
      when(() => runtime.openSubagent(any())).thenAnswer(
        (_) async => const AgentLeaseFailed(message: 'no sequence'),
      );

      final reply = await openAgent('sub:1');

      expect(reply.status, HttpStatus.internalServerError);
      expect(reply.errorCode, 'lease_failed');
    });

    test('refuse an open body that is not an open request', () async {
      await loadModel();

      final notJson = await openAgent('sub:1', body: '{');
      final wrongShape = await openAgent('sub:1', body: '{"kind": "boss"}');

      expect(
        [notJson.status, wrongShape.status],
        [
          HttpStatus.badRequest,
          HttpStatus.badRequest,
        ],
      );
    });

    test('answer an unexpected failure with a server error', () async {
      await loadModel();
      when(() => runtime.openSubagent(any())).thenThrow(StateError('broken'));

      final reply = await openAgent('sub:1');

      expect(reply.status, HttpStatus.internalServerError);
      expect(reply.errorCode, 'internal_error');
    });

    test('close leases, decoding the agent id', () async {
      await loadModel();
      when(() => runtime.close('primary:1')).thenAnswer(
        (_) async => const AgentLeaseClosed(),
      );
      when(() => runtime.close('ghost')).thenAnswer(
        (_) async => const AgentLeaseUnknown(),
      );
      when(() => runtime.close('lost')).thenAnswer(
        (_) async => const AgentCloseFailed(message: 'engine gone'),
      );

      final closed = await client.send(
        'DELETE',
        bestieAgentPath('primary:1'),
        headers: _owner,
      );
      final unknown = await client.send(
        'DELETE',
        bestieAgentPath('ghost'),
        headers: _owner,
      );

      final lost = await client.send(
        'DELETE',
        bestieAgentPath('lost'),
        headers: _owner,
      );

      expect(closed.status, HttpStatus.noContent);
      expect(unknown.status, HttpStatus.notFound);
      expect(unknown.errorCode, 'agent_not_found');
      expect(lost.status, HttpStatus.internalServerError);
      expect(lost.errorCode, 'lease_failed');
    });
  });

  group('chat completions', () {
    test('refuse a request that cannot be read', () async {
      final reply = await client.send('POST', _chatPath, body: '{}');

      expect(reply.status, HttpStatus.badRequest);
      expect(reply.errorCode, 'invalid_request');
    });

    test('need a loaded model', () async {
      final reply = await client.send('POST', _chatPath, body: _hello);

      expect(reply.status, HttpStatus.serviceUnavailable);
      expect(reply.errorCode, 'model_not_loaded');
    });

    test('refuse a model other than the loaded one', () async {
      await loadModel();

      final reply = await client.send(
        'POST',
        _chatPath,
        body: {..._hello, 'model': 'gemma'},
      );

      expect(reply.status, HttpStatus.notFound);
      expect(reply.errorCode, 'model_not_found');
    });

    test('refuse a token limit below one', () async {
      await loadModel();

      final reply = await client.send(
        'POST',
        _chatPath,
        body: {..._hello, 'max_tokens': 0},
      );

      expect(reply.status, HttpStatus.badRequest);
      expect(reply.errorCode, 'invalid_request');
    });

    test('require the owner token to complete for an agent', () async {
      await loadModel();
      final session = await openSession();

      final missing = await client.send(
        'POST',
        _chatPath,
        headers: {bestieAgentHeader: 'primary:1'},
        body: _hello,
      );
      final wrong = await client.send(
        'POST',
        _chatPath,
        headers: {bestieAgentHeader: 'primary:1', bestieOwnerHeader: 'nope'},
        body: _hello,
      );

      expect(
        [missing.status, wrong.status],
        [
          HttpStatus.forbidden,
          HttpStatus.forbidden,
        ],
      );
      expect(missing.errorCode, 'owner_required');
      verifyNever(() => runtime.complete(any()));
      await session.hangUp();
    });

    test('answer a whole completion', () async {
      await loadModel();
      final session = await openSession();
      completes(const [
        CompletionTextDelta('Hi'),
        CompletionFinished(reason: CompletionStopReason.stop, usage: _usage),
      ]);

      final reply = await client.send(
        'POST',
        _chatPath,
        headers: {bestieAgentHeader: 'primary:1', ..._owner},
        body: {
          ..._hello,
          'model': 'qwen3-1.7b',
          'temperature': 0.1,
          'max_tokens': 8,
          'stop': ['END', 'STOP'],
          'chat_template_kwargs': {'enable_thinking': false},
        },
      );
      await session.hangUp();

      expect(reply.status, HttpStatus.ok);
      expect(reply.object['id'], 'chatcmpl-1');
      expect(reply.object['created'], 5);
      expect(reply.object['model'], 'qwen3-1.7b');
      expect(
        (((reply.object['choices']! as List).single as Map)['message']
            as Map)['content'],
        'Hi',
      );
      final request = sentRequest();
      expect(request.agentId, 'primary:1');
      expect(request.reasoningMode, 'off');
      expect(request.maxTokens, 8);
      expect(request.stopSequences, ['END', 'STOP']);
      expect(
        request.sampling,
        const EngineSampling(temperature: 0.1, topK: 20),
      );
      expect(
        request.messages.single,
        isA<PromptUserMessage>().having(
          (message) => message.content,
          'content',
          'hi',
        ),
      );
    });

    test('answer a whole completion that failed with an error', () async {
      await loadModel();
      completes(const [
        CompletionFailed(failure: CompletionFailure.cancelled, message: 'gone'),
      ]);

      final reply = await client.send('POST', _chatPath, body: _hello);

      expect(reply.status, HttpStatus.internalServerError);
      expect(reply.errorCode, 'cancelled');
    });

    test('stream a completion, then its usage', () async {
      await loadModel();
      completes(const [
        CompletionReasoningDelta('hmm'),
        CompletionTextDelta('Hi'),
        CompletionToolCalled(id: 'call_1', name: 'read', argumentsJson: '{}'),
        CompletionFinished(
          reason: CompletionStopReason.toolCalls,
          usage: _usage,
        ),
      ]);

      final stream = await client.events(
        _chatPath,
        method: 'POST',
        body: {
          ..._hello,
          'stream': true,
          'stream_options': {'include_usage': true},
        },
      );
      final events = await stream.rest();

      expect(
        stream.response.headers.contentType?.mimeType,
        'text/event-stream',
      );
      expect(events.last, '[DONE]');
      final chunks = [
        for (final data in events.take(events.length - 1))
          jsonDecode(data) as Map<String, Object?>,
      ];
      Object? deltaOf(Map<String, Object?> chunk) =>
          ((chunk['choices']! as List).single as Map)['delta'];
      expect(deltaOf(chunks[0]), {'role': 'assistant'});
      expect(deltaOf(chunks[1]), {'reasoning_content': 'hmm'});
      expect(deltaOf(chunks[2]), {'content': 'Hi'});
      expect(deltaOf(chunks[3]), contains('tool_calls'));
      expect(
        ((chunks[4]['choices']! as List).single as Map)['finish_reason'],
        'tool_calls',
      );
      expect(chunks[5]['usage'], containsPair('total_tokens', 5));
      expect(sentRequest().agentId, isNull);
    });

    test('stream a failure as an error event', () async {
      await loadModel();
      completes(const [
        CompletionFailed(
          failure: CompletionFailure.contextExceeded,
          message: 'full',
        ),
      ]);

      final stream = await client.events(
        _chatPath,
        method: 'POST',
        body: {..._hello, 'stream': true},
      );
      final events = await stream.rest();

      expect(events, hasLength(3));
      expect(
        (jsonDecode(events[1]) as Map)['error'],
        containsPair('code', 'context_length_exceeded'),
      );
      expect(events.last, '[DONE]');
    });

    test('a completion that breaks ends its stream', () async {
      await loadModel();
      when(() => runtime.complete(any())).thenAnswer(
        (_) async => CompletionStarted(Stream.error(StateError('torn'))),
      );

      final stream = await client.events(
        _chatPath,
        method: 'POST',
        body: {..._hello, 'stream': true},
      );

      expect(await stream.rest(), hasLength(1));
      verify(() => log.error(any(that: contains('torn')))).called(1);
    });

    test('hanging up on a whole completion cancels it', () async {
      await loadModel();
      final cancelled = Completer<void>();
      final events = StreamController<CompletionEvent>(
        onCancel: cancelled.complete,
      );
      when(() => runtime.complete(any())).thenAnswer(
        (_) async => CompletionStarted(events.stream),
      );
      final socket = await client.raw('POST', _chatPath, body: _hello);
      await untilCalled(() => runtime.complete(any()));
      events.add(const CompletionTextDelta('Hi'));

      socket.destroy();

      await cancelled.future;
      await pumpEventQueue();
      expect(inFlight, 0);
    });

    test('hanging up cancels the completion', () async {
      await loadModel();
      final cancelled = Completer<void>();
      final events = StreamController<CompletionEvent>(
        onCancel: cancelled.complete,
      );
      when(() => runtime.complete(any())).thenAnswer(
        (_) async => CompletionStarted(events.stream),
      );
      final stream = await client.events(
        _chatPath,
        method: 'POST',
        body: {..._hello, 'stream': true},
      );
      events.add(const CompletionTextDelta('Hi'));
      await stream.next();
      await stream.next();

      await stream.hangUp();

      await cancelled.future;
    });

    test('map refused completions to their statuses', () async {
      await loadModel();
      final statuses = <int>[];
      final codes = <Object?>[];
      for (final reason in CompletionRejection.values) {
        when(() => runtime.complete(any())).thenAnswer(
          (_) async => CompletionRejected(reason: reason, message: reason.name),
        );
        final reply = await client.send('POST', _chatPath, body: _hello);
        statuses.add(reply.status);
        codes.add(reply.errorCode);
      }

      expect(statuses, [
        HttpStatus.notFound,
        HttpStatus.conflict,
        HttpStatus.serviceUnavailable,
        HttpStatus.badRequest,
        HttpStatus.badRequest,
        HttpStatus.internalServerError,
        HttpStatus.serviceUnavailable,
      ]);
      expect(codes, [
        'agent_not_found',
        'agent_busy',
        'no_capacity',
        'context_length_exceeded',
        'prompt_unreadable',
        'engine_failed',
        'model_unloading',
      ]);
    });
  });
}
