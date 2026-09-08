import 'package:intentions/intentions.dart';

/// Outputs from the shell workspace logic block.
@model
sealed class ShellWorkspaceOutput {
  const ShellWorkspaceOutput();
}

/// The UI should rebuild — emitted on every data change that does not
/// already announce itself as a state transition.
@model
final class StateUpdated extends ShellWorkspaceOutput {
  const StateUpdated();
}
