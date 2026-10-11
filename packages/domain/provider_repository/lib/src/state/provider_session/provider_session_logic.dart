import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/state/provider_session/model_resolution.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_data.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_input.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_output.dart';

/// State hierarchy for the provider session. Only [ReadyState] holds a
/// loaded model; every other state lets go of it.
@model
sealed class ProviderSessionState extends StateLogic<ProviderSessionState> {
  ProviderSessionState() {
    on<ConfigureProvider>(onConfigure);
    on<ReconnectProvider>(onReconnect);
    on<StopProvider>(onStop);
    on<LoadCompleted>(onLoadCompleted);
  }

  ProviderSessionData get data => get<ProviderSessionData>();
  List<Provider> get providers => get<List<Provider>>();

  Transition onConfigure(ConfigureProvider input) {
    apply(input.settings);
    return input.settings.isComplete
        ? to<StartingState>()
        : to<UnconfiguredState>();
  }

  Transition onReconnect(ReconnectProvider input) {
    final settings = data.settings;
    if (settings == null || !settings.isComplete) return toSelf();
    apply(settings);
    return to<StartingState>();
  }

  Transition onStop(StopProvider input) => toSelf();

  /// A load that ended after the session moved on is released at once.
  Transition onLoadCompleted(LoadCompleted input) {
    if (input.result case ProviderModelLoaded(:final model)) {
      output(ModelReleased(model));
    }
    return toSelf();
  }

  /// Adopts [settings] and starts the session over. Each provider keeps its
  /// connection while its credentials stay the same; the rest are replaced.
  void apply(ProviderSettings settings) {
    releaseRuntime();
    for (final provider in providers) {
      final credentials =
          settings.credentials[provider.id] ?? const NoCredentials();
      if (data.connectedWith[provider.id] == credentials) continue;
      if (data.connections[provider.id] case final retired?) {
        output(ConnectionRetired(retired));
      }
      data
        ..connections[provider.id] = provider.connect(credentials)
        ..connectedWith[provider.id] = credentials;
    }
    data
      ..settings = settings
      ..attempt += 1
      ..model = null
      ..loading = null
      ..failure = null
      ..losses = 0;
  }

  /// Hands the agent runtime, if one runs, to whoever tears it down.
  void releaseRuntime() {
    if (data.runtime case final runtime?) output(RuntimeReleased(runtime));
    data.runtime = null;
  }

  /// Hands the loaded model, if any, to whoever releases it.
  void releaseLoaded() {
    releaseRuntime();
    if (data.loaded case final loaded?) output(ModelReleased(loaded));
    data.loaded = null;
  }
}

@model
final class UnconfiguredState extends ProviderSessionState {
  UnconfiguredState() {
    onEnter(releaseLoaded);
  }
}

/// The session is on its way to running the chosen model, or runs it.
@model
sealed class RunningState extends ProviderSessionState {
  @override
  Transition onConfigure(ConfigureProvider input) =>
      adopt(input.settings) ? toSelf() : super.onConfigure(input);

  /// Keeps [settings] for the next load when they run the session already
  /// under way, leaving what runs be. False when they do not.
  bool adopt(ProviderSettings settings) {
    if (!data.settings!.runsSameSessionAs(settings)) return false;
    data.settings = settings;
    return true;
  }

  /// Leaves the session failed until the settings change or a reconnect.
  @override
  Transition onStop(StopProvider input) {
    data
      ..attempt += 1
      ..loading = null
      ..failure = const ProviderCancelled(
        'Stopped. Reconnect or pick a model to start again.',
      );
    return to<FailedState>();
  }
}

/// Looks the chosen model up, then loads it. A model loaded before stays
/// until the new load has started, so a provider that serves one model at
/// a time can hand over to the next without letting go in between.
@model
final class StartingState extends RunningState {
  StartingState() {
    onEnter(start);

    on<ModelResolved>((input) {
      if (input.attempt != data.attempt) return toSelf();
      switch (input.resolution) {
        case ModelUnresolved(:final failure):
          data.failure = failure;
          return to<FailedState>();
        case ModelFound(:final model):
          data.model = model;
          load();
          return toSelf();
      }
    });

    on<LoadProgressed>((input) {
      if (input.attempt != data.attempt) return toSelf();
      data.loading = input.progress;
      output(const ProviderSessionChanged());
      return toSelf();
    });
  }

  @override
  Transition onConfigure(ConfigureProvider input) {
    if (adopt(input.settings)) return toSelf();
    apply(input.settings);
    if (!input.settings.isComplete) return to<UnconfiguredState>();
    start();
    output(const ProviderSessionChanged());
    return toSelf();
  }

  @override
  Transition onReconnect(ReconnectProvider input) {
    apply(data.settings!);
    start();
    output(const ProviderSessionChanged());
    return toSelf();
  }

  @override
  Transition onLoadCompleted(LoadCompleted input) {
    if (input.attempt != data.attempt) return super.onLoadCompleted(input);
    switch (input.result) {
      case ProviderModelLoadFailed(:final failure):
        data.failure = failure;
        return to<FailedState>();
      case ProviderModelLoaded(:final model):
        serve(model);
        return to<ReadyState>();
    }
  }

  void start() {
    final attempt = data.attempt;
    final ref = data.settings!.model!;
    final provider = providers
        .where((provider) => provider.id == ref.providerId)
        .firstOrNull;
    final resolving = provider == null
        ? Future<ModelResolution>.value(
            ModelUnresolved(
              ProviderRejected('No provider is called "${ref.providerId}".'),
            ),
          )
        : ModelResolution.of(
            ref,
            connection: data.connections[provider.id]!,
            providerName: provider.displayName,
          );
    async(resolving).input(
      (resolution) => ModelResolved(attempt: attempt, resolution: resolution),
    );
  }

  void load() {
    final attempt = data.attempt;
    final model = data.model!;
    final settings = data.settings!;
    final loading = data.connections[model.ref.providerId]!.load(
      ProviderModelLoadRequest(
        modelId: model.id,
        contextWindow: model.contextWindow,
        maxAgents: settings.maxAgents,
        contextCap: settings.contextCap,
      ),
    );
    releaseLoaded();
    output(LoadStarted(attempt: attempt, progress: loading.progress));
    async(loading.result).input(
      (result) => LoadCompleted(attempt: attempt, result: result),
    );
  }

  /// Runs a fresh agent runtime on [loaded] and watches for its loss.
  void serve(ProviderModel loaded) {
    final attempt = data.attempt;
    final model = data.model!.copyWith(contextWindow: loaded.contextWindow);
    data
      ..model = model
      ..loaded = loaded
      ..servingSince = get<RecoveryPolicy>().clock.now()
      ..runtime = loaded.runtime;
    async(loaded.lost).input((_) => ModelLost(attempt: attempt));
  }
}

/// The chosen model serves completions until its provider loses it, when
/// it is loaded again after a wait, up to the recovery policy's limit.
@model
final class ReadyState extends RunningState {
  ReadyState() {
    on<ModelLost>((input) {
      if (input.attempt != data.attempt) return toSelf();
      final policy = get<RecoveryPolicy>();
      final served = policy.clock.now().difference(data.servingSince);
      data
        ..losses = served >= policy.stableAfter ? 1 : data.losses + 1
        ..attempt += 1
        ..loading = null;
      if (data.losses <= policy.maxLosses) return to<RecoveringState>();
      data.failure = ProviderServerFailed(
        '${data.model!.name} stopped being served ${data.losses} times '
        'in a row. Reconnect to try again.',
      );
      return to<FailedState>();
    });
  }
}

/// The chosen model was lost; it is loaded again once the wait the
/// recovery policy sets for this loss is over.
@model
final class RecoveringState extends RunningState {
  RecoveringState() {
    onEnter(() {
      releaseLoaded();
      final attempt = data.attempt;
      final policy = get<RecoveryPolicy>();
      final due = Completer<void>();
      data.recovery = Timer(policy.delayBefore(data.losses), due.complete);
      async(due.future).input((_) => RecoveryDue(attempt: attempt));
    });

    onExit(() => data.recovery?.cancel());

    on<RecoveryDue>(
      (input) => input.attempt == data.attempt ? to<StartingState>() : toSelf(),
    );
  }
}

/// The model could not be found or loaded, kept being lost, or was
/// stopped.
@model
final class FailedState extends ProviderSessionState {
  FailedState() {
    onEnter(releaseLoaded);
  }
}

@model
final class ProviderSessionLogic extends LogicBlock<ProviderSessionState> {
  ProviderSessionLogic({
    required List<Provider> providers,
    required RecoveryPolicy recovery,
  }) {
    set(
      ProviderSessionData()
        ..connections = {
          for (final provider in providers)
            provider.id: provider.connect(const NoCredentials()),
        }
        ..connectedWith = {
          for (final provider in providers) provider.id: const NoCredentials(),
        },
    );
    set<List<Provider>>(providers);
    set(recovery);

    set(UnconfiguredState());
    set(StartingState());
    set(ReadyState());
    set(RecoveringState());
    set(FailedState());
  }

  @override
  Transition getInitialState() => to<UnconfiguredState>();
}
