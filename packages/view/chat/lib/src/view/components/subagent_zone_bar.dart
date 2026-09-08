import 'dart:math' as math;

import 'package:agent_repository/agent_repository.dart' show SubagentStatus;
import 'package:bestie_chat_view/src/state/chat_cubit.dart';
import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The subagent zone: a Primary row for the main conversation, then one row
/// per subagent. While the zone has pseudo-focus, ↑/↓ browse with live
/// preview (↑ off Primary returns to the input) and Esc stops the
/// highlighted subagent, leaving Esc on the Primary row to the page — routed
/// through the shared [SelectionInputController] via [SelectableHandler], so
/// the text field keeps real focus. Rows are clickable (select + view) with a
/// hover tint that does not preview.
///
/// The bar is exactly as tall as its rows, up to [maxVisibleRows]; beyond
/// that the rows scroll and the highlight is kept in view.
@view
class SubagentZoneBar extends StatefulComponent {
  const SubagentZoneBar({required this.state, super.key});

  final ChatState state;

  static const int maxVisibleRows = 4;

  @override
  State<SubagentZoneBar> createState() => _SubagentZoneBarState();
}

class _SubagentZoneBarState extends State<SubagentZoneBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ChatState get state => component.state;

  @override
  Component build(BuildContext context) {
    if (state.subagents.isEmpty) return const SizedBox();

    final cubit = BlocProvider.of<ChatCubit>(context, listen: false);
    final theme = AppTheme.of(context);

    final totalRows = state.subagents.length + 1;
    final visibleRows = math.min(totalRows, SubagentZoneBar.maxVisibleRows);
    final overflowing = totalRows > visibleRows;

    final rows = <Component>[
      _row(
        cubit,
        theme,
        index: 0,
        leading: Text(' ◆ ', style: TextStyle(color: theme.primary)),
        label: 'Primary',
      ),
      for (var i = 0; i < state.subagents.length; i++)
        _subagentRow(cubit, theme, i),
    ];

    final Component body;
    if (overflowing) {
      _keepHighlightVisible();
      body = AppScrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }

    return SelectableHandler(
      selected: state.zoneActive,
      onKey: (event) => _handleKey(event, cubit),
      child: SizedBox(height: visibleRows.toDouble(), child: body),
    );
  }

  void _keepHighlightVisible() {
    if (!state.zoneActive) return;
    final row = state.highlightedSubagentIndex.toDouble();
    TerminalBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollController.ensureVisible(itemOffset: row, itemExtent: 1);
    });
  }

  bool _handleKey(KeyboardEvent event, ChatCubit cubit) {
    if (!state.zoneActive) return false;
    // Plain arrows browse the zone; Shift+arrows belong to chat-row selection.
    if (event.matches(LogicalKey.arrowUp, shift: false)) {
      cubit.moveSubagentUp();
      return true;
    }
    if (event.matches(LogicalKey.arrowDown, shift: false)) {
      cubit.moveSubagentDown();
      return true;
    }
    if (event.matches(LogicalKey.escape) && state.zoneHighlightsSubagent) {
      cubit.stopHighlightedSubagent();
      return true;
    }
    return false;
  }

  Component _subagentRow(ChatCubit cubit, AppThemeData theme, int index) {
    final subagent = state.subagents[index];
    final leading = switch (subagent.status) {
      // A live subagent uses the same inline spinner as the rest of the app.
      SubagentStatus.running => Row(
        children: [
          const Text(' '),
          InlineSpinner(color: theme.primary),
          const Text(' '),
        ],
      ),
      SubagentStatus.completed => Text(
        ' ✓ ',
        style: TextStyle(color: theme.success),
      ),
      SubagentStatus.failed => Text(
        ' ✗ ',
        style: TextStyle(color: theme.error),
      ),
    };
    return _row(
      cubit,
      theme,
      index: index + 1,
      leading: leading,
      label: subagent.title,
    );
  }

  Component _row(
    ChatCubit cubit,
    AppThemeData theme, {
    required int index,
    required Component leading,
    required String label,
  }) {
    final highlighted =
        state.zoneActive && state.highlightedSubagentIndex == index;
    return Hoverable(
      onTap: () => cubit.selectSubagentRow(index),
      builder: (context, {required hovered}) {
        final background = highlighted
            ? theme.surfaceAccent
            : hovered
            ? theme.hover
            : null;
        return Container(
          color: background,
          child: Row(
            children: [
              leading,
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlighted ? theme.onBackground : theme.onSurface,
                    fontWeight: highlighted
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
