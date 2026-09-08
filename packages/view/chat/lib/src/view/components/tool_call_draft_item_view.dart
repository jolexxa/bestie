import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/activity_stub_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The tool call the model is still writing, as the tail of the chat list:
/// dots flowing across the row where the call's own row will land once it
/// is whole.
///
/// It borrows the activity stub's row so it sits on the same margin and in
/// the same gutter as the stub it replaces; the dots are the whole label, and
/// the leading slot stays a quiet dot rather than a second spinner.
@view
class ToolCallDraftItemView extends StatelessComponent {
  const ToolCallDraftItemView(
    this.item, {
    this.selected = false,
    this.hovered = false,
    super.key,
  });

  final ToolCallDraftTimelineItem item;
  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return ActivityStubRow(
      running: false,
      accent: theme.muted,
      glyph: '·',
      selected: selected,
      hovered: hovered,
      label: FlowingDots(color: theme.loading),
    );
  }
}
