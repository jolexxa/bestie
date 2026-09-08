import 'package:intentions/intentions.dart';

/// Outputs produced by the shell pane logic block.
@model
sealed class ShellPaneOutput {
  const ShellPaneOutput();
}

/// Something the surface draws from changed — repaint.
@model
final class PaneUpdated extends ShellPaneOutput {
  const PaneUpdated();
}
