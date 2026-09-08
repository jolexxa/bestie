import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_chat_view/src/state/models/chat_phase.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

@view
class ChatInputRow extends StatelessComponent {
  const ChatInputRow({
    required this.textController,
    required this.state,
    required this.onSubmitted,
    required this.onEnterZone,
    super.key,
  });

  /// Rows the text field takes.
  static const double height = 6;

  final TextEditingController textController;
  final ChatState state;
  final VoidCallback onSubmitted;

  /// Invoked when ↓ is pressed at the end of the text and subagents exist —
  /// hands pseudo-focus to the subagent zone.
  final VoidCallback onEnterZone;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '> ',
          style: TextStyle(color: theme.primary),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: TextField(
              controller: textController,
              focused: Provider.of<RouterContext>(
                context,
              ).focusFor(AppMode.chat),
              style: TextStyle(color: theme.onBackground),
              maxLines: 6,
              placeholder: _inputPlaceholder,
              placeholderStyle: TextStyle(color: theme.muted),
              onSubmitted: (_) => onSubmitted(),
              onKeyEvent: (event) {
                // ↓ at the end of the text (with subagents present) hands
                // pseudo-focus to the zone instead of moving the cursor.
                if (_shouldEnterZone(event)) {
                  onEnterZone();
                  return true;
                }
                // A selected rich timeline item — or the active zone.
                if (SelectionInputHost.of(context).tryHandle(event)) {
                  return true;
                }
                if (InputActions.dispatch(context, event)) return true;
                return false;
              },
            ),
          ),
        ),
      ],
    );
  }

  /// True when a bare ↓ should enter the subagent zone: subagents exist, the
  /// zone isn't already active, and the cursor sits at the end of the text.
  bool _shouldEnterZone(KeyboardEvent event) {
    if (state.zoneActive || state.subagents.isEmpty) return false;
    if (!event.matches(LogicalKey.arrowDown)) return false;
    final sel = textController.selection;
    return sel.isCollapsed && sel.extentOffset >= textController.text.length;
  }

  String get _inputPlaceholder {
    if (state.loading) return 'Connecting...';
    if (state.generating) return 'Generating...';
    if (state.phase == ChatPhase.compacting) return 'Compacting memory...';
    return 'Type a message...';
  }
}
