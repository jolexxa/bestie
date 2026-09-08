import 'dart:async';
import 'dart:math' as math;

import 'package:bestie_chat_view/src/workspace/state/shell_workspace_data.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_output.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/shell_repository.dart';

/// Base state for the shell workspace logic block.
@model
sealed class ShellWorkspaceState extends StateLogic<ShellWorkspaceState> {
  ShellWorkspaceState() {
    on<RosterUpdated>(_onRosterUpdated);
    on<SelectTab>(_onSelectTab);
    on<PinnedTabsSynced>(_onPinnedTabsSynced);
    on<PinnedAreaShown>(_onPinnedAreaShown);
    on<OpenShell>(_onOpenShell);
    on<CloseTab>(_onCloseTab);
  }

  ShellWorkspaceData get data => get<ShellWorkspaceData>();
  ShellUseCase get shell => get<ShellUseCase>();

  /// The open user shells, one tab each.
  List<ShellSessionSummary> get shells => data.shells;

  /// The pinned tabs visible for the current selection, in strip order.
  List<String> get pinnedIds => data.pinnedIds;

  /// The id of the tab currently shown.
  String get activeId => data.activeShellId ?? data.activePinnedId;

  /// The pinned tab to fall back to when the sticky one cannot be shown.
  String get _preferredPinnedId {
    if (data.pinnedIds.contains(detailsTabId)) return detailsTabId;
    return data.pinnedIds.isEmpty ? detailsTabId : data.pinnedIds.first;
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The roster entry for the shown shell tab, or null on the details tab.
  ShellSessionSummary? get activeShell {
    for (final summary in data.shells) {
      if (summary.id == data.activeShellId) return summary;
    }
    return null;
  }

  /// The live session behind the shown shell tab, or null on the details
  /// tab or when the session has already been closed underneath us.
  ShellSession? get activeSession {
    final summary = activeShell;
    return summary == null ? null : shell.sessionFor(summary.id);
  }

  /// Whether the active shell pane holds the keyboard.
  bool get terminalFocused => false;

  /// A session that vanished underneath us — closed by someone other than
  /// [CloseTab] — folds its tab away here.
  Transition _onRosterUpdated(RosterUpdated input) {
    data.shells = input.shells;
    output(const StateUpdated());
    final active = data.activeShellId;
    if (active != null && !input.shells.any((s) => s.id == active)) {
      data.activeShellId = null;
      return to<DetailsActiveState>();
    }
    return toSelf();
  }

  /// Selecting a shell tab also hands it the keyboard.
  Transition _onSelectTab(SelectTab input) {
    final id = input.id;
    if (id == activeId) return toSelf();
    if (data.shells.any((s) => s.id == id)) {
      data.activeShellId = id;
      output(const StateUpdated());
      return to<ShellFocusedState>();
    }
    if (!data.pinnedIds.contains(id)) return toSelf();
    data
      ..activeShellId = null
      ..activePinnedId = id;
    output(const StateUpdated());
    return to<DetailsActiveState>();
  }

  /// The selection's pinned tabs changed underneath us.
  Transition _onPinnedTabsSynced(PinnedTabsSynced input) {
    if (_sameIds(data.pinnedIds, input.pinnedIds)) return toSelf();
    data.pinnedIds = input.pinnedIds;
    if (!input.pinnedIds.contains(data.activePinnedId)) {
      data.activePinnedId = _preferredPinnedId;
    }
    output(const StateUpdated());
    return toSelf();
  }

  /// Bring the pinned area forward on its sticky tab, leaving any shell tab
  /// running behind it.
  Transition _onPinnedAreaShown(PinnedAreaShown input) {
    data.activeShellId = null;
    output(const StateUpdated());
    return to<DetailsActiveState>();
  }

  Transition _onOpenShell(OpenShell input) {
    final session = shell.openUserShell(rows: input.rows, cols: input.cols);
    data
      ..shells = shell.userShells
      ..activeShellId = session.id;
    output(const StateUpdated());
    return to<ShellFocusedState>();
  }

  /// When the closed tab was on screen, selection moves to the next tab,
  /// else the previous, else the details tab.
  Transition _onCloseTab(CloseTab input) {
    final index = data.shells.indexWhere((s) => s.id == input.id);
    if (index < 0) return toSelf();
    unawaited(shell.close(input.id));
    final remaining = [
      for (final summary in data.shells)
        if (summary.id != input.id) summary,
    ];
    data.shells = remaining;
    output(const StateUpdated());
    if (data.activeShellId != input.id) return toSelf();
    if (remaining.isEmpty) {
      data.activeShellId = null;
      return to<DetailsActiveState>();
    }
    data.activeShellId = remaining[math.min(index, remaining.length - 1)].id;
    return to<ShellFocusedState>();
  }
}

/// The pinned details tab is shown; no shell holds the keyboard.
@model
final class DetailsActiveState extends ShellWorkspaceState {}

/// A shell tab is shown.
@model
sealed class ShellActiveState extends ShellWorkspaceState {}

/// The shown shell pane holds the keyboard.
@model
final class ShellFocusedState extends ShellActiveState {
  ShellFocusedState() {
    on<ClickedAt>(
      (input) => input.overActivePane ? toSelf() : to<ShellUnfocusedState>(),
    );
  }

  @override
  bool get terminalFocused => true;
}

/// A shell tab is shown but a click elsewhere released the keyboard.
@model
final class ShellUnfocusedState extends ShellActiveState {
  ShellUnfocusedState() {
    on<ClickedAt>(
      (input) => input.overActivePane ? to<ShellFocusedState>() : toSelf(),
    );
  }
}
