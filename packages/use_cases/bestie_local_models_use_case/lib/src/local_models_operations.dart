import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_local_models_use_case/src/config/local_models_config_keys.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/support/latest_throttle.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderModelRef;
import 'package:provider_repository/provider_repository.dart';
import 'package:rxdart/rxdart.dart';

/// What the model panes and commands show and do: the library at a pace a
/// terminal can draw, the built-in server, the model the app runs on, and
/// the operations on all three.
@PartOf(LocalModelsUseCase)
class LocalModelsOperations {
  LocalModelsOperations({
    required LocalModelsRepository library,
    required BuiltInServerRepository server,
    required ProviderRepository providers,
    required ConfigRepository config,
    required LocalModelsConfigKeys configKeys,
    required ConfigKey<String> modelKey,
    required String providerId,
    required AgentRepository agents,
    required OSPlatformRepository platform,
    required Clock clock,
  }) : _library = library,
       _server = server,
       _providers = providers,
       _config = config,
       _configKeys = configKeys,
       _modelKey = modelKey,
       _providerId = providerId,
       _agents = agents,
       _platform = platform,
       _throttledLibrary = BehaviorSubject.seeded(library.current) {
    _throttle = LatestThrottle(
      interval: libraryInterval,
      emit: _throttledLibrary.add,
      clock: clock,
    );
    _subscriptions = [
      library.library.listen(_throttle.add),
      config
          .watch(configKeys.paths.global)
          .distinct(const ListEquality<String>().equals)
          .skip(1)
          .listen((folders) => unawaited(library.setFolders(folders))),
    ];
  }

  /// The longest the panes wait to see the library change; downloads report
  /// progress far more often than a terminal needs to redraw.
  static const libraryInterval = Duration(milliseconds: 250);

  final LocalModelsRepository _library;
  final BuiltInServerRepository _server;
  final ProviderRepository _providers;
  final ConfigRepository _config;
  final LocalModelsConfigKeys _configKeys;
  final ConfigKey<String> _modelKey;
  final String _providerId;
  final AgentRepository _agents;
  final OSPlatformRepository _platform;
  final BehaviorSubject<ModelLibrary> _throttledLibrary;
  late final LatestThrottle<ModelLibrary> _throttle;
  late final List<StreamSubscription<Object>> _subscriptions;

  /// The library as it changes, at most a few times a second, opening with
  /// the latest.
  Stream<ModelLibrary> get library => _throttledLibrary.stream;

  ModelLibrary get currentLibrary => _throttledLibrary.value;

  /// What the built-in server is doing, now and whenever it changes.
  Stream<BuiltInServerStatus> get server => _server.statusStream;

  /// The local model the app is set to run on, if it is set to one.
  String? get selectedId => _localIdOf(_config.resolve(_modelKey.global));

  /// The local model the app is running or getting ready, if any.
  String? get inUseId => _inUseOf(_providers.status);

  /// [inUseId] now and whenever it changes.
  Stream<String?> get inUseIds =>
      _providers.statusStream.map(_inUseOf).distinct();

  /// Whether no turn is running, so the model may change under the app.
  bool get idle => _agents.primary.conversationPhase == ConversationPhase.idle;

  /// The folders the user added, now and whenever they change.
  Stream<List<String>> get folderChanges => _config
      .watch(_configKeys.paths.global)
      .distinct(const ListEquality<String>().equals);

  List<String> get folders => _config.resolve(_configKeys.paths.global);

  /// [path] as the user knows it: their home shortened to `~`.
  String shorten(String path) => _platform.platform.paths.shortenHome(path);

  /// All of this machine's memory, which the fit of a download is judged
  /// against.
  int get memoryBytes => _platform.readSystemInfo().totalRamBytes;

  /// Memory nothing is using right now.
  int get freeMemoryBytes => _platform.readSystemInfo().availableRamBytes;

  /// Picks the library up and scans every folder.
  Future<void> start() => _library.start();

  Future<RepoSearchResult> search(String query) => _library.searchRepos(query);

  Future<RepoResolution> resolve(String repo) => _library.resolveRepo(repo);

  Future<DownloadRequestResult> download(RepoQuant quant) =>
      _library.download(quant);

  CancelDownloadResult cancel(String downloadId) => _library.cancel(downloadId);

  ResumeDownloadResult resume(String downloadId) => _library.resume(downloadId);

  Future<DiscardDownloadResult> discard(String downloadId) =>
      _library.discardDownload(downloadId);

  Future<DeleteModelResult> delete(String localId) =>
      _library.deleteModel(localId);

  /// Runs the app on the local model [localId], unless a turn is running;
  /// starts it again when the app is already set to it.
  ModelPickResult use(String localId) {
    if (!idle) return const ModelPickRefused('turn in progress');
    if (selectedId == localId) {
      _providers.reconnect();
      return const ModelPicked();
    }
    _config.commit({
      _modelKey.global: ConfigEdit<String>.set(
        ProviderModelRef(providerId: _providerId, modelId: localId).qualified,
      ),
    });
    return const ModelPicked();
  }

  /// [folder] as the library would list it: `~` expanded and normalized, or
  /// null when it is not an absolute path.
  String? folderFrom(String folder) {
    final paths = _platform.platform.paths;
    final expanded = paths.expandHome(folder.trim());
    return paths.isAbsolute(expanded) ? paths.normalize(expanded) : null;
  }

  void setFolders(List<String> folders) => _config.commit({
    _configKeys.paths.global: ConfigEdit<List<String>>.set(folders),
  });

  /// Takes the server again and, when the app is set to one of its models,
  /// loads that model again. Takes the downloads over too when another
  /// window ran them, since that window has likely gone.
  void retryServer() {
    unawaited(_server.start());
    if (selectedId != null) _providers.reconnect();
    if (_library.current.downloadsStatus is DownloadsManagedElsewhere) {
      unawaited(_library.rescan());
    }
  }

  Future<void> dispose() async {
    _throttle.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _throttledLibrary.close();
  }

  String? _localIdOf(String model) => _localIdIn(ProviderModelRef.parse(model));

  String? _localIdIn(ProviderModelRef? ref) => switch (ref) {
    ProviderModelRef(:final providerId, :final modelId)
        when providerId == _providerId =>
      modelId,
    _ => null,
  };

  String? _inUseOf(ProviderStatus status) => switch (status) {
    ProviderStatusReady(:final model) => _localIdIn(model.ref),
    ProviderStatusConnecting(:final model) => _localIdIn(model),
    ProviderStatusUnconfigured() || ProviderStatusFailed() => null,
  };
}

/// How asking to run on a local model went.
@model
sealed class ModelPickResult {
  const ModelPickResult();
}

@model
final class ModelPicked extends ModelPickResult {
  const ModelPicked();
}

@model
final class ModelPickRefused extends ModelPickResult {
  const ModelPickRefused(this.reason);

  final String reason;
}
