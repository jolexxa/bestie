import 'package:bestie_chat_use_case/bestie_chat_use_case.dart'
    show ConversationReplacement;
import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:intentions/intentions.dart';

/// Outputs produced by the chat state machine.
@model
sealed class ChatOutput {
  const ChatOutput();
}

/// Blackboard data changed within the same state — re-derive UI state.
@model
final class StateUpdated extends ChatOutput {
  const StateUpdated();
}

/// The selection cursor moved (or zone entered). The view subscribes
/// to this signal to ensure the cursor is visible — calls
/// `ensureIndexVisible(position.itemIndex)` on its scroll controller.
@model
final class CursorMoved extends ChatOutput {
  const CursorMoved(this.position);

  final SelectionPosition position;
}

/// The user deliberately put the cursor on a timeline item — by key or by
/// click.
@model
final class ItemSelected extends ChatOutput {
  const ItemSelected();
}

/// A user message was accepted and the turn has started.
@model
final class MessageAccepted extends ChatOutput {
  const MessageAccepted();
}

/// The whole conversation was swapped out, and why.
@model
final class ConversationSwitched extends ChatOutput {
  const ConversationSwitched(this.replacement);

  final ConversationReplacement replacement;
}

/// The turn failed — carries error for display.
@model
final class TurnErrorLog extends ChatOutput {
  const TurnErrorLog(this.error);

  final String error;
}
