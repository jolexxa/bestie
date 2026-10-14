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
    on<ClientReconfigured>(onClientReconfigured);
    on<LoadCompleted>(onLoadCompleted);
  }

  ProviderSessionData get data => get<ProviderSessionData>();

  /// The settings the session can run under, once complete ones are given.
  ProviderSettings? get runnable => switch (data.settings) {
    final settings? when settings.isComplete => settings,
    _ => null,
  };

  Transition onConfigure(ConfigureProvider input) {
    if (input.settings.isComplete) return startOver(input.settings);
    apply(input.settings);
    return to<UnconfiguredState>();
  }

  Transition onReconnect(ReconnectProvider input) => switch (runnable) {
    final settings? => startOver(settings),
    null => toSelf(),
  };

  Transition onStop(StopProvider input) => toSelf();

  /// Notes what the client now reports; a session set to run on it starts
  /// over.
  Transition onClientReconfigured(ClientReconfigured input) {
    data.availability[input.providerId] = input.availability;
    final settings = runnable;
    if (settings?.model?.providerId != input.providerId) return toSelf();
    return startOver(settings!);
  }

  /// Adopts the complete [settings] and starts the session over.
  Transition startOver(ProviderSettings settings) {
    apply(settings);
    return to<StartingState>();
  }

  /// A load that ended after the session moved on is released at once.
  Transition onLoadCompleted(LoadCompleted input) {
    if (input.result case ProviderModelLoaded(:final model)) {
      output(ModelReleased(model));
    }
    return toSelf();
  }

  /// Adopts [settings], letting go of whatever ran under the last ones.
  void apply(ProviderSettings settings) {
    releaseRuntime();
    data
      ..settings = settings
      ..attempt += 1
      ..model = null
      ..loading = null
      ..failure = null;
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
  Transition onStop(StopProvider input) => fail(
    const ProviderCancelled(
      'Stopped. Reconnect or pick a model to start again.',
    ),
  );

  /// Leaves the session failed with [failure] until the settings change or
  /// a reconnect; whatever was under way lands unheeded.
  Transition fail(ProviderFailure failure) {
    data
      ..attempt += 1
      ..loading = null
      ..failure = failure;
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

  /// Starts over under [settings] without leaving, so a lookup under way
  /// is left to land unheeded.
  @override
  Transition startOver(ProviderSettings settings) {
    apply(settings);
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
    final client = data.clients[ref.providerId];
    final resolving = switch ((client, data.availability[ref.providerId])) {
      (null, _) => Future<ModelResolution>.value(
        ModelUnresolved(
          ProviderRejected('No provider is called "${ref.providerId}".'),
        ),
      ),
      (_, ProviderNotSetUp(:final failure)) => Future<ModelResolution>.value(
        ModelUnresolved(failure),
      ),
      (final client?, _) => ModelResolution.of(
        ref,
        client: client,
        providerName: client.displayName,
      ),
    };
    async(resolving).input(
      (resolution) => ModelResolved(attempt: attempt, resolution: resolution),
    );
  }

  void load() {
    final attempt = data.attempt;
    final model = data.model!;
    final loading = data.clients[model.ref.providerId]!.load(
      ProviderModelLoadRequest(
        modelId: model.id,
        contextWindow: model.contextWindow,
        maxAgents: data.settings!.maxAgents,
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
      ..runtime = loaded.runtime;
    async(loaded.lost).input(
      (failure) => ModelLost(attempt: attempt, failure: failure),
    );
  }
}

/// The chosen model serves completions until its provider loses it, which
/// fails the session with the provider's reason.
@model
final class ReadyState extends RunningState {
  ReadyState() {
    on<ModelLost>(
      (input) => input.attempt == data.attempt ? fail(input.failure) : toSelf(),
    );
  }
}

/// The model could not be found or loaded, was lost, or was stopped. A
/// provider configured anew or a reconnect gets its model another try.
@model
final class FailedState extends ProviderSessionState {
  FailedState() {
    onEnter(releaseLoaded);
  }
}

@model
final class ProviderSessionLogic extends LogicBlock<ProviderSessionState> {
  ProviderSessionLogic({required List<ProviderClient> clients}) {
    set(
      ProviderSessionData()
        ..clients = {for (final client in clients) client.id: client}
        ..availability = {
          for (final client in clients) client.id: client.availability,
        },
    );
    set(UnconfiguredState());
    set(StartingState());
    set(ReadyState());
    set(FailedState());
  }

  @override
  Transition getInitialState() => to<UnconfiguredState>();
}
