import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/view/components/timeline_marker.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Renders the single compaction frontier marker between the
/// pre-frontier (compacted) and post-frontier (raw) transcript items.
///
/// Selecting it surfaces the rolling-memory text in the details pane.
@view
class CompactionMarkerView extends StatelessComponent {
  const CompactionMarkerView(
    this.marker, {
    this.selected = false,
    this.hovered = false,
    super.key,
  });

  final CompactionMarkerTimelineItem marker;
  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final label = marker.running
        ? ChatStrings.compactionInProgress(marker.tokensBefore)
        : ChatStrings.compactionResult(marker.tokensBefore);
    final fraction = marker.prefillFraction;
    return TimelineMarker(
      label: TextSpan(text: '◆ $label ◆'),
      selected: selected,
      hovered: hovered,
      body: fraction == null
          ? null
          : BlockProgressBar(
              fraction: fraction,
              color: theme.loading,
              track: theme.muted,
            ),
    );
  }
}
