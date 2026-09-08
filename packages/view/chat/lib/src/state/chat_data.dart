import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:bestie_chat_view/src/state/models/write_access_choice.dart';
import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

/// The reasoning mode every model offers: think however the provider
/// configures it.
const String reasoningAuto = 'auto';

/// The reasoning mode that asks the model not to think.
const String reasoningOff = 'off';

/// Mutable data container stored on the logic block blackboard.
///
/// Contains only UI-local state. Model state lives on the model
/// repository and conversation state lives on the conversation
/// repository — both accessed via ChatState delegation. Selection
/// state lives on the embedded `SelectionLogic` child block.
@model
final class ChatData {
  /// Current reasoning mode string (e.g. 'auto', 'off', 'low').
  String reasoningMode = reasoningAuto;

  /// Last primary agent provider observed when entering ready. Used to
  /// detect "fresh primary vs same primary" across reconnects.
  AgentProvider? lastPrimaryHandle;

  /// Where the sandbox stands, mirrored from the sandbox use case.
  SandboxReadiness sandboxReadiness = const SandboxReady();

  /// The agent's ask for write access awaiting the user, mirrored from the
  /// sandbox use case.
  WriteAccessRequest? pendingWriteAccess;

  /// Which answer to [pendingWriteAccess] keyboard focus rests on.
  WriteAccessChoice writeAccessChoice = WriteAccessChoice.deny;

  /// Unsettled tool jobs, mirrored from the tools use case. Drives the
  /// idle-state stop affordance.
  int activeJobs = 0;

  /// When a bare Escape last landed with nothing to stop. A second one soon
  /// after completes the chord that enters rewind.
  DateTime? escapeArmedAt;

  /// Where the cursor sat before rewind moved it, so cancelling can put it
  /// back.
  SelectionPosition? cursorBeforeRewind;
}
