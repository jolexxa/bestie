import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/models/model_list.dart';
import 'package:provider_repository/src/models/provider_account.dart';
import 'package:provider_repository/src/models/provider_factories.dart';
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/models/provider_status.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_data.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_input.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_logic.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_output.dart';
import 'package:rxdart/rxdart.dart';

/// Owns the hosted provider session: which provider and model the app runs
/// against, and whether that combination is usable right now.
@repository
class ProviderRepository {
  ProviderRepository({
    required ProviderSessionFactories factories,
    required ModelCatalog catalog,
  }) : _catalog = catalog {
    _logic = ProviderSessionLogic(factories: factories, catalog: catalog)
      ..start();
    _statusController = BehaviorSubject<ProviderStatus>.seeded(_project());
    _binding = _logic.bind()
      ..onState<ProviderSessionState>((_) => _publish())
      ..onOutput<ProviderSessionChanged>((_) => _publish())
      ..onOutput<ProviderHandleReleased>(
        (released) => unawaited(released.handle.dispose()),
      );
  }

  static const _unconfigured = ProviderFailure(
    kind: InferenceFailureKind.badRequest,
    message: 'No provider is configured.',
  );

  final ModelCatalog _catalog;
  late final ProviderSessionLogic _logic;
  late final LogicBlockBinding<ProviderSessionState> _binding;
  late final BehaviorSubject<ProviderStatus> _statusController;
  final _reloadsStartingController = StreamController<void>.broadcast(
    sync: true,
  );

  ProviderSessionData get _data => _logic.get<ProviderSessionData>();

  /// Stream of [ProviderStatus] snapshots.
  Stream<ProviderStatus> get statusStream => _statusController.stream;

  /// Current [ProviderStatus] snapshot.
  ProviderStatus get status => _statusController.value;

  /// The settings the session is running under, if any were given.
  ProviderSettings? get settings => _data.settings;

  /// Emits immediately before a live agent provider is torn down, so
  /// listeners can detach from it first.
  Stream<void> get reloadsStarting => _reloadsStartingController.stream;

  /// Adopt [settings]; a no-op when nothing changed.
  void configure(ProviderSettings settings) {
    if (settings == _data.settings) return;
    _announceReload();
    _logic.input(ConfigureProvider(settings));
  }

  /// Retry the current settings.
  void reconnect() {
    _announceReload();
    _logic.input(const ReconnectProvider());
  }

  Provider? get _provider => _data.connection?.provider;

  Future<CreditsResult> credits() async =>
      await _provider?.credits() ?? const CreditsFailed(_unconfigured);

  Future<KeyInfoResult> keyInfo() async =>
      await _provider?.keyInfo() ?? const KeyInfoFailed(_unconfigured);

  /// Every model across the configured accounts, in account order: the
  /// listing each connection fetched when it was built, then the catalog
  /// for the accounts the user has not set up.
  Future<ModelList> models() async {
    final settings = _data.settings;
    if (settings == null) {
      return const ModelList(models: [], failures: [_unconfigured]);
    }
    final usable = <ListedModel>[];
    final catalogOnly = <ListedModel>[];
    final failures = <ProviderFailure>[];
    for (final account in settings.accounts) {
      final connection = _data.connections[account.descriptor.id];
      if (connection == null) {
        await _listKnown(account, into: catalogOnly, failures: failures);
        continue;
      }
      switch (await connection.models) {
        case ProviderModelsFailed(:final failure):
          failures.add(failure);
        case ProviderModelsListed(models: final listed):
          usable.addAll(_listed(account, listed, hasAccess: true));
      }
    }
    return ModelList(models: [...usable, ...catalogOnly], failures: failures);
  }

  /// Releases the live agent provider and closes every stream.
  Future<void> dispose() async {
    final handle = _data.handle;
    _binding.dispose();
    _logic
      ..stop()
      ..dispose();
    await handle?.dispose();
    await _statusController.close();
    await _reloadsStartingController.close();
  }

  Future<void> _listKnown(
    ProviderAccount account, {
    required List<ListedModel> into,
    required List<ProviderFailure> failures,
  }) async {
    final catalogId = account.descriptor.catalogId;
    if (catalogId == null) return;
    switch (await _catalog.modelsFor(catalogId)) {
      case CatalogUnavailable(:final failure):
        failures.add(failure);
      case CatalogListed(:final models):
        into.addAll(_listed(account, models, hasAccess: false));
    }
  }

  static Iterable<ListedModel> _listed(
    ProviderAccount account,
    List<ProviderModel> models, {
    required bool hasAccess,
  }) => models.map(
    (model) => ListedModel(
      ref: ProviderModelRef(
        providerId: account.descriptor.id,
        modelId: model.id,
      ),
      model: model,
      providerName: account.descriptor.displayName,
      hasAccess: hasAccess,
    ),
  );

  void _announceReload() {
    if (status.provider != null) _reloadsStartingController.add(null);
  }

  ProviderStatus _project() => ProviderStatus.fromState(_logic.value, _data);

  void _publish() => _statusController.add(_project());
}
