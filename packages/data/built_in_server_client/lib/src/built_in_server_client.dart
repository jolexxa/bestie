import 'dart:async';

import 'package:built_in_server_client/src/built_in_server_link.dart';
import 'package:built_in_server_client/src/built_in_server_model.dart';
import 'package:built_in_server_client/src/connection/server_connection_data.dart';
import 'package:built_in_server_client/src/connection/server_connection_input.dart';
import 'package:built_in_server_client/src/connection/server_connection_logic.dart';
import 'package:built_in_server_client/src/connection/server_connection_output.dart';
import 'package:built_in_server_client/src/disconnect_wording.dart';
import 'package:built_in_server_client/src/model_index_file.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/built_in_server_launch.dart';
import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:built_in_server_client/src/models/model_load_options.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/owner_session.dart';
import 'package:built_in_server_client/src/server_api.dart';
import 'package:built_in_server_client/src/server_attacher.dart';
import 'package:built_in_server_client/src/server_discovery.dart';
import 'package:built_in_server_client/src/server_spawner.dart';
import 'package:clock/clock.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:meta/meta.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// This bestie's link to the built-in inference server: it lists the models
/// in bestie's index, finds or starts the server, and holds the owner
/// session that lets this bestie load a model and lease its agents.
@dataSource
class BuiltInServerClient implements ProviderClient, BuiltInServerLink {
  BuiltInServerClient({
    required http.Client client,
    required http.Client Function() sessionClientFactory,
    required FileSystem fileSystem,
    required String lockFile,
    required String indexFile,
    required BuiltInServerLaunch launch,
    required int pid,
    required ServerSpawner spawner,
    Clock clock = const Clock(),
    Duration startTimeout = const Duration(seconds: 90),
    Duration healthTimeout = const Duration(seconds: 5),
    Duration lossGrace = const Duration(seconds: 1),
  }) : _index = ModelIndexFile(fileSystem: fileSystem, path: indexFile),
       _wording = DisconnectWording(logFile: launch.logFile) {
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
      lossGrace: lossGrace,
    )..start();
    _binding = _logic.bind()
      ..onOutput<ModelStatusChanged>(
        (changed) => _modelStatusChanges.add(changed.status),
      )
      ..onOutput<ConnectionChanged>(
        (changed) => _connectionChanges.add(changed.connection),
      )
      ..onOutput<SessionStarted>((started) => _follow(started.session));
  }

  final ModelIndexFile _index;
  final DisconnectWording _wording;
  late final ServerConnectionLogic _logic;
  late final LogicBlockBinding<ServerConnectionState> _binding;
  final _modelStatusChanges = StreamController<ModelStatus>.broadcast(
    sync: true,
  );
  final _connectionChanges =
      StreamController<BuiltInServerConnection>.broadcast(
        sync: true,
      );
  final _poolSnapshots = StreamController<PoolSnapshotEvent>.broadcast();
  final _reconfigured = StreamController<ProviderAvailability>.broadcast();
  StreamSubscription<SessionEvent>? _following;
  Future<void>? _closing;
  ModelLoadOptions _options = ModelLoadOptions.defaults;
  var _loads = 0;

  ServerConnectionData get _data => _logic.get<ServerConnectionData>();

  @override
  String get id => 'local';

  @override
  String get displayName => 'Built-in server';

  /// The index is readable without the server, so the models are always
  /// there to list; whether the server can be held shows up on a load.
  @override
  ProviderAvailability get availability => const ProviderReady();

  @override
  Stream<ProviderAvailability> get reconfigured => _reconfigured.stream;

  /// Where this bestie stands with the server, as it changes.
  Stream<BuiltInServerConnection> get connectionChanges =>
      _connectionChanges.stream;

  /// The model's status as the owner session reports it, as it changes.
  Stream<ModelStatus> get modelStatusChanges => _modelStatusChanges.stream;

  @override
  Stream<PoolSnapshotEvent> get poolSnapshots => _poolSnapshots.stream;

  @override
  Future<DisconnectCause> untilDetached() => _data.detached.future;

  /// Loads every model from now on the way [options] say.
  void configure(ModelLoadOptions options) {
    if (options == _options) return;
    _options = options;
    _reconfigured.add(availability);
  }

  /// Holds the owner session, finding or starting the server first.
  Future<BuiltInServerConnection> attach() => _ask(AttachRequested.new);

  /// Unloads the model and hangs up the owner session, so another bestie
  /// can take the server; a server left with no connection then exits.
  Future<void> release() => _ask(ReleaseRequested.new);

  /// The models in the index, read without starting the server.
  @override
  Future<ProviderModelsResult> models() async => switch (await _index.read()) {
    ModelIndexListed(:final entries) => ProviderModelsListed([
      for (final entry in entries) _toModelInfo(entry),
    ]),
    ModelIndexUnreadable(:final reason) => ProviderModelsFailed(
      ProviderResponseMalformed(reason),
    ),
  };

  @override
  Future<CreditsResult> credits() async => const CreditsUnsupported();

  /// Takes the owner session, then loads the model, reporting the load's
  /// progress as the session does. The model is lost once the session
  /// ends, since a server that comes back serves neither it nor its leases
  /// until it is loaded again.
  @override
  ProviderModelLoad load(ProviderModelLoadRequest request) {
    final generation = ++_loads;
    final progress = StreamController<ProviderModelLoadProgress>();
    return ProviderModelLoad(
      progress: progress.stream,
      result: _load(request, generation, progress),
    );
  }

  @override
  Future<void> unload(int generation) =>
      generation == _loads ? _ask(UnloadRequested.new) : Future.value();

  /// Hangs up the owner session so the server frees every lease at once;
  /// a server left with no connection then exits. The connection is spent
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

  Future<ProviderModelLoadResult> _load(
    ProviderModelLoadRequest request,
    int generation,
    StreamController<ProviderModelLoadProgress> progress,
  ) async {
    final attached = await attach();
    if (attached is! BuiltInServerAttached) {
      unawaited(progress.close());
      return ProviderModelLoadFailed(failureFor(attached));
    }
    final reporting = _modelStatusChanges.stream.listen((status) {
      if (_progressOf(status, request.modelId) case final reported?) {
        progress.add(reported);
      }
    });
    final loaded = await _ask<ModelLoadResult, LoadRequested>(
      (reply) => LoadRequested(
        request: ModelLoadRequest(
          localId: request.modelId,
          maxAgents: request.maxAgents,
          contextCap: _options.contextCap,
        ),
        reply: reply,
      ),
    );
    await reporting.cancel();
    unawaited(progress.close());
    switch (loaded) {
      case ModelLoaded(:final ready):
        return ProviderModelLoaded(
          BuiltInServerModel(
            link: this,
            generation: generation,
            attached: attached,
            ready: ready,
            modelId: request.modelId,
            wording: _wording,
          ),
        );
      case ModelLoadFailed(:final reason):
        return ProviderModelLoadFailed(
          ProviderServerFailed(reason),
        );
    }
  }

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
    await _modelStatusChanges.close();
    await _connectionChanges.close();
    await _poolSnapshots.close();
    await _reconfigured.close();
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
        SessionClosing(:final reason) => _logic.input(
          SessionClosingReported(session: session, reason: reason),
        ),
        SessionOpened() => null,
      },
      onDone: () => _logic.input(SessionEnded(session)),
    );
  }

  /// Why loading cannot go on while the server stands at [connection].
  @visibleForTesting
  ProviderFailure failureFor(BuiltInServerConnection connection) =>
      switch (connection) {
        BuiltInServerBusy(:final ownerPid) => ProviderOccupied(
          bestieServerBusyMessage(ownerPid),
        ),
        BuiltInServerVersionMismatch(:final protocolVersion) =>
          ProviderOccupied(
            'The running local model server speaks protocol '
            '$protocolVersion; this bestie speaks $bestieProtocolVersion. '
            'It exits once its owner closes and it sits idle.',
          ),
        BuiltInServerSpawnFailed(:final reason) => ProviderServerFailed(
          'Could not start the local model server: $reason',
        ),
        BuiltInServerDisconnected(:final cause) => _wording.failureFor(cause),
        BuiltInServerAttaching() || BuiltInServerAttached() =>
          const ProviderServerFailed(DisconnectWording.notConnected),
      };

  static ProviderModelLoadProgress? _progressOf(
    ModelStatus status,
    String modelId,
  ) => switch (status) {
    ModelFitting(:final localId) when localId == modelId =>
      const ProviderModelMeasuring(),
    ModelLoading(:final localId, :final progress) when localId == modelId =>
      ProviderModelLoading(progress),
    _ => null,
  };

  static ProviderModelInfo _toModelInfo(ModelIndexEntry entry) =>
      ProviderModelInfo(
        id: entry.localId,
        name: entry.displayName,
        contextLength: entry.trainedContextLength,
        supportsTools: true,
        reasoning: _reasoningOf(entry.reasoning),
      );

  /// How the server treats each kind: a toggle thinks unless declined, and
  /// declining an effort model picks its cheapest effort rather than none.
  static ProviderReasoning? _reasoningOf(ModelReasoning reasoning) =>
      switch (reasoning) {
        ModelReasoningNone() => null,
        ModelReasoningAlways() => const ProviderReasoningFixed(),
        ModelReasoningToggle() => const ProviderReasoningToggle(
          enabledByDefault: true,
        ),
        ModelReasoningEfforts(:final efforts) => ProviderReasoningEfforts(
          efforts: efforts,
          canDisable: false,
          defaultEffort: efforts.contains('medium') ? 'medium' : efforts.first,
        ),
      };
}
