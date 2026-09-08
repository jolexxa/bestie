import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Work the owning agent performs on the turn's behalf. Everything else the
/// turn outputs is an `AgentRuntimeEvent` for the event stream.
sealed class RemoteTurnWork {
  const RemoteTurnWork();
}

/// Open a completion stream and feed its events back tagged
/// [completionId].
final class CompletionRequested extends RemoteTurnWork {
  const CompletionRequested({
    required this.completionId,
    required this.request,
  });

  final int completionId;
  final CompletionRequest request;
}

/// The agent's token usage changed; the provider republishes its pool.
final class UsageChanged extends RemoteTurnWork {
  const UsageChanged(this.usage);

  final RemoteUsage usage;
}

/// A completion reported what it cost, in the provider's currency.
final class SpendReported extends RemoteTurnWork {
  const SpendReported(this.cost);

  final double cost;
}
