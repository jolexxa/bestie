import 'package:intentions/intentions.dart';

/// Outputs produced by the agent shell logic block.
@model
sealed class AgentShellOutput {
  const AgentShellOutput();
}

/// The attached shell changed — rebuild around it.
@model
final class AttachmentChanged extends AgentShellOutput {
  const AttachmentChanged();
}
