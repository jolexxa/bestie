import 'dart:async';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/connection/server_connection_data.dart';
import 'package:local_inference_client/src/connection/server_connection_input.dart';
import 'package:local_inference_client/src/connection/server_connection_logic.dart';
import 'package:local_inference_client/src/connection/server_connection_output.dart';
import 'package:local_inference_client/src/local_provider.dart';
import 'package:local_inference_client/src/local_server_link.dart';
import 'package:local_inference_client/src/model_index_file.dart';
import 'package:local_inference_client/src/models/local_provider_options.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/local_server_launch.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_client/src/owner_session.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_client/src/server_attacher.dart';
import 'package:local_inference_client/src/server_discovery.dart';
import 'package:local_inference_client/src/server_spawner.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:meta/meta.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// This bestie's link to the local inference server: it finds or starts the
/// server, holds the owner session that lets this bestie lease agents and
/// load models, and reports what the session says.
@dataSource
class LocalInferenceClient implements LocalServerLink {
  LocalInferenceClient({
    required http.Client client,
    required http.Client Function() sessionClientFactory,
    required FileSystem fileSystem,
    required String lockFile,
    required String indexFile,
    required LocalServerLaunch launch,
    required int pid,
    ServerSpawner spawner = const DetachedServerSpawner(),
    Clock clock = const Clock(),
    Duration startTimeout = const Duration(seconds: 90),
    Duration healthTimeout = const Duration(seconds: 5),
  }) : _index = ModelIndexFile(fileSystem: fileSystem, path: indexFile) {
    final api = ServerApi(client: client, healthTimeout: healthTimeout);
    _logic = ServerConnectionLogic(
      attacher: ServerAttacher(
        discovery: ServerDiscovery(
          api: api,
          fileSystem: fileSystem,
          lockFile: lockFile,
          launch: launch,
          spawner: spawner,
          clock: clock,
          startTimeout: startTimeout,
        ),
        sessionClientFactory: sessionClientFactory,
        pid: pid,
      ),
      api: api,
    )..start();
    _binding = _logic.bind()
      ..onOutput<ConnectionChanged>(
        (changed) => _connectionChanges.add(changed.connection),
      )
      ..onOutput<ModelStatusChanged>(
        (changed) => _modelStatusChanges.add(changed.status),
      )
      ..onOutput<SessionStarted>((started) => _follow(started.session));
  }

  final ModelIndexFile _index;
  late final ServerConnectionLogic _logic;
  late final LogicBlockBinding<ServerConnectionState> _binding;
  final _connectionChanges = StreamController<LocalServerConnection>.broadcast(
    sync: true,
  );
  final _modelStatusChanges = StreamController<ModelStatus>.broadcast(
    sync: true,
  );
  final _poolSnapshots = StreamController<PoolSnapshotEvent>.broadcast();
  StreamSubscription<SessionEvent>? _following;
  Future<void>? _closing;

  ServerConnectionData get _data => _logic.get<ServerConnectionData>();

  LocalServerConnection get connection => _data.connection;

  Stream<LocalServerConnection> get connectionChanges =>
      _connectionChanges.stream;

  /// The loaded model's status, as the owner session last reported it.
  ModelStatus get modelStatus => _data.modelStatus;

  @override
  Stream<ModelStatus> get modelStatusChanges => _modelStatusChanges.stream;

  /// How the loaded model's context is divided, whenever that changes.
  @override
  Stream<PoolSnapshotEvent> get poolSnapshots => _poolSnapshots.stream;

  @override
  Future<void> untilDetached() => _data.detached.future;

  /// The `local` provider over this client, running models with the
  /// [options] the user has set when each is activated.
  Provider provider({
    required ProviderDescriptor descriptor,
    required LocalProviderOptionsReader options,
  }) => LocalProvider(
    link: this,
    index: _index,
    descriptor: descriptor,
    options: options,
  );

  /// Holds the owner session, finding or starting the server first. The
  /// server stays up while the session is held. Concurrent callers share
  /// one attempt.
  @override
  Future<LocalServerConnection> attach() => _ask(AttachRequested.new);

  /// Unloads the model and hangs up the owner session, so another bestie
  /// can own the server; a server left with no connection exits at once.
  /// The client stays usable: attaching again takes a new session.
  @override
  Future<void> release() => _ask(ReleaseRequested.new);

  /// Loads the model [request] names, unless it already serves exactly
  /// that. Needs the owner session.
  @override
  Future<ModelLoadResult> load(ModelLoadRequest request) => _ask(
    (reply) => LoadRequested(request: request, reply: reply),
  );

  /// Hangs up the owner session so the server frees every lease at once;
  /// a server left with no connection then exits. The client is spent
  /// afterwards.
  Future<void> close() => _closing ??= _close();

  @override
  @internal
  Future<AgentSessionResult> openLease(Object holder, AgentIdentity agent) =>
      _ask(
        (reply) =>
            LeaseOpenRequested(holder: holder, agent: agent, reply: reply),
      );

  @override
  @internal
  Future<void> closeLease(Object holder, String agentId) => _ask(
    (reply) =>
        LeaseCloseRequested(holder: holder, agentId: agentId, reply: reply),
  );

  @override
  @internal
  Future<void> releaseLeases(Object holder) => _ask(
    (reply) => LeaseCloseRequested(holder: holder, reply: reply),
  );

  /// Sends the input [ask] makes, keeping its type so its handler finds
  /// it, and answers what the input's reply is completed with.
  Future<T> _ask<T, TInput extends ServerConnectionInput>(
    TInput Function(Completer<T> reply) ask,
  ) {
    final reply = Completer<T>();
    _logic.input<TInput>(ask(reply));
    return reply.future;
  }

  Future<void> _close() async {
    await _ask(CloseRequested.new);
    await _following?.cancel();
    _binding.dispose();
    await _connectionChanges.close();
    await _modelStatusChanges.close();
    await _poolSnapshots.close();
  }

  /// Feeds the session's events to whoever follows them until it ends.
  void _follow(OwnerSession session) {
    unawaited(_following?.cancel());
    _following = session.events.listen(
      (event) => switch (event) {
        ModelStatusEvent(:final status) => _logic.input(
          ModelStatusReported(session: session, status: status),
        ),
        final PoolSnapshotEvent snapshot => _poolSnapshots.add(snapshot),
        SessionOpened() => null,
      },
      onDone: () => _logic.input(SessionEnded(session)),
    );
  }
}
