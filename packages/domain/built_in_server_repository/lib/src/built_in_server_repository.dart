import 'dart:async';

import 'package:built_in_server_repository/src/models/built_in_server_status.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/provider_local.dart';
import 'package:rxdart/rxdart.dart';

/// Owns this bestie's hold on the built-in inference server: starts and
/// stops it, says how it loads models, and reports what it is doing.
@repository
class BuiltInServerRepository {
  BuiltInServerRepository({required BuiltInServerClient client})
    : _client = client {
    _statusController = BehaviorSubject.seeded(_project());
    _subscriptions = [
      client.connectionChanges.listen((connection) {
        _connection = connection;
        _publish();
      }),
      client.modelStatusChanges.listen((model) {
        _model = model;
        _publish();
      }),
      client.poolSnapshots.listen((pool) {
        _pool = pool;
        _publish();
      }),
    ];
  }

  final BuiltInServerClient _client;
  late final BehaviorSubject<BuiltInServerStatus> _statusController;
  late final List<StreamSubscription<Object>> _subscriptions;
  BuiltInServerConnection _connection = const BuiltInServerDisconnected();
  ModelStatus _model = const ModelUnloaded();
  PoolSnapshotEvent? _pool;

  /// What the server is doing, now and whenever it changes.
  Stream<BuiltInServerStatus> get statusStream => _statusController.stream;

  BuiltInServerStatus get status => _statusController.value;

  /// Takes the server, finding or starting it first; the status says how
  /// that went.
  Future<void> start() => _client.attach();

  /// Unloads the model and lets the server go; a server left with nothing
  /// connected exits.
  Future<void> stop() => _client.release();

  /// Lets the server go and takes it again.
  Future<void> restart() async {
    await _client.release();
    await _client.attach();
  }

  /// Loads every model from now on the way [options] say.
  void configure(ModelLoadOptions options) => _client.configure(options);

  /// Lets the server go for good and closes every stream.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _client.close();
    await _statusController.close();
  }

  BuiltInServerStatus _project() =>
      BuiltInServerStatus.of(_connection, _model, _pool);

  void _publish() => _statusController.add(_project());
}
