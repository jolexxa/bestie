import 'package:meta/meta.dart';

/// The outcome of asking an endpoint to hold a session for one agent.
sealed class AgentSessionResult {
  const AgentSessionResult();
}

/// The endpoint holds a session for the agent.
@immutable
final class AgentSessionOpened extends AgentSessionResult {
  const AgentSessionOpened({required this.claimedTokens});

  /// Context tokens set aside for the agent alone.
  final int claimedTokens;

  @override
  bool operator ==(Object other) =>
      other is AgentSessionOpened && other.claimedTokens == claimedTokens;

  @override
  int get hashCode => claimedTokens.hashCode;
}

/// Every session the endpoint can hold is taken.
final class AgentSessionNoCapacity extends AgentSessionResult {
  const AgentSessionNoCapacity();
}

/// The endpoint has a free session but too little context left to give it.
final class AgentSessionInsufficientClaim extends AgentSessionResult {
  const AgentSessionInsufficientClaim();
}

/// The endpoint could not be asked, or answered with something unexpected.
final class AgentSessionFailed extends AgentSessionResult {
  const AgentSessionFailed({required this.message});

  final String message;
}
