import 'package:intentions/intentions.dart';
import 'package:shell_repository/shell_repository.dart';

/// Inputs to the shell workspace logic block.
@model
sealed class ShellWorkspaceInput {
  const ShellWorkspaceInput();
}

/// The use case published a new roster of open user shells.
@model
final class RosterUpdated extends ShellWorkspaceInput {
  const RosterUpdated(this.shells);

  final List<ShellSessionSummary> shells;
}

/// The user picked the tab registered under [id].
@model
final class SelectTab extends ShellWorkspaceInput {
  const SelectTab(this.id);

  final String id;
}

/// The selection changed, so the set of pinned tabs it can show did too. The
/// pinned-tab analog of [RosterUpdated].
@model
final class PinnedTabsSynced extends ShellWorkspaceInput {
  const PinnedTabsSynced(this.pinnedIds);

  final List<String> pinnedIds;
}

/// The user picked a row to read, so the pinned area comes forward — even when
/// a shell tab was covering it — on whichever pinned tab is sticky.
@model
final class PinnedAreaShown extends ShellWorkspaceInput {
  const PinnedAreaShown();
}

/// The user asked for a new shell sized to the content area.
@model
final class OpenShell extends ShellWorkspaceInput {
  const OpenShell({required this.rows, required this.cols});

  final int rows;
  final int cols;
}

/// The user closed the tab registered under [id].
@model
final class CloseTab extends ShellWorkspaceInput {
  const CloseTab(this.id);

  final ShellSessionId id;
}

/// A raw left press landed either over the active pane or elsewhere.
@model
final class ClickedAt extends ShellWorkspaceInput {
  const ClickedAt({required this.overActivePane});

  final bool overActivePane;
}
