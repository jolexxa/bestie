import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

@model
sealed class StatusBarInput {
  const StatusBarInput();
}

/// The session's sandbox moved along its startup.
@model
final class SandboxReadinessChanged extends StatusBarInput {
  const SandboxReadinessChanged(this.readiness);

  final SandboxReadiness readiness;
}

/// The user took back their write grants and the sandbox was rebuilt.
@model
final class WriteGrantsForgottenReported extends StatusBarInput {
  const WriteGrantsForgottenReported(this.forgotten);

  final WriteGrantsForgotten forgotten;
}

/// The provider reported a new connection status.
@model
final class ProviderStatusChanged extends StatusBarInput {
  const ProviderStatusChanged(this.status);

  final ProviderStatus status;
}

/// A balance came back from the provider.
@model
final class CreditsChanged extends StatusBarInput {
  const CreditsChanged(this.credits);

  final CreditsResult credits;
}

/// The primary conversation moved; a turn may have just finished.
@model
final class ConversationChanged extends StatusBarInput {
  const ConversationChanged(this.conversation);

  final ConversationState conversation;
}
