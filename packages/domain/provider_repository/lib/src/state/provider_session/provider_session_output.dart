import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:intentions/intentions.dart';

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
