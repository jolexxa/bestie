import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show
        ProviderFailure,
        ProviderModelLoadProgress,
        ProviderModelRef,
        ProviderReasoningEfforts,
        ProviderReasoningFixed,
        ProviderReasoningToggle;
import 'package:provider_repository/src/models/resolved_model.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_data.dart';
import 'package:provider_repository/src/state/provider_session/provider_session_logic.dart';

/// Snapshot of the provider session's lifecycle.
@model
sealed class ProviderStatus {
  const ProviderStatus();

  /// Project a [ProviderSessionState] into a status snapshot.
  static ProviderStatus fromState(
    ProviderSessionState state,
    ProviderSessionData data,
  ) => switch (state) {
    UnconfiguredState() => const ProviderStatusUnconfigured(),
    StartingState() || RecoveringState() => ProviderStatusConnecting(
      model: data.settings!.model!,
      loading: LoadingModel.of(data.model, progress: data.loading),
    ),
    ReadyState() => ProviderStatusReady(
      model: data.model!,
      runtime: data.runtime!,
      maxAgents: data.loaded!.maxAgents,
      deviceBytes: data.loaded!.deviceBytes,
    ),
    FailedState() => ProviderStatusFailed(
      failure: data.failure!,
      model: data.settings!.model!,
    ),
  };

  /// Running agent runtime (null unless ready).
  AgentRuntime? get runtime => null;
}

/// No model chosen yet.
@model
final class ProviderStatusUnconfigured extends ProviderStatus {
  const ProviderStatusUnconfigured();
}

/// Looking the model up and getting it ready.
@model
final class ProviderStatusConnecting extends ProviderStatus {
  const ProviderStatusConnecting({required this.model, this.loading});

  final ProviderModelRef model;

  /// The model being loaded, once its provider reports progress.
  final LoadingModel? loading;
}

/// A model on its way into memory.
@model
final class LoadingModel {
  const LoadingModel({
    required this.name,
    required this.providerName,
    required this.contextWindow,
    required this.progress,
  });

  final String name;

  final String providerName;

  /// The context the model was asked to run with.
  final int contextWindow;

  final ProviderModelLoadProgress progress;

  /// [model] at [progress], or null until both are known.
  static LoadingModel? of(
    ResolvedModel? model, {
    required ProviderModelLoadProgress? progress,
  }) => model == null || progress == null
      ? null
      : LoadingModel(
          name: model.name,
          providerName: model.providerName,
          contextWindow: model.contextWindow,
          progress: progress,
        );
}

/// Agents can run.
@model
final class ProviderStatusReady extends ProviderStatus {
  const ProviderStatusReady({
    required this.model,
    required this.runtime,
    required this.maxAgents,
    required this.deviceBytes,
  });

  /// Send nothing; the model thinks however the provider configures it.
  static const String reasoningAuto = 'auto';

  /// Ask the model not to think.
  static const String reasoningOff = 'off';

  /// Ask the model to think, without choosing how hard.
  static const String reasoningOn = 'on';

  final ResolvedModel model;
  @override
  final AgentRuntime runtime;

  /// The most agents the loaded model runs at once.
  final int maxAgents;

  /// Memory the model takes on this device; null when it runs elsewhere.
  final int? deviceBytes;

  String get providerName => model.providerName;

  int get contextWindow => model.contextWindow;

  /// The reasoning modes the chat surface may cycle through: `auto`, then
  /// `off` when the model allows it, then whatever the provider accepts.
  List<String> get reasoningModes => switch (model.reasoning) {
    null || ProviderReasoningFixed() => const [reasoningAuto],
    ProviderReasoningToggle() => const [
      reasoningAuto,
      reasoningOff,
      reasoningOn,
    ],
    ProviderReasoningEfforts(:final efforts, :final canDisable) => [
      reasoningAuto,
      if (canDisable) reasoningOff,
      ...efforts,
    ],
  };

  String get defaultReasoningMode => reasoningAuto;

  /// The effort the provider applies under `auto`, when it says.
  String? get defaultEffortLabel => switch (model.reasoning) {
    ProviderReasoningEfforts(:final defaultEffort) => defaultEffort,
    _ => null,
  };

  /// The cheapest legal thinking mode for compaction: the lowest effort the
  /// model accepts, else `off` when it may stop thinking, else `auto`.
  String get compactionReasoningMode => switch (model.reasoning) {
    null || ProviderReasoningFixed() => reasoningAuto,
    ProviderReasoningToggle() => reasoningOff,
    ProviderReasoningEfforts(:final efforts) => efforts.first,
  };
}

/// The last connection attempt did not produce a usable provider.
@model
final class ProviderStatusFailed extends ProviderStatus {
  const ProviderStatusFailed({required this.failure, required this.model});

  final ProviderFailure failure;
  final ProviderModelRef model;
}
