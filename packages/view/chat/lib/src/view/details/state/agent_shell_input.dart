import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:intentions/intentions.dart';

/// Inputs to the agent shell logic block.
@model
sealed class AgentShellInput {
  const AgentShellInput();
}

/// The use case published what this call has to show of its shell.
@model
final class AttachmentPublished extends AgentShellInput {
  const AttachmentPublished(this.attachment);

  final AgentShellAttachment attachment;
}
