import 'package:intentions/intentions.dart';

/// Why the primary session's history was just swapped out wholesale.
@model
sealed class ConversationReplacement {
  const ConversationReplacement();
}

/// A fresh, empty conversation took its place.
@model
final class StartedFresh extends ConversationReplacement {
  const StartedFresh();
}

/// A saved conversation took its place.
@model
final class LoadedFromDisk extends ConversationReplacement {
  const LoadedFromDisk();
}

/// A prefix of the same conversation took its place, cut just before one of
/// the user's messages; [message] is that message's text, handed back for
/// editing.
@model
final class RewoundToMessage extends ConversationReplacement {
  const RewoundToMessage({required this.message});

  final String message;
}
