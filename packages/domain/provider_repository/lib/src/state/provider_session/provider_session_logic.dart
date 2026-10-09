import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart'
    show InferenceEndpoint, InferenceFailureKind;
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show
        ModelActivated,
        ModelActivationFailed,
        ModelActivationRequest,
        ModelCatalog,
        ProviderFailure,
        ProviderModelRef;
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
    on<ModelsChanged>(onModelsChanged);
    on<StopProvider>(onStop);
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

  Transition onModelsChanged(ModelsChanged input) {
    forgetModelsOf(input.providerId);
    return toSelf();
  }

  /// Forgets the provider's kept listing, so the next look fetches it again.
  void forgetModelsOf(String providerId) =>
      data.connections[providerId]?.forgetModels();

  Transition onStop(StopProvider input) => toSelf();

  /// The settings, when the chosen model runs on [providerId].
  ProviderSettings? settingsRunningOn(String providerId) =>
      switch (data.settings) {
        final settings? when settings.model?.providerId == providerId =>
          settings,
        _ => null,
      };

  /// Adopts [settings], dropping everything the previous settings built and
  /// invalidating any probe still in flight. Connections whose account did
  /// not change stay, listing included, unless [reuseConnections] is off.
  void apply(ProviderSettings settings, {bool reuseConnections = true}) {
    releaseHandle();
    _deactivateUnless(settings.model?.providerId);
    final previous = reuseConnections
        ? data.connections
        : const <String, ProviderConnection>{};
    final connections = {
      for (final account in settings.accounts)
        if (account.isUsable)
          account.descriptor.id: _connect(
            account,
            previous[account.descriptor.id],
          ),
    };
    if (!_sameConnections(connections, data.connections)) {
      output(
        ProvidersReplaced([
          for (final connection in connections.values) connection.provider,
        ]),
      );
    }
    data
      ..settings = settings
      ..attempt += 1
      ..connections = connections
      ..connection = null
      ..model = null
      ..activationProgress = null
      ..keyInfo = null
      ..handle = null
      ..failure = null
      ..losses = 0;
  }

  /// Hands the agent provider, if one was spawned, to whoever tears it
  /// down.
  void releaseHandle() {
    if (data.handle case final handle?) output(ProviderHandleReleased(handle));
    data.handle = null;
  }

  /// Lets the activated provider go unless the session stays on
  /// [providerId], where the next activation replaces the model.
  void _deactivateUnless(String? providerId) {
    final activated = data.activated;
    if (activated == null || activated.id == providerId) return;
    data.activated = null;
    output(ProviderDeactivated(activated));
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

  static bool _sameConnections(
    Map<String, ProviderConnection> next,
    Map<String, ProviderConnection> previous,
  ) =>
      next.length == previous.length &&
      next.entries.every(
        (entry) => identical(previous[entry.key], entry.value),
      );
}

@model
final class UnconfiguredState extends ProviderSessionState {}

/// The session is on its way to running the chosen model, or runs it.
@model
sealed class RunningState extends ProviderSessionState {
  /// Lets the activated provider go and leaves the session failed until the
  /// settings change or a reconnect.
  @override
  Transition onStop(StopProvider input) {
    releaseHandle();
    _deactivateUnless(null);
    data
      ..attempt += 1
      ..activationProgress = null
      ..failure = const ProviderFailure(
        kind: InferenceFailureKind.cancelled,
        message: 'Stopped. Reconnect or pick a model to start again.',
      );
    return to<ActivationFailedState>();
  }
}

@model
final class ConnectingState extends RunningState {
  ConnectingState() {
    onEnter(connect);

    on<ProbeCompleted>((input) {
      if (input.attempt != data.attempt) return toSelf();
      switch (input.outcome) {
        case ProbeFailed(:final failure):
          data.failure = failure;
          return to<ProbeFailedState>();
        case ProbeSucceeded(:final model, :final keyInfo):
          data
            ..model = model
            ..keyInfo = keyInfo;
          return to<ActivatingState>();
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

  /// A probe under way may have read the listing from before the change,
  /// so it starts over.
  @override
  Transition onModelsChanged(ModelsChanged input) {
    forgetModelsOf(input.providerId);
    if (settingsRunningOn(input.providerId) case final settings?) {
      apply(settings);
      connect();
    }
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

/// The provider is getting the chosen model ready to serve.
@model
final class ActivatingState extends RunningState {
  ActivatingState() {
    onEnter(activate);

    on<ActivationProgressed>((input) {
      if (input.attempt != data.attempt) return toSelf();
      data.activationProgress = input.progress;
      output(const ProviderSessionChanged());
      return toSelf();
    });

    on<ActivationCompleted>((input) {
      if (input.attempt != data.attempt) return toSelf();
      switch (input.result) {
        case ModelActivationFailed(:final failure):
          data.failure = failure;
          return to<ActivationFailedState>();
        case ModelActivated(:final contextWindow, :final endpoint):
          spawn(contextWindow, endpoint);
          return to<ReadyState>();
      }
    });
  }

  void activate() {
    final attempt = data.attempt;
    final model = data.model!;
    final provider = data.connection!.provider;
    data.activated = provider;
    final activation = provider.activate(
      ModelActivationRequest(
        modelId: model.id,
        contextWindow: model.contextWindow,
        maxAgents: data.settings!.maxAgents,
      ),
    );
    output(ActivationStarted(attempt: attempt, progress: activation.progress));
    async(activation.result).input(
      (result) => ActivationCompleted(attempt: attempt, result: result),
    );
    async(activation.lost).input((_) => ActivationLost(attempt: attempt));
  }

  /// Hands the activated model to a fresh agent provider, which reaches it
  /// at [endpoint] and holds its agents' sessions with the provider.
  void spawn(int contextWindow, InferenceEndpoint endpoint) {
    final provider = data.connection!.provider;
    final model = data.model!.copyWith(contextWindow: contextWindow);
    data
      ..model = model
      ..servingSince = get<RecoveryPolicy>().clock.now()
      ..handle = factories.agentProviderSpawner(
        client: factories.inferenceClientFactory(endpoint),
        sessions: provider.openSessions(contextWindow: contextWindow),
        modelId: model.id,
        contextWindow: contextWindow,
        maxAgents: data.settings!.maxAgents,
      );
  }
}

/// The chosen model serves completions until its provider loses it, when
/// it is activated again after a wait, up to the recovery policy's limit.
@model
final class ReadyState extends RunningState {
  ReadyState() {
    on<ActivationLost>((input) {
      if (input.attempt != data.attempt) return toSelf();
      final policy = get<RecoveryPolicy>();
      final served = policy.clock.now().difference(data.servingSince);
      releaseHandle();
      data
        ..losses = served >= policy.stableAfter ? 1 : data.losses + 1
        ..attempt += 1
        ..activationProgress = null;
      if (data.losses <= policy.maxLosses) return to<RecoveringState>();
      data.failure = ProviderFailure(
        kind: InferenceFailureKind.server,
        message:
            '${data.model!.name} stopped being served ${data.losses} times '
            'in a row. Reconnect to try again.',
      );
      return to<ActivationFailedState>();
    });
  }
}

/// The chosen model was lost; it is activated again once the wait the
/// recovery policy sets for this loss is over.
@model
final class RecoveringState extends RunningState {
  RecoveringState() {
    onEnter(() {
      final attempt = data.attempt;
      final policy = get<RecoveryPolicy>();
      final due = Completer<void>();
      data.recovery = policy.startTimer(
        policy.delayBefore(data.losses),
        due.complete,
      );
      async(due.future).input((_) => RecoveryDue(attempt: attempt));
    });

    onExit(() => data.recovery?.cancel());

    on<RecoveryDue>(
      (input) =>
          input.attempt == data.attempt ? to<ActivatingState>() : toSelf(),
    );
  }
}

/// The last attempt did not produce a usable provider.
@model
sealed class FailedState extends ProviderSessionState {}

/// The provider or the model could not be confirmed. A change in the
/// provider's models may be the fix, so it probes again then.
@model
final class ProbeFailedState extends FailedState {
  @override
  Transition onModelsChanged(ModelsChanged input) {
    forgetModelsOf(input.providerId);
    if (settingsRunningOn(input.providerId) case final settings?) {
      apply(settings);
      return to<ConnectingState>();
    }
    return toSelf();
  }
}

/// The model could not be readied, kept being lost, or was stopped.
@model
final class ActivationFailedState extends FailedState {}

@model
final class ProviderSessionLogic extends LogicBlock<ProviderSessionState> {
  ProviderSessionLogic({
    required ProviderSessionFactories factories,
    required ModelCatalog catalog,
    required RecoveryPolicy recovery,
  }) {
    set(ProviderSessionData());
    set(factories);
    set<ModelCatalog>(catalog);
    set(recovery);

    set(UnconfiguredState());
    set(ConnectingState());
    set(ActivatingState());
    set(ReadyState());
    set(RecoveringState());
    set(ProbeFailedState());
    set(ActivationFailedState());
  }

  @override
  Transition getInitialState() => to<UnconfiguredState>();
}
