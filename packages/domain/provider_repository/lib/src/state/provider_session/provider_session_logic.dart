import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind, InferenceProtocolId;
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ModelCatalog, ProviderFailure, ProviderModelRef;
import 'package:provider_repository/src/models/provider_account.dart';
import 'package:provider_repository/src/models/provider_factories.dart';
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/state/provider_session/provider_connection.dart';
import 'package:provider_repository/src/state/provider_session/provider_probe.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_data.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_input.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_output.dart';

/// State hierarchy for the hosted provider session.
@model
sealed class ProviderSessionState extends StateLogic<ProviderSessionState> {
  ProviderSessionState() {
    on<ConfigureProvider>(onConfigure);
    on<ReconnectProvider>(onReconnect);
  }

  ProviderSessionData get data => get<ProviderSessionData>();
  ProviderSessionFactories get factories => get<ProviderSessionFactories>();
  ModelCatalog get catalog => get<ModelCatalog>();

  Transition onConfigure(ConfigureProvider input) {
    apply(input.settings);
    return input.settings.isComplete
        ? to<ConnectingState>()
        : to<UnconfiguredState>();
  }

  Transition onReconnect(ReconnectProvider input) {
    final settings = data.settings;
    if (settings == null || !settings.isComplete) return toSelf();
    apply(settings, reuseConnections: false);
    return to<ConnectingState>();
  }

  /// Adopts [settings], dropping everything the previous settings built and
  /// invalidating any probe still in flight. Connections whose account did
  /// not change stay, listing included, unless [reuseConnections] is off.
  void apply(ProviderSettings settings, {bool reuseConnections = true}) {
    final handle = data.handle;
    if (handle != null) output(ProviderHandleReleased(handle));
    final previous = reuseConnections
        ? data.connections
        : const <String, ProviderConnection>{};
    data
      ..settings = settings
      ..attempt += 1
      ..connections = {
        for (final account in settings.accounts)
          if (account.isUsable)
            account.descriptor.id: _connect(
              account,
              previous[account.descriptor.id],
            ),
      }
      ..connection = null
      ..model = null
      ..keyInfo = null
      ..handle = null
      ..failure = null;
  }

  ProviderConnection _connect(
    ProviderAccount account,
    ProviderConnection? existing,
  ) => existing != null && existing.account == account
      ? existing
      : ProviderConnection(
          account: account,
          provider: factories.providerFactory(account),
          catalog: catalog,
        );
}

@model
final class UnconfiguredState extends ProviderSessionState {}

@model
final class ConnectingState extends ProviderSessionState {
  ConnectingState() {
    onEnter(connect);

    on<ProbeCompleted>((input) {
      if (input.attempt != data.attempt) return toSelf();
      switch (input.outcome) {
        case ProbeFailed(:final failure):
          data.failure = failure;
          return to<FailedState>();
        case ProbeSucceeded(:final model, :final keyInfo):
          final settings = data.settings!;
          final endpoint = data
              .connection!
              .provider
              .endpoints[InferenceProtocolId.openAiCompat]!;
          data
            ..model = model
            ..keyInfo = keyInfo
            ..handle = factories.agentProviderSpawner(
              client: factories.inferenceClientFactory(endpoint),
              modelId: model.id,
              contextWindow: model.contextWindow,
              maxAgents: settings.maxAgents,
            );
          return to<ReadyState>();
      }
    });
  }

  @override
  Transition onConfigure(ConfigureProvider input) {
    apply(input.settings);
    if (!input.settings.isComplete) return to<UnconfiguredState>();
    connect();
    output(const ProviderSessionChanged());
    return toSelf();
  }

  @override
  Transition onReconnect(ReconnectProvider input) {
    apply(data.settings!, reuseConnections: false);
    connect();
    return toSelf();
  }

  void connect() {
    final settings = data.settings!;
    final attempt = data.attempt;
    final model = settings.model!;
    async(_probe(settings.accountFor(model.providerId), model)).input(
      (outcome) => ProbeCompleted(attempt: attempt, outcome: outcome),
    );
  }

  Future<ProbeOutcome> _probe(
    ProviderAccount? account,
    ProviderModelRef model,
  ) {
    if (account == null) {
      return Future.value(ProbeFailed(_unknownProvider(model)));
    }
    if (!account.isUsable) return Future.value(ProbeFailed(_unusable(account)));
    final connection = data.connections[account.descriptor.id]!;
    data.connection = connection;
    return probeProvider(connection, model: model);
  }

  static ProviderFailure _unknownProvider(ProviderModelRef model) =>
      ProviderFailure(
        kind: InferenceFailureKind.badRequest,
        message: 'No provider is called "${model.providerId}".',
      );

  static ProviderFailure _unusable(ProviderAccount account) {
    final name = account.descriptor.displayName;
    return account.descriptor.requiresApiKey && !account.hasApiKey
        ? ProviderFailure(
            kind: InferenceFailureKind.auth,
            message: 'No $name API key configured.',
          )
        : ProviderFailure(
            kind: InferenceFailureKind.badRequest,
            message: '$name URL is not set.',
          );
  }
}

@model
final class ReadyState extends ProviderSessionState {}

@model
final class FailedState extends ProviderSessionState {}

@model
final class ProviderSessionLogic extends LogicBlock<ProviderSessionState> {
  ProviderSessionLogic({
    required ProviderSessionFactories factories,
    required ModelCatalog catalog,
  }) {
    set(ProviderSessionData());
    set(factories);
    set<ModelCatalog>(catalog);

    set(UnconfiguredState());
    set(ConnectingState());
    set(ReadyState());
    set(FailedState());
  }

  @override
  Transition getInitialState() => to<UnconfiguredState>();
}
