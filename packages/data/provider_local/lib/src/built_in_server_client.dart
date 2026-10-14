import 'dart:async';

import 'package:clock/clock.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:meta/meta.dart';
import 'package:provider_local/src/connection/server_connection_data.dart';
import 'package:provider_local/src/connection/server_connection_input.dart';
import 'package:provider_local/src/connection/server_connection_logic.dart';
import 'package:provider_local/src/connection/server_connection_output.dart';
import 'package:provider_local/src/local_provider_model.dart';
import 'package:provider_local/src/local_server_link.dart';
import 'package:provider_local/src/model_index_file.dart';
import 'package:provider_local/src/models/local_server_connection.dart';
import 'package:provider_local/src/models/local_server_launch.dart';
import 'package:provider_local/src/models/server_results.dart';
import 'package:provider_local/src/owner_session.dart';
import 'package:provider_local/src/server_api.dart';
import 'package:provider_local/src/server_attacher.dart';
import 'package:provider_local/src/server_discovery.dart';
import 'package:provider_local/src/server_spawner.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// This bestie's link to the local inference server: it lists the models in
/// bestie's index, finds or starts the server, and holds the owner session
/// that lets this bestie load a model and lease its agents.
@dataSource
final class LocalConnection implements ProviderConnection, LocalServerLink {
  LocalConnection({
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
      ..onOutput<ModelStatusChanged>(
        (changed) => _modelStatusChanges.add(changed.status),
      )
      ..onOutput<SessionStarted>((started) => _follow(started.session));
  }

  final ModelIndexFile _index;
  late final ServerConnectionLogic _logic;
  late final LogicBlockBinding<ServerConnectionState> _binding;
  final _modelStatusChanges = StreamController<ModelStatus>.broadcast(
    sync: true,
  );
  final _poolSnapshots = StreamController<PoolSnapshotEvent>.broadcast();
  StreamSubscription<SessionEvent>? _following;
  Future<void>? _closing;
  var _loads = 0;

  ServerConnectionData get _data => _logic.get<ServerConnectionData>();

  @override
  Stream<PoolSnapshotEvent> get poolSnapshots => _poolSnapshots.stream;

  @override
  Future<void> untilDetached() => _data.detached.future;

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
  Future<void> releaseLoad(int generation) =>
      generation == _loads ? _ask(ReleaseRequested.new) : Future.value();

  /// Hangs up the owner session so the server frees every lease at once;
  /// a server left with no connection then exits. The connection is spent
  /// afterwards.
  @override
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
    final attached = await _ask(AttachRequested.new);
    if (attached is! LocalServerAttached) {
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
          contextCap: request.contextCap,
        ),
        reply: reply,
      ),
    );
    await reporting.cancel();
    unawaited(progress.close());
    switch (loaded) {
      case ModelLoaded(:final ready):
        return ProviderModelLoaded(
          LocalProviderModel(
            link: this,
            generation: generation,
            attached: attached,
            ready: ready,
            modelId: request.modelId,
          ),
        );
      case ModelLoadFailed(:final reason):
        await releaseLoad(generation);
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

  /// Why loading cannot go on while the server stands at [connection].
  @visibleForTesting
  static ProviderFailure failureFor(
    LocalServerConnection connection,
  ) => switch (connection) {
    LocalServerBusy(:final ownerPid) => ProviderOccupied(
      bestieServerBusyMessage(ownerPid),
    ),
    LocalServerVersionMismatch(:final protocolVersion) => ProviderOccupied(
      'The running local model server speaks protocol '
      '$protocolVersion; this bestie speaks $bestieProtocolVersion. '
      'It exits once its owner closes and it sits idle.',
    ),
    LocalServerSpawnFailed(:final reason) => ProviderServerFailed(
      'Could not start the local model server: $reason',
    ),
    LocalServerDisconnected(:final reason) => ProviderServerFailed(
      reason ?? _notConnected,
    ),
    LocalServerAttaching() ||
    LocalServerAttached() => const ProviderServerFailed(_notConnected),
  };

  static const _notConnected = 'The local model server is not connected.';

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
