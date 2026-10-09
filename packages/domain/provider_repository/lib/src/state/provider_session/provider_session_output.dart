import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart' show Provider;

@model
sealed class ProviderSessionOutput {
  const ProviderSessionOutput();
}

/// An agent provider is no longer part of the session and should be torn
/// down by whoever owns side effects.
@model
final class ProviderHandleReleased extends ProviderSessionOutput {
  const ProviderHandleReleased(this.handle);

  final AgentProvider handle;
}

/// The session's data changed without a state change.
@model
final class ProviderSessionChanged extends ProviderSessionOutput {
  const ProviderSessionChanged();
}

/// The chosen model started getting ready under [attempt]; whoever owns
/// side effects feeds its [progress] back as inputs.
@model
final class ActivationStarted extends ProviderSessionOutput {
  const ActivationStarted({required this.attempt, required this.progress});

  final int attempt;

  /// From 0 to 1.
  final Stream<double> progress;
}

/// The session built a different set of [providers]; whoever owns side
/// effects follows their model listings from now on.
@model
final class ProvidersReplaced extends ProviderSessionOutput {
  const ProvidersReplaced(this.providers);

  final List<Provider> providers;
}

/// The session no longer runs on [provider], which should let go of what
/// activating held.
@model
final class ProviderDeactivated extends ProviderSessionOutput {
  const ProviderDeactivated(this.provider);

  final Provider provider;
}
