import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderModel, ProviderModelLoadProgress;

@model
sealed class ProviderSessionOutput {
  const ProviderSessionOutput();
}

/// The session's data changed without a state change.
@model
final class ProviderSessionChanged extends ProviderSessionOutput {
  const ProviderSessionChanged();
}

/// The chosen model started loading under [attempt]; whoever owns side
/// effects feeds its [progress] back as inputs.
@model
final class LoadStarted extends ProviderSessionOutput {
  const LoadStarted({required this.attempt, required this.progress});

  final int attempt;
  final Stream<ProviderModelLoadProgress> progress;
}

/// An agent runtime is no longer part of the session and should be torn
/// down by whoever owns side effects.
@model
final class RuntimeReleased extends ProviderSessionOutput {
  const RuntimeReleased(this.runtime);

  final AgentRuntime runtime;
}

/// A loaded model is no longer part of the session and should be released
/// by whoever owns side effects.
@model
final class ModelReleased extends ProviderSessionOutput {
  const ModelReleased(this.model);

  final ProviderModel model;
}
