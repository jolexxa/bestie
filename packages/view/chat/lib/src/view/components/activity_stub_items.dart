import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/activity_stub_row.dart';
import 'package:bestie_chat_view/src/view/components/tool_label.dart';
import 'package:bestie_chat_view/src/view/details/activity_badge.dart';
import 'package:bestie_chat_view/src/view/details/detail_accent_theme.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The badge a row wears, resolved against the theme.
({String glyph, Color accent}) _badgeFor(
  TimelineItem item,
  AppThemeData theme,
) {
  final badge =
      ActivityBadge.fromTimelineItem(item) ??
      const ActivityBadge(glyph: '·', accent: DetailAccent.muted);
  return (glyph: badge.glyph, accent: badge.accent.resolve(theme));
}

/// An interpolated activity label, its literal text in [accent] and its
/// argument values dimmed.
///
/// One row, always. Flattening the argument's own line breaks is most of it,
/// but a command can be long enough to wrap on its own, and a stub that grows
/// with its argument is a list nobody can scan.
Component _labelRow(
  List<LabelSpan> spans, {
  required Color accent,
  required Color muted,
}) => LayoutBuilder(
  builder: (context, constraints) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final span in fitLabel(spans, constraints.maxWidth.floor()))
        Text(
          span.text,
          style: TextStyle(
            color: span.role == SpanRole.literal ? accent : muted,
          ),
        ),
    ],
  ),
);

/// A reasoning run as a one-line chat stub: `Thinking…` while live, else
/// `Thought for 1.2s`.
@view
class ReasoningStubItemView extends StatelessComponent {
  const ReasoningStubItemView(
    this.item, {
    this.selected = false,
    this.hovered = false,
    this.snippet,
    super.key,
  });

  final ReasoningStubTimelineItem item;
  final bool selected;
  final bool hovered;

  /// A one-line snippet of the latest reasoning block, shown beside `Thinking…`
  /// while the run is live.
  final String? snippet;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (:glyph, accent: color) = _badgeFor(item, theme);
    final ms = item.stat?.elapsedMs ?? 0;
    final snippetText = snippet;
    final text = item.running
        ? (snippetText != null && snippetText.isNotEmpty
              ? snippetText
              : 'Thinking…')
        : (ms > 0 ? 'Thought for ${ms.asDuration}' : 'Thought');
    final fraction = item.prefillFraction;
    return ActivityStubRow(
      running: item.running,
      accent: color,
      glyph: glyph,
      selected: selected,
      hovered: hovered,
      label: Text(text, style: TextStyle(color: color)),
      secondLine: fraction == null
          ? null
          : BlockProgressBar(
              fraction: fraction,
              color: theme.loading,
              track: theme.muted,
            ),
    );
  }
}

/// The label a row wears and whether it is still going — everything that
/// differs between a tool call, the job it left running, and that job's
/// report. Null for the rows that carry no interpolated label of their own.
({List<LabelSpan> spans, bool running})? _labelOf(TimelineItem item) =>
    switch (item) {
      ToolActivityTimelineItem() => (
        spans: item.labelSpans,
        running: item.running,
      ),
      BackgroundJobTimelineItem() => (
        spans: item.job.labelSpans,
        running: item.settled == null,
      ),
      JobReportTimelineItem() => (
        spans: item.report.labelSpans,
        running: false,
      ),
      _ => null,
    };

/// A tool call, a job outliving the call that started it, or that job's
/// settled report, as a one-line chat stub: a status badge and a label
/// interpolated from the template stamped on it.
///
/// One view for the three because they are one row — the same badge, the same
/// label, the same layout, and only the field the spans are read from telling
/// them apart. Splitting them was three copies of a row that has to stay
/// identical to read as a list.
@view
class ActivityStubItemView extends StatelessComponent {
  const ActivityStubItemView(
    this.item, {
    this.selected = false,
    this.hovered = false,
    super.key,
  });

  /// The row to draw. A kind that carries no label draws nothing.
  final TimelineItem item;

  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    final label = _labelOf(item);
    if (label == null) return const SizedBox.shrink();
    final theme = AppTheme.of(context);
    final (:glyph, :accent) = _badgeFor(item, theme);
    return ActivityStubRow(
      running: label.running,
      accent: accent,
      glyph: glyph,
      selected: selected,
      hovered: hovered,
      label: _labelRow(label.spans, accent: accent, muted: theme.muted),
    );
  }
}
