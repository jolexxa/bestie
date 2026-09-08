import 'package:agent_repository/agent_repository.dart'
    show ConversationState, SubagentSummary;
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart'
    show ConversationReplacement;
import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_repository/provider_repository.dart'
    show ProviderStatus;
import 'package:sandbox_repository/sandbox_repository.dart';

/// Inputs to the chat state machine.
@model
sealed class ChatInput {
  const ChatInput();
}

/// Initialize chat and follow the provider up.
@model
final class Start extends ChatInput {
  const Start();
}

/// Submit a user message.
@model
final class Submit extends ChatInput {
  const Submit(this.message);

  final String message;
}

/// Cancel the current turn.
@model
final class Cancel extends ChatInput {
  const Cancel();
}

/// Clear all messages and start a fresh conversation.
@model
final class Clear extends ChatInput {
  const Clear();
}

/// Cycle to the next reasoning mode.
@model
final class CycleReasoning extends ChatInput {
  const CycleReasoning();
}

/// A bare Escape reached the chat with no turn to stop. Two in quick
/// succession enter rewind.
@model
final class EscapePressed extends ChatInput {
  const EscapePressed();
}

/// Enter rewind: pick an earlier user message to cut the history back to.
@model
final class EnterRewind extends ChatInput {
  const EnterRewind();
}

/// Move the rewind cursor to the previous user message.
@model
final class RewindMoveUp extends ChatInput {
  const RewindMoveUp();
}

/// Move the rewind cursor to the next user message.
@model
final class RewindMoveDown extends ChatInput {
  const RewindMoveDown();
}

/// Cut the history back to the user message under the rewind cursor.
@model
final class ConfirmRewind extends ChatInput {
  const ConfirmRewind();
}

/// Leave rewind with the history untouched.
@model
final class CancelRewind extends ChatInput {
  const CancelRewind();
}

/// Dispose chat and clean up resources.
@model
final class Dispose extends ChatInput {
  const Dispose();
}

/// Move the selection cursor one slot earlier (toward older messages).
@model
final class MoveSelectionUp extends ChatInput {
  const MoveSelectionUp();
}

/// Move the selection cursor one slot later (toward newer messages).
@model
final class MoveSelectionDown extends ChatInput {
  const MoveSelectionDown();
}

/// Jump the selection cursor directly to timeline item [itemIndex].
@model
final class SelectTimelineItem extends ChatInput {
  const SelectTimelineItem(this.itemIndex);

  final int itemIndex;
}

/// Put the cursor on timeline item [itemIndex] and scroll it into view.
@model
final class RevealTimelineItem extends ChatInput {
  const RevealTimelineItem(this.itemIndex);

  final int itemIndex;
}

/// The viewport drifted away from the cursor (mouse scrolling, say) and the
/// view reports the item at its edge; the cursor snaps onto it without
/// scrolling or pulling the details pane forward.
@model
final class SelectVisibleItem extends ChatInput {
  const SelectVisibleItem(this.itemIndex);

  final int itemIndex;
}

/// Bridge input — fires when the embedded `SelectionLogic` emits
/// `PositionChanged`. The base `ChatState` handler re-emits this as
/// a `CursorMoved` chat-level output so the view's `onCursorMoved`
/// callback scrolls the cursor into view. Not intended for external
/// dispatchers; the ChatLogic constructor's binding is the only
/// producer.
@model
final class SelectionPositionChanged extends ChatInput {
  const SelectionPositionChanged(this.position);

  final SelectionPosition position;
}

/// Give pseudo-focus to the subagent zone (↓ off the end of the input).
@model
final class EnterSubagentZone extends ChatInput {
  const EnterSubagentZone();
}

/// Drop pseudo-focus back to the input field.
@model
final class ExitSubagentZone extends ChatInput {
  const ExitSubagentZone();
}

/// Move the zone highlight up one row (live-previews the viewed session).
@model
final class MoveSubagentUp extends ChatInput {
  const MoveSubagentUp();
}

/// Move the zone highlight down one row (live-previews the viewed session).
@model
final class MoveSubagentDown extends ChatInput {
  const MoveSubagentDown();
}

/// Stop the highlighted subagent.
@model
final class StopHighlightedSubagent extends ChatInput {
  const StopHighlightedSubagent();
}

/// Select the subagent at [index] (mouse click).
@model
final class SelectSubagentRow extends ChatInput {
  const SelectSubagentRow(this.index);

  final int index;
}

/// The subagent roster changed — pushed in from the use case stream.
@model
final class SubagentsChanged extends ChatInput {
  const SubagentsChanged(this.subagents);

  final List<SubagentSummary> subagents;
}

/// The tool system's unsettled-job count changed — pushed in from the
/// tools use case stream.
@model
final class ActiveJobsChanged extends ChatInput {
  const ActiveJobsChanged(this.count);

  final int count;
}

/// The hosted provider's status changed.
@model
final class ProviderStatusChanged extends ChatInput {
  const ProviderStatusChanged(this.status);

  final ProviderStatus status;
}

/// The primary's history was swapped out wholesale — pushed in from the use
/// case stream once the new history is in place.
@model
final class ConversationReplaced extends ChatInput {
  const ConversationReplaced(this.replacement);

  final ConversationReplacement replacement;
}

/// Conversation repository state changed.
@model
final class ConversationStateChanged extends ChatInput {
  const ConversationStateChanged(this.conversationState);

  final ConversationState conversationState;
}

/// The sandbox's readiness moved.
@model
final class SandboxReadinessChanged extends ChatInput {
  const SandboxReadinessChanged(this.readiness);

  final SandboxReadiness readiness;
}

/// The user answered the sandbox gate.
@model
final class InitializeSandbox extends ChatInput {
  const InitializeSandbox();
}

/// The ask for write access in front of the user changed — pushed in from
/// the sandbox use case stream.
@model
final class WriteAccessRequestChanged extends ChatInput {
  const WriteAccessRequestChanged(this.request);

  final WriteAccessRequest? request;
}

/// The user answered the ask for write access in front of them.
@model
final class AnswerWriteAccess extends ChatInput {
  const AnswerWriteAccess({required this.allow});

  final bool allow;
}

/// The user moved keyboard focus to the other answer to the ask for write
/// access.
@model
final class ToggleWriteAccessChoice extends ChatInput {
  const ToggleWriteAccessChoice();
}

/// The user confirmed the answer keyboard focus rests on.
@model
final class ConfirmWriteAccess extends ChatInput {
  const ConfirmWriteAccess();
}
