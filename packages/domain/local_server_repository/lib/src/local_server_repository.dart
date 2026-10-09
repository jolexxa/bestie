import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_server_repository/src/local_server_status.dart';
import 'package:rxdart/rxdart.dart';

/// Follows what the local inference server is doing for this window: the
/// owner session, the model's status, and the agent pool, folded into one
/// status. It only watches; the provider that runs local models decides
/// when the server is taken and let go.
@repository
class LocalServerRepository {
  LocalServerRepository({required LocalInferenceClient client})
    : _connection = client.connection,
      _model = client.modelStatus {
    _status = BehaviorSubject.seeded(_fold());
    _subscriptions = [
      client.connectionChanges.listen(_onConnection),
      client.modelStatusChanges.listen(_onModel),
      client.poolSnapshots.listen(_onPool),
    ];
  }

  LocalServerConnection _connection;
  ModelStatus _model;
  LocalAgentPool? _pool;
  late final BehaviorSubject<LocalServerStatus> _status;
  late final List<StreamSubscription<Object>> _subscriptions;

  /// The status as it changes, opening with [current].
  Stream<LocalServerStatus> get status => _status.stream;

  LocalServerStatus get current => _status.value;

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _status.close();
  }

  void _onConnection(LocalServerConnection connection) {
    _connection = connection;
    if (connection is! LocalServerAttached) _pool = null;
    _status.add(_fold());
  }

  void _onModel(ModelStatus model) {
    _model = model;
    if (model is! ModelReady) _pool = null;
    _status.add(_fold());
  }

  void _onPool(PoolSnapshotEvent snapshot) {
    _pool = LocalAgentPool(
      leased: snapshot.agents.length,
      maxAgents: snapshot.maxAgents,
    );
    _status.add(_fold());
  }

  LocalServerStatus _fold() => switch (_connection) {
    LocalServerBusy(:final ownerPid) => ServerOwnedElsewhere(
      ownerPid: ownerPid,
    ),
    LocalServerVersionMismatch(:final serverVersion, :final protocolVersion) =>
      ServerIncompatible(
        serverVersion: serverVersion,
        protocolVersion: protocolVersion,
      ),
    LocalServerSpawnFailed(:final reason) ||
    LocalServerDisconnected(:final reason?) => ServerFailed(reason),
    LocalServerDisconnected() => const ServerIdle(),
    LocalServerAttaching() => const ServerStarting(),
    LocalServerAttached() => _modelStatus(),
  };

  LocalServerStatus _modelStatus() => switch (_model) {
    ModelUnloaded() => const ServerStarting(),
    ModelFitting(:final localId) => ServerLoading(localId: localId),
    ModelLoading(:final localId, :final progress) => ServerLoading(
      localId: localId,
      progress: progress,
    ),
    ModelReady(
      :final localId,
      :final contextSize,
      :final maxAgents,
      :final deviceBytes,
    ) =>
      ServerServing(
        localId: localId,
        contextSize: contextSize,
        maxAgents: maxAgents,
        deviceBytes: deviceBytes,
        pool: _pool,
      ),
    ModelFailed(:final localId, :final reason) => ServerLoadFailed(
      localId: localId,
      reason: reason,
    ),
  };
}
