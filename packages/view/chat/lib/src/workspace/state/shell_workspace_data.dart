import 'package:intentions/intentions.dart';
import 'package:shell_repository/shell_repository.dart';

/// Id of the pinned Details tab — a selected item's output.
const detailsTabId = 'details';

/// Id of the pinned `{ }` tab — a selected item's inputs.
const propertiesTabId = 'properties';

/// Shared mutable data stored on the logic block blackboard.
@model
class ShellWorkspaceData {
  ShellWorkspaceData();

  /// The open user shells, one tab each.
  List<ShellSessionSummary> shells = const [];

  /// The shell tab currently shown, or null when a pinned tab is.
  ShellSessionId? activeShellId;

  /// The pinned tabs visible for the current selection, in strip order.
  List<String> pinnedIds = const [detailsTabId];

  /// The pinned tab shown when no shell is.
  String activePinnedId = detailsTabId;
}
