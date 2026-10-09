import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:inference_server/src/chat/chat_request.dart';
import 'package:inference_server/src/chat/chat_response.dart';
import 'package:inference_server/src/http/client_connection.dart';
import 'package:inference_server/src/http/json_reply.dart';
import 'package:inference_server/src/lifetime/server_lifetime.dart';
import 'package:inference_server/src/model_host.dart';
import 'package:inference_server/src/model_index_reader.dart';
import 'package:inference_server/src/owner_session.dart';
import 'package:inference_server/src/server_log.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

const _modelsPath = '/v1/models';
const _chatPath = '/v1/chat/completions';
const _agentsPrefix = '/bestie/v1/agents/';

typedef _Handler = Future<void> Function(HttpRequest request);

/// Answers the OpenAI routes and bestie's session, lease, and model routes.
final class InferenceServer {
  InferenceServer({
    required ModelHost host,
    required ModelIndexReader index,
    required OwnerSessions owners,
    required ServerLifetime lifetime,
    required ServerLog log,
    required String serverVersion,
    required int pid,
    required DateTime Function() now,
    required String Function() mintCompletionId,
  }) : _host = host,
       _index = index,
       _owners = owners,
       _lifetime = lifetime,
       _log = log,
       _serverVersion = serverVersion,
       _pid = pid,
       _now = now,
       _mintCompletionId = mintCompletionId {
    _statusSubscription = _host.statusChanges.listen(_onModelStatus);
  }

  final ModelHost _host;
  final ModelIndexReader _index;
  final OwnerSessions _owners;
  final ServerLifetime _lifetime;
  final ServerLog _log;
  final String _serverVersion;
  final int _pid;
  final DateTime Function() _now;
  final String Function() _mintCompletionId;
  late final StreamSubscription<ModelStatus> _statusSubscription;
  StreamSubscription<PoolSnapshot>? _poolSubscription;
  final _connections = <ClientConnection>{};
  final _answering = <Future<void>>{};

  /// Answers every request [server] receives until it closes.
  Future<void> serve(Stream<HttpRequest> server) async {
    await server.forEach((request) {
      final answer = _answer(request);
      _answering.add(answer);
      unawaited(answer.whenComplete(() => _answering.remove(answer)));
    });
  }

  /// Ends every open connection, shuts the model host down so a load in
  /// flight is answered as interrupted, waits for every answer under way,
  /// and stops listening to the model.
  Future<void> close() async {
    await Future.wait([
      for (final connection in [..._connections]) connection.end(),
    ]);
    await _host.dispose();
    await Future.wait([..._answering]);
    await _statusSubscription.cancel();
    await _poolSubscription?.cancel();
  }

  /// Answers [request] as a connection that keeps the server up. The health
  /// probe is how clients look for a server, so it neither keeps one up nor
  /// ends its startup grace.
  Future<void> _answer(HttpRequest request) async {
    if (_lifetime.shuttingDown) return _shuttingDown(request);
    if (request.uri.path == bestieHealthPath) return _route(request);
    _lifetime.opened();
    try {
      await _route(request);
    } finally {
      _lifetime.closed();
    }
  }

  Future<void> _shuttingDown(HttpRequest request) => replyError(
    request,
    status: HttpStatus.serviceUnavailable,
    code: 'shutting_down',
    type: 'server_error',
    message: 'The server is shutting down.',
  );

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    _log.info('${request.method} $path');
    final method = request.method;
    final handler = switch (path) {
      bestieHealthPath => _byMethod(method, get: _health),
      _modelsPath => _byMethod(method, get: _models),
      _chatPath => _byMethod(method, post: _chat),
      bestieSessionPath => _byMethod(method, get: _session),
      bestieModelPath => _byMethod(
        method,
        get: _modelStatus,
        post: _owned(_loadModel),
        delete: _owned(_unloadModel),
      ),
      _ when path.startsWith(_agentsPrefix) => _byMethod(
        method,
        post: _owned(_openAgent),
        delete: _owned(_closeAgent),
      ),
      _ => _notFound,
    };
    try {
      await handler(request);
    } on Object catch (error) {
      _log.error('${request.method} $path failed: $error');
      await Future.sync(
        () => replyError(
          request,
          status: HttpStatus.internalServerError,
          code: 'internal_error',
          type: 'server_error',
          message: '$error',
        ),
      ).then((_) {}, onError: (Object _) {});
    }
  }

  _Handler _byMethod(
    String method, {
    _Handler? get,
    _Handler? post,
    _Handler? delete,
  }) =>
      switch (method) {
        'GET' => get,
        'POST' => post,
        'DELETE' => delete,
        _ => null,
      } ??
      _methodNotAllowed;

  Future<void> _methodNotAllowed(HttpRequest request) => replyError(
    request,
    status: HttpStatus.methodNotAllowed,
    code: 'method_not_allowed',
    message: '${request.method} is not allowed on ${request.uri.path}.',
  );

  _Handler _owned(_Handler handler) =>
      (request) => _owners.authorizes(request.headers.value(bestieOwnerHeader))
      ? handler(request)
      : _ownerRequired(request);

  Future<void> _ownerRequired(HttpRequest request) => replyError(
    request,
    status: HttpStatus.forbidden,
    code: 'owner_required',
    message: 'Only the owner session may do this.',
  );

  Future<void> _notFound(HttpRequest request) => replyError(
    request,
    status: HttpStatus.notFound,
    code: 'not_found',
    message: 'No route for ${request.method} ${request.uri.path}.',
  );

  Future<void> _health(HttpRequest request) => replyEncoded(
    request,
    HealthResponse(
      protocolVersion: bestieProtocolVersion,
      serverVersion: _serverVersion,
      pid: _pid,
    ).toJson(),
  );

  Future<void> _models(HttpRequest request) async {
    final List<ModelIndexEntry> entries;
    switch (await _index.read()) {
      case ModelIndexRead(:final index, :final skippedEntries):
        if (skippedEntries > 0) {
          _log.error('Skipped $skippedEntries index entries it cannot load.');
        }
        entries = index.models;
      case ModelIndexMissing():
        entries = const [];
      case ModelIndexMalformed(:final message):
        return replyError(
          request,
          status: HttpStatus.internalServerError,
          code: 'index_unreadable',
          type: 'server_error',
          message: message,
        );
    }
    final loadedId = _host.hosted?.entry.localId;
    final created = _now().millisecondsSinceEpoch ~/ 1000;
    await replyEncoded(
      request,
      BestieModelList(
        data: [
          for (final entry in entries)
            BestieModel(
              id: entry.localId,
              created: created,
              contextLength: entry.trainedContextLength,
              bestie: BestieModelFacts(
                loaded: entry.localId == loadedId,
                reasoning: entry.reasoning,
                displayName: entry.displayName,
                fileType: entry.fileType,
                sizeBytes: entry.sizeBytes,
              ),
            ),
        ],
      ).toJson(),
    );
  }

  Future<void> _session(HttpRequest request) async {
    final pid =
        int.tryParse(request.headers.value(bestieOwnerPidHeader) ?? '') ?? 0;
    await _holding(request, (connection) async {
      switch (_owners.claim(pid: pid)) {
        case OwnerRefused(:final ownerPid):
          await connection.reply(
            ServerBusy(ownerPid: ownerPid).toJson(),
            status: ServerBusy.statusCode,
          );
        case OwnerGranted(:final owner):
          await _hostSession(connection, owner);
      }
    });
  }

  Future<void> _hostSession(ClientConnection connection, Owner owner) async {
    _log.info('Owner session opened by pid ${owner.pid}.');
    connection.startEvents();
    final forwarding = owner.events.listen(
      (event) => connection.send(jsonDecode(event.toJson())),
    );
    try {
      owner
        ..send(SessionOpened(ownerToken: owner.token))
        ..send(ModelStatusEvent(status: _host.status));
      final runtime = _host.hosted?.model.runtime;
      if (runtime != null) owner.send(_poolEvent(runtime.pool));
      await connection.closed;
    } finally {
      await forwarding.cancel();
      _owners.release(owner);
      await _host.hosted?.model.runtime.closeAll();
      _log.info('Owner session closed; every lease was released.');
    }
  }

  /// Takes [request]'s connection for [work], ending it however the work
  /// ends.
  Future<void> _holding(
    HttpRequest request,
    Future<void> Function(ClientConnection connection) work,
  ) async {
    final connection = await ClientConnection.take(request);
    _connections.add(connection);
    try {
      await work(connection);
    } finally {
      await connection.end();
      _connections.remove(connection);
    }
  }

  void _onModelStatus(ModelStatus status) {
    _owners.send(ModelStatusEvent(status: status));
    unawaited(_poolSubscription?.cancel());
    _poolSubscription = _host.hosted?.model.runtime.poolChanges.listen(
      (pool) => _owners.send(_poolEvent(pool)),
    );
  }

  static PoolSnapshotEvent _poolEvent(PoolSnapshot pool) => PoolSnapshotEvent(
    contextSize: pool.contextSize,
    maxAgents: pool.maxAgents,
    borrowedTokens: pool.borrowedTokens,
    agents: [
      for (final agent in pool.agents)
        PoolAgent(
          id: agent.id,
          kind: switch (agent) {
            PrimaryPoolLease() => AgentLeaseKind.primary,
            SubagentPoolLease() => AgentLeaseKind.subagent,
          },
          claimedTokens: agent.claimedTokens,
          usedTokens: agent.usedTokens,
        ),
    ],
  );

  Future<void> _modelStatus(HttpRequest request) =>
      replyEncoded(request, _host.status.toJson());

  Future<void> _loadModel(HttpRequest request) async {
    final ModelLoadRequest load;
    try {
      load = ModelLoadRequestMapper.fromJson(await _bodyOf(request));
    } on MapperException catch (error) {
      return _invalidBody(request, error.message);
    } on FormatException catch (error) {
      return _invalidBody(request, error.message);
    }
    switch (await _host.load(load)) {
      case ModelLoadSucceeded(:final ready):
        await replyEncoded(request, ready.toJson());
      case ModelLoadRejected(:final reason, :final message):
        await replyError(
          request,
          status: switch (reason) {
            ModelLoadRejection.invalidRequest => HttpStatus.badRequest,
            ModelLoadRejection.unknownModel => HttpStatus.notFound,
            ModelLoadRejection.indexUnreadable =>
              HttpStatus.internalServerError,
          },
          code: switch (reason) {
            ModelLoadRejection.invalidRequest => 'invalid_request',
            ModelLoadRejection.unknownModel => 'model_not_found',
            ModelLoadRejection.indexUnreadable => 'index_unreadable',
          },
          message: message,
        );
      case ModelLoadFailed(:final reason):
        await replyError(
          request,
          status: HttpStatus.internalServerError,
          code: 'model_load_failed',
          type: 'server_error',
          message: reason,
        );
      case ModelLoadInterrupted():
        await replyError(
          request,
          status: HttpStatus.serviceUnavailable,
          code: 'shutting_down',
          type: 'server_error',
          message: 'The server shut down before the model loaded.',
        );
    }
  }

  Future<void> _unloadModel(HttpRequest request) async {
    await _host.unload();
    await replyEncoded(request, _host.status.toJson());
  }

  Future<void> _openAgent(HttpRequest request) async {
    final runtime = _host.hosted?.model.runtime;
    if (runtime == null) return _modelNotLoaded(request);
    final AgentOpenRequest open;
    try {
      open = AgentOpenRequestMapper.fromJson(await _bodyOf(request));
    } on MapperException catch (error) {
      return _invalidBody(request, error.message);
    } on FormatException catch (error) {
      return _invalidBody(request, error.message);
    }
    final agentId = _agentIdOf(request);
    final AgentOpenResult result;
    switch (await switch (open.kind) {
      AgentLeaseKind.primary => runtime.openPrimary(agentId),
      AgentLeaseKind.subagent => runtime.openSubagent(agentId),
    }) {
      case AgentLeaseOpened(:final claimedTokens):
        result = AgentOpened(claimedTokens: claimedTokens);
      case AgentLeaseNoCapacity():
        result = const AgentNoCapacity();
      case AgentLeaseInsufficientClaim():
        result = const AgentInsufficientClaim();
      case AgentLeaseFailed(:final message):
        return replyError(
          request,
          status: HttpStatus.internalServerError,
          code: 'lease_failed',
          type: 'server_error',
          message: message,
        );
    }
    await replyEncoded(request, result.toJson());
  }

  Future<void> _closeAgent(HttpRequest request) async {
    final runtime = _host.hosted?.model.runtime;
    if (runtime == null) return _modelNotLoaded(request);
    final agentId = _agentIdOf(request);
    switch (await runtime.close(agentId)) {
      case AgentCloseFailed(:final message):
        await replyError(
          request,
          status: HttpStatus.internalServerError,
          code: 'lease_failed',
          type: 'server_error',
          message: message,
        );
      case AgentLeaseClosed():
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      case AgentLeaseUnknown():
        await replyError(
          request,
          status: HttpStatus.notFound,
          code: 'agent_not_found',
          message: 'No lease is open for agent $agentId.',
        );
    }
  }

  static String _agentIdOf(HttpRequest request) =>
      Uri.decodeComponent(request.uri.path.substring(_agentsPrefix.length));

  Future<void> _chat(HttpRequest request) async {
    final agentId = request.headers.value(bestieAgentHeader);
    if (agentId != null &&
        !_owners.authorizes(request.headers.value(bestieOwnerHeader))) {
      return _ownerRequired(request);
    }
    final ChatRequest chat;
    switch (ChatRequestParser.parse(await _bodyOf(request))) {
      case ChatRequestParsed(:final request):
        chat = request;
      case ChatRequestInvalid(:final message):
        return _invalidBody(request, message);
    }
    final hosted = _host.hosted;
    if (hosted == null) return _modelNotLoaded(request);
    final entry = hosted.entry;
    final model = chat.model;
    if (model != null && model != entry.localId) {
      return replyError(
        request,
        status: HttpStatus.notFound,
        code: 'model_not_found',
        message: 'Model $model is not loaded; ${entry.localId} is.',
      );
    }
    await _holding(request, (connection) async {
      final started = await hosted.model.runtime.complete(
        CompletionRequest(
          agentId: agentId,
          messages: chat.messages,
          tools: chat.tools,
          reasoningMode: chat.reasoningModeFor(entry.reasoning),
          sampling: chat.samplingOver(entry.defaultSampling),
          maxTokens: chat.maxTokens,
          stopSequences: chat.stopSequences,
        ),
      );
      final response = ChatResponse(
        id: 'chatcmpl-${_mintCompletionId()}',
        model: entry.localId,
        created: _now().millisecondsSinceEpoch ~/ 1000,
      );
      switch (started) {
        case CompletionRejected(:final reason, :final message):
          await _rejectCompletion(connection, reason, message);
        case CompletionStarted(:final events) when chat.stream:
          await _streamCompletion(
            connection,
            _logged(events, agentId),
            response,
            includeUsage: chat.includeUsage,
          );
        case CompletionStarted(:final events):
          await _wholeCompletion(
            connection,
            _logged(events, agentId),
            response,
          );
      }
    });
  }

  Stream<CompletionEvent> _logged(
    Stream<CompletionEvent> events,
    String? agentId,
  ) => events.map((event) {
    switch (event) {
      case CompletionFinished(:final reason, :final usage):
        _log.info(
          'Completion for ${agentId ?? 'a borrowed sequence'} finished '
          '(${reason.name}): ${usage.promptTokens} prompt tokens, '
          '${usage.cachedTokens} reused, ${usage.completionTokens} generated.',
        );
      case CompletionFailed(:final failure, :final message):
        _log.error(
          'Completion for ${agentId ?? 'a borrowed sequence'} failed '
          '(${failure.name}): $message',
        );
      case CompletionReasoningDelta() ||
          CompletionTextDelta() ||
          CompletionToolCalled():
        break;
    }
    return event;
  });

  Future<void> _streamCompletion(
    ClientConnection connection,
    Stream<CompletionEvent> events,
    ChatResponse response, {
    required bool includeUsage,
  }) {
    connection
      ..startEvents()
      ..send(response.opening);
    return _relay(
      connection,
      events,
      onEvent: (event) => response
          .chunksFor(event, includeUsage: includeUsage)
          .forEach(connection.send),
      onDone: connection.finish,
    );
  }

  Future<void> _wholeCompletion(
    ClientConnection connection,
    Stream<CompletionEvent> events,
    ChatResponse response,
  ) {
    final collected = <CompletionEvent>[];
    return _relay(
      connection,
      events,
      onEvent: collected.add,
      onDone: () => switch (collected.last) {
        final CompletionFailed failed => connection.reply(
          jsonEncode(ChatResponse.errorFor(failed)),
          status: HttpStatus.internalServerError,
        ),
        _ => connection.reply(jsonEncode(response.whole(collected))),
      },
    );
  }

  /// Passes [events] on until they end or the client hangs up; hanging up
  /// cancels the completion.
  Future<void> _relay(
    ClientConnection connection,
    Stream<CompletionEvent> events, {
    required void Function(CompletionEvent event) onEvent,
    required Future<void> Function() onDone,
  }) async {
    final subscription = events.listen(
      onEvent,
      onError: (Object error) {
        _log.error('A completion broke: $error');
        unawaited(connection.end());
      },
      onDone: () => unawaited(onDone()),
    );
    await connection.closed;
    await subscription.cancel();
  }

  Future<void> _rejectCompletion(
    ClientConnection connection,
    CompletionRejection reason,
    String message,
  ) => connection.reply(
    jsonEncode(
      openAiError(
        message: message,
        type: switch (reason) {
          CompletionRejection.engineFailed => 'server_error',
          _ => 'invalid_request_error',
        },
        code: switch (reason) {
          CompletionRejection.unknownAgent => 'agent_not_found',
          CompletionRejection.agentBusy => 'agent_busy',
          CompletionRejection.noCapacity => 'no_capacity',
          CompletionRejection.promptTooLarge => 'context_length_exceeded',
          CompletionRejection.promptUnreadable => 'prompt_unreadable',
          CompletionRejection.engineFailed => 'engine_failed',
          CompletionRejection.disposed => 'model_unloading',
        },
      ),
    ),
    status: switch (reason) {
      CompletionRejection.unknownAgent => HttpStatus.notFound,
      CompletionRejection.agentBusy => HttpStatus.conflict,
      CompletionRejection.promptTooLarge ||
      CompletionRejection.promptUnreadable => HttpStatus.badRequest,
      CompletionRejection.engineFailed => HttpStatus.internalServerError,
      CompletionRejection.noCapacity ||
      CompletionRejection.disposed => HttpStatus.serviceUnavailable,
    },
  );

  Future<void> _modelNotLoaded(HttpRequest request) => replyError(
    request,
    status: HttpStatus.serviceUnavailable,
    code: 'model_not_loaded',
    type: 'server_error',
    message: 'No model is loaded.',
  );

  Future<void> _invalidBody(HttpRequest request, String message) => replyError(
    request,
    status: HttpStatus.badRequest,
    code: 'invalid_request',
    message: message,
  );

  static Future<String> _bodyOf(HttpRequest request) =>
      utf8.decoder.bind(request).join();
}
