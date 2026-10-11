import 'dart:async';

import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/models/model_list.dart';
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/models/provider_status.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_data.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_input.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_logic.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_output.dart';
import 'package:rxdart/rxdart.dart';

/// Owns the provider session: a live connection to every provider, which
/// model the app runs, and whether it is usable right now.
@repository
class ProviderRepository {
  ProviderRepository({
    required List<Provider> providers,
    Clock clock = const Clock(),
  }) : _providers = providers {
    _logic = ProviderSessionLogic(
      providers: providers,
      recovery: RecoveryPolicy(clock: clock),
    )..start();
    _statusController = BehaviorSubject<ProviderStatus>.seeded(_project());
    _binding = _logic.bind()
      ..onState<ProviderSessionState>((_) => _publish())
      ..onOutput<ProviderSessionChanged>((_) => _publish())
      ..onOutput<RuntimeReleased>((released) {
        _reloadsStartingController.add(null);
        unawaited(released.runtime.dispose());
      })
      ..onOutput<ModelReleased>(
        (released) => unawaited(released.model.release()),
      )
      ..onOutput<ConnectionRetired>(
        (retired) => unawaited(retired.connection.close()),
      )
      ..onOutput<LoadStarted>(_followLoad);
  }

  static const _unconfigured = ProviderRejected('No model is chosen.');

  final List<Provider> _providers;
  late final ProviderSessionLogic _logic;
  late final LogicBlockBinding<ProviderSessionState> _binding;
  late final BehaviorSubject<ProviderStatus> _statusController;
  final _reloadsStartingController = StreamController<void>.broadcast(
    sync: true,
  );
  StreamSubscription<ProviderModelLoadProgress>? _loadProgress;

  ProviderSessionData get _data => _logic.get<ProviderSessionData>();

  /// Stream of [ProviderStatus] snapshots.
  Stream<ProviderStatus> get statusStream => _statusController.stream;

  /// Current [ProviderStatus] snapshot.
  ProviderStatus get status => _statusController.value;

  /// The settings the session is running under, if any were given.
  ProviderSettings? get settings => _data.settings;

  /// Emits immediately before a live agent runtime is torn down, so
  /// listeners can detach from it first.
  Stream<void> get reloadsStarting => _reloadsStartingController.stream;

  /// Adopt [settings]; a no-op when nothing changed.
  void configure(ProviderSettings settings) {
    if (settings == _data.settings) return;
    _logic.input(ConfigureProvider(settings));
  }

  /// Retry the current settings.
  void reconnect() => _logic.input(const ReconnectProvider());

  /// Stops running the chosen model and lets it go, until the settings
  /// change or a reconnect.
  void stop() => _logic.input(const StopProvider());

  /// The balance of the account the chosen model runs on.
  Future<CreditsResult> credits() async =>
      switch (_data.connections[_data.settings?.model?.providerId]) {
        final connection? => await connection.credits(),
        null => const CreditsFailed(_unconfigured),
      };

  /// Every model every provider lists, in provider order. Models of a
  /// provider that wants credentials the user has not given are listed
  /// without access.
  Future<ModelList> models() async {
    final listings = await Future.wait([
      for (final provider in _providers) _modelsOf(provider),
    ]);
    return ModelList(
      models: [for (final listing in listings) ...listing.models],
      failures: [for (final listing in listings) ...listing.failures],
    );
  }

  /// Lets go of the running model and every connection, and closes every
  /// stream.
  Future<void> dispose() async {
    final runtime = _data.runtime;
    final loaded = _data.loaded;
    final connections = _data.connections.values.toList();
    await _loadProgress?.cancel();
    _binding.dispose();
    _logic
      ..stop()
      ..dispose();
    await runtime?.dispose();
    await loaded?.release();
    await Future.wait([
      for (final connection in connections) connection.close(),
    ]);
    await _statusController.close();
    await _reloadsStartingController.close();
  }

  Future<ModelList> _modelsOf(Provider provider) async {
    switch (await _data.connections[provider.id]!.models()) {
      case ProviderModelsFailed(:final failure):
        return ModelList(models: const [], failures: [failure]);
      case ProviderModelsListed(:final models):
        final hasAccess =
            provider.credentialsKind == ProviderCredentialsKind.none ||
            (_data.settings?.credentials.containsKey(provider.id) ?? false);
        return ModelList(
          models: [
            for (final model in models)
              ListedModel(
                ref: ProviderModelRef(
                  providerId: provider.id,
                  modelId: model.id,
                ),
                model: model,
                providerName: provider.displayName,
                hasAccess: hasAccess,
              ),
          ],
          failures: const [],
        );
    }
  }

  void _followLoad(LoadStarted started) {
    unawaited(_loadProgress?.cancel());
    _loadProgress = started.progress.listen(
      (progress) => _logic.input(
        LoadProgressed(attempt: started.attempt, progress: progress),
      ),
    );
  }

  ProviderStatus _project() => ProviderStatus.fromState(_logic.value, _data);

  void _publish() => _statusController.add(_project());
}
