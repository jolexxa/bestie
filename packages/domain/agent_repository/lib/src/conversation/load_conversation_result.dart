import 'package:intentions/intentions.dart';

/// Outcome of swapping a saved conversation into the primary session.
@model
sealed class LoadConversationResult {
  const LoadConversationResult();
}

/// The conversation is now the primary session's history.
@model
final class ConversationLoaded extends LoadConversationResult {
  const ConversationLoaded();
}

/// Nothing is saved under that id.
@model
final class ConversationNotFound extends LoadConversationResult {
  const ConversationNotFound();
}
