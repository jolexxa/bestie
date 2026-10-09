import 'dart:async';
import 'dart:convert';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// The server's request-and-answer routes, each answered with a sealed
/// result instead of an exception.
@PartOf(LocalInferenceClient)
final class ServerApi {
  ServerApi({required http.Client client, required Duration healthTimeout})
    : _client = client,
      _healthTimeout = healthTimeout;

  final http.Client _client;
  final Duration _healthTimeout;

  static Uri urlFor(int port, String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: path);

  /// The handshake, or null when nothing answers on [port] in time.
  Future<HealthResponse?> health(int port) async {
    try {
      final response = await _client
          .get(urlFor(port, bestieHealthPath))
          .timeout(_healthTimeout);
      if (response.statusCode != 200) return null;
      return HealthResponseMapper.fromJson(response.body);
    } on Object {
      return null;
    }
  }

  Future<ModelLoadResult> load(
    LocalServerAttached owner,
    ModelLoadRequest request,
  ) async {
    try {
      final response = await _client.post(
        urlFor(owner.port, bestieModelPath),
        headers: _ownedJson(owner),
        body: request.toJson(),
      );
      if (response.statusCode != 200) {
        return ModelLoadFailed(_reasonIn(response));
      }
      return switch (ModelStatusMapper.fromJson(response.body)) {
        final ModelReady ready => ModelLoaded(ready),
        final ModelStatus other => ModelLoadFailed(
          'The server answered the load with ${other.runtimeType}.',
        ),
      };
    } on Object catch (error) {
      return ModelLoadFailed(_describe(error));
    }
  }

  Future<ModelUnloadResult> unload(LocalServerAttached owner) async {
    try {
      final response = await _client.delete(
        urlFor(owner.port, bestieModelPath),
        headers: _owned(owner),
      );
      return response.statusCode == 200
          ? const ModelUnloadSucceeded()
          : ModelUnloadFailed(_reasonIn(response));
    } on Object catch (error) {
      return ModelUnloadFailed(_describe(error));
    }
  }

  Future<AgentSessionResult> openLease(
    LocalServerAttached owner,
    AgentIdentity agent,
  ) async {
    try {
      final response = await _client.post(
        urlFor(owner.port, bestieAgentPath(agent.id)),
        headers: _ownedJson(owner),
        body: AgentOpenRequest(kind: _leaseKindOf(agent.kind)).toJson(),
      );
      if (response.statusCode != 200) {
        return AgentSessionFailed(message: _reasonIn(response));
      }
      return switch (AgentOpenResultMapper.fromJson(response.body)) {
        AgentOpened(:final claimedTokens) => AgentSessionOpened(
          claimedTokens: claimedTokens,
        ),
        AgentNoCapacity() => const AgentSessionNoCapacity(),
        AgentInsufficientClaim() => const AgentSessionInsufficientClaim(),
      };
    } on Object catch (error) {
      return AgentSessionFailed(message: _describe(error));
    }
  }

  /// Releases the lease; an unknown agent or an unreachable server leaves
  /// nothing to release.
  Future<void> closeLease(LocalServerAttached owner, String agentId) async {
    try {
      await _client.delete(
        urlFor(owner.port, bestieAgentPath(agentId)),
        headers: _owned(owner),
      );
    } on Object {
      return;
    }
  }

  static AgentLeaseKind _leaseKindOf(AgentIdentityKind kind) => switch (kind) {
    AgentIdentityKind.primary => AgentLeaseKind.primary,
    AgentIdentityKind.subagent => AgentLeaseKind.subagent,
  };

  static Map<String, String> _owned(LocalServerAttached owner) => {
    bestieOwnerHeader: owner.ownerToken,
  };

  static Map<String, String> _ownedJson(LocalServerAttached owner) => {
    ..._owned(owner),
    'Content-Type': 'application/json',
  };

  /// The message of an OpenAI-style error body, else the status.
  static String _reasonIn(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body case {'error': {'message': final String message}}) {
        return message;
      }
    } on FormatException {
      // Not JSON; the status says enough.
    }
    return 'The local model server answered HTTP ${response.statusCode}.';
  }

  static String _describe(Object error) => switch (error) {
    http.ClientException(:final message) => message,
    MapperException(:final message) => 'Unreadable answer: $message',
    FormatException(:final message) => 'Unreadable answer: $message',
    TimeoutException() => 'The local model server did not answer in time.',
    _ => '$error',
  };
}
