import 'package:agentic_terminal/agentic_terminal.dart'
    show MouseButton, parseHostInput;
import 'package:bestie_chat_view/src/workspace/shell_pane.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_cubit.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_state.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart' hide MouseButton;

export 'package:bestie_chat_view/src/workspace/state/shell_workspace_data.dart'
    show detailsTabId, propertiesTabId;

/// One pinned tab the workspace hosts.
@model
final class WorkspacePinnedTab {
  const WorkspacePinnedTab({
    required this.id,
    required this.label,
    required this.child,
  });

  final String id;
  final String label;
  final Component child;
}

/// Browser-style tab host for the chat details pane.

@view
class ShellWorkspace extends StatelessComponent {
  const ShellWorkspace({
    required this.cubit,
    required this.pinnedTabs,
    required this.active,
    super.key,
  });

  /// The tab host's view model, owned and driven by whoever built it — the chat
  /// page.
  final ShellWorkspaceCubit cubit;

  /// Every pinned tab the host can show.
  final List<WorkspacePinnedTab> pinnedTabs;

  /// Whether this workspace's region owns the keyboard at all. The active
  /// shell tab only captures input while this is `true`.
  final bool active;

  @override
  Component build(BuildContext context) =>
      BlocProvider<ShellWorkspaceCubit>.value(
        value: cubit,
        child: _ShellWorkspaceView(pinnedTabs: pinnedTabs, active: active),
      );
}

class _ShellWorkspaceView extends StatefulComponent {
  const _ShellWorkspaceView({required this.pinnedTabs, required this.active});

  final List<WorkspacePinnedTab> pinnedTabs;
  final bool active;

  @override
  State<_ShellWorkspaceView> createState() => _ShellWorkspaceViewState();
}

class _ShellWorkspaceViewState extends State<_ShellWorkspaceView> {
  late final ShellWorkspaceCubit _cubit = BlocProvider.of<ShellWorkspaceCubit>(
    context,
    listen: false,
  );

  /// Whether the mouse is over the active pane's box right now, reported
  /// upward by the pane.
  bool _paneHovered = false;

  /// Size the content area was last laid out at, so a new shell spawns at
  /// the size it will be shown at rather than reflowing on first paint.
  int _paneRows = 24;
  int _paneCols = 80;

  /// Routes raw left presses to the cubit with the hit test pre-computed.
  bool _onRawInput(List<int> bytes) {
    for (final event in parseHostInput(bytes).mouseEvents) {
      if (event.button != MouseButton.left || !event.press) continue;
      _cubit.clickedAt(overActivePane: _paneHovered);
    }
    return false;
  }

  Component _buildContent(ShellWorkspaceState state) {
    final session = state.activeSession;
    if (session != null) {
      return ShellPane(
        key: ValueKey(session.id),
        surface: session,
        focused: state.terminalFocused && component.active,
        onHoverChanged: ({required hovered}) => _paneHovered = hovered,
      );
    }
    return _pinnedContent(state.activeId);
  }

  /// The pinned tab shown when no shell is up.
  Component _pinnedContent(String activeId) {
    for (final tab in component.pinnedTabs) {
      if (tab.id == activeId) return tab.child;
    }
    return component.pinnedTabs.isEmpty
        ? const SizedBox.shrink()
        : component.pinnedTabs.first.child;
  }

  @override
  Component build(BuildContext context) {
    return BlocBuilder<ShellWorkspaceCubit, ShellWorkspaceState>(
      bloc: _cubit,
      builder: (context, state) => InputListener(
        onInput: _onRawInput,
        child: Column(
          children: [
            TabStrip(
              tabs: [
                for (final tab in component.pinnedTabs)
                  if (state.pinnedIds.contains(tab.id))
                    TabStripItem(
                      id: tab.id,
                      label: tab.label,
                      closable: false,
                    ),
                for (final shell in state.shells)
                  TabStripItem(id: shell.id, label: shell.title),
              ],
              activeId: state.activeId,
              onSelect: _cubit.select,
              onClose: _cubit.closeTab,
              onNew: () => _cubit.openShell(rows: _paneRows, cols: _paneCols),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Less the frame the pane draws around the grid.
                  _paneRows = constraints.maxHeight.toInt() - 2;
                  _paneCols = constraints.maxWidth.toInt() - 2;
                  return _buildContent(state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
