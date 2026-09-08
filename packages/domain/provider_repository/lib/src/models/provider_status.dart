import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show
        ProviderFailure,
        ProviderKeyInfo,
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
    ConnectingState() => ProviderStatusConnecting(
      model: data.settings!.model!,
    ),
    ReadyState() => ProviderStatusReady(
      model: data.model!,
      handle: data.handle!,
      keyInfo: data.keyInfo,
      providerName: data.connection!.provider.displayName,
    ),
    FailedState() => ProviderStatusFailed(
      failure: data.failure!,
      model: data.settings!.model!,
    ),
  };

  /// Running agent provider (null unless ready).
  AgentProvider? get provider => switch (this) {
    ProviderStatusReady(:final handle) => handle,
    _ => null,
  };
}

/// No usable account or no model yet.
@model
final class ProviderStatusUnconfigured extends ProviderStatus {
  const ProviderStatusUnconfigured();
}

/// Validating the key and looking the model up.
@model
final class ProviderStatusConnecting extends ProviderStatus {
  const ProviderStatusConnecting({required this.model});

  final ProviderModelRef model;
}

/// Agents can run.
@model
final class ProviderStatusReady extends ProviderStatus {
  const ProviderStatusReady({
    required this.model,
    required this.handle,
    required this.keyInfo,
    required this.providerName,
  });

  /// Send nothing; the model thinks however the provider configures it.
  static const String reasoningAuto = 'auto';

  /// Ask the model not to think.
  static const String reasoningOff = 'off';

  /// Ask the model to think, without choosing how hard.
  static const String reasoningOn = 'on';

  final ResolvedModel model;
  final AgentProvider handle;

  /// Null when the provider has no key metadata to offer.
  final ProviderKeyInfo? keyInfo;
  final String providerName;

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
