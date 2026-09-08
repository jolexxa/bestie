import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/details/activity_badge.dart';
import 'package:bestie_chat_view/src/view/details/change_text.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show CreatedFileContribution, DiffContribution, SourceContribution;

/// Builds the details view of a timeline item. Pure — no theme, repositories,
/// or clock — through fixed slots, so a new kind of row inherits the layout.
extension TimelineItemDetails on TimelineItem {
  ItemDetails get asItemDetails {
    final badge = ActivityBadge.fromTimelineItem(this);
    return switch (this) {
      final MessageTimelineItem item => _message(item),
      final ReasoningStubTimelineItem item => _reasoning(item, badge),
      final ToolCallDraftTimelineItem item => _toolCallDraft(item, badge),
      final ToolActivityTimelineItem item => _tool(item, badge),
      final BackgroundJobTimelineItem item => _backgroundJob(item, badge),
      final JobReportTimelineItem item => _jobReport(item, badge),
      final CompactionMarkerTimelineItem item => _compaction(item),
      final ModelCardTimelineItem item => _modelCard(item),
      final NoticeTimelineItem item => _notice(item),
    };
  }
}

/// Display name for a chat row's sender.
String senderLabelFor(Role role) => switch (role) {
  Role.user => 'You',
  Role.assistant => 'Bestie',
  Role.system || Role.tool => 'System',
};

DetailAccent _roleAccent(Role role) => switch (role) {
  Role.user => DetailAccent.success,
  Role.assistant => DetailAccent.emphasis,
  Role.system || Role.tool => DetailAccent.emphasis,
};

/// Who a message came from.
Provenance _messageProvenance(Role role) => switch (role) {
  Role.user => Provenance.you,
  Role.assistant => Provenance.model,
  Role.tool => Provenance.tool,
  Role.system => Provenance.harness,
};

/// The clock reading every item gets.
List<Measurement> _at(DateTime timestamp) => [
  Measurement(value: timestamp.as12HourTime),
];

/// Clock, then what the run cost — both slots declared empty until known, so
/// the strip keeps its final width from the first frame. While [running] the
/// duration slot counts up from when the run began.
List<Measurement> _atWithCost(
  DateTime timestamp,
  BlockStat? stat, {
  required bool running,
}) => [
  ..._at(timestamp),
  if (stat != null) ...[
    if (running)
      Measurement.running(stat.startedAt)
    else
      Measurement(
        value: stat.elapsedMs > 0 ? stat.elapsedMs.asDuration : null,
      ),
    Measurement(value: stat.tokenCount?.toString(), unit: 'tok'),
    Measurement(
      value: stat.tokensPerSecond?.toStringAsFixed(1),
      unit: 'tok/s',
    ),
  ],
];

ItemDetails _message(MessageTimelineItem item) {
  final stat = item.blocks.map((b) => b.stat).fold<BlockStat?>(null, _merge);
  final text = item.text;
  return ItemDetails(
    title: senderLabelFor(item.role),
    accent: _roleAccent(item.role),
    provenance: _messageProvenance(item.role),
    measurements: _atWithCost(item.timestamp, stat, running: item.running),
    content: [
      // The list already renders this as markdown; what the pane can add is
      // the source behind it.
      if (text.isNotEmpty)
        TextSection(text, label: 'Source', streaming: item.running),
    ],
  );
}

ItemDetails _reasoning(ReasoningStubTimelineItem item, ActivityBadge? badge) =>
    ItemDetails(
      title: 'Reasoning',
      accent: badge?.accent ?? DetailAccent.muted,
      provenance: Provenance.model,
      glyph: badge?.glyph,
      measurements: _atWithCost(
        item.timestamp,
        item.stat,
        running: item.running,
      ),
      content: [TextSection(item.text, streaming: item.running)],
    );

ItemDetails _toolCallDraft(
  ToolCallDraftTimelineItem item,
  ActivityBadge? badge,
) => ItemDetails(
  title: 'Tool call',
  accent: badge?.accent ?? DetailAccent.running,
  provenance: Provenance.model,
  glyph: badge?.glyph,
  subtitle: 'Still being written',
  measurements: _at(item.timestamp),
);

ItemDetails _tool(ToolActivityTimelineItem item, ActivityBadge? badge) {
  final result = item.result;
  return ItemDetails(
    title: item.toolCall.name,
    accent: badge?.accent ?? DetailAccent.normal,
    provenance: Provenance.tool,
    glyph: badge?.glyph,
    subtitle: switch (result) {
      ToolCallCanceled() => 'Interrupted',
      ToolCallFailed() => 'Failed',
      ToolCallSucceeded() => _changeSummary(result),
      null => null,
    },
    measurements: [..._at(item.timestamp), _elapsed(result)],
    content: [
      LiveSection(
        item.toolCall.id,
        fallback: switch (result) {
          ToolCallFailed(:final modelText) => TextSection(
            modelText,
            label: 'Error',
            accent: DetailAccent.error,
          ),
          ToolCallCanceled(:final modelText) => TextSection(
            modelText,
            label: 'Interrupted',
          ),
          ToolCallSucceeded(:final modelText) => TextSection(
            modelText,
            label: 'Output',
          ),
          null => null,
        },
      ),
      ..._created(result),
      ..._diffs(result),
      ?_sources(result),
    ],
    properties: [?_arguments(item.toolCall.arguments)],
  );
}

ItemDetails _backgroundJob(
  BackgroundJobTimelineItem item,
  ActivityBadge? badge,
) {
  final settled = item.settled;
  return ItemDetails(
    title: item.job.toolName,
    accent: badge?.accent ?? DetailAccent.running,
    provenance: Provenance.tool,
    glyph: badge?.glyph,
    subtitle: settled == null ? 'Running in the background' : null,
    measurements: _at(item.timestamp),
    content: [
      LiveSection(
        item.job.callId,
        fallback: settled == null
            ? const TextSection('Still running.')
            : _report(settled.body, succeeded: settled.succeeded),
      ),
    ],
    properties: [?_arguments(item.job.labelArguments)],
  );
}

ItemDetails _jobReport(JobReportTimelineItem item, ActivityBadge? badge) {
  final report = item.report;
  return ItemDetails(
    title: report.toolName,
    accent: badge?.accent ?? DetailAccent.normal,
    provenance: Provenance.harness,
    glyph: badge?.glyph,
    subtitle: report.succeeded ? null : 'Failed',
    measurements: _at(item.timestamp),
    content: [_report(report.body, succeeded: report.succeeded)],
    properties: [?_arguments(report.labelArguments)],
  );
}

/// The report body a settled job and its later report both show, muted when it
/// went well and flagged when it did not.
TextSection _report(String body, {required bool succeeded}) => TextSection(
  body,
  label: 'Report',
  accent: succeeded ? DetailAccent.muted : DetailAccent.error,
);

/// What the call was asked to do, flattened so a nested payload reads as a
/// table rather than one key with an unreadable value.
FactsSection? _arguments(Map<String, Object?> arguments) {
  if (arguments.isEmpty) return null;
  final facts = <DetailFact>[];
  _flatten(arguments, '', facts);
  return facts.isEmpty ? null : FactsSection(facts);
}

/// Walks [value] into a flat list of facts: a nested map dots its keys onto the
/// path, a list indexes its items, and a leaf lands as one labelled row.
void _flatten(Object? value, String label, List<DetailFact> into) {
  switch (value) {
    case final Map<Object?, Object?> map when map.isNotEmpty:
      map.forEach((key, child) => _flatten(child, _join(label, '$key'), into));
    case final Iterable<Object?> items when items.isNotEmpty:
      for (final (index, item) in items.indexed) {
        _flatten(item, '$label[$index]', into);
      }
    default:
      into.add(DetailFact(label, _leafText(value)));
  }
}

/// Joins a key onto a dotted path, dropping the dot at the root.
String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

/// A single argument value drawn for a reader — [Map]s and [Iterable]s never
/// reach here, so an empty one prints as itself rather than vanishing.
String _leafText(Object? value) => switch (value) {
  null => '',
  final String text => text,
  final Map<Object?, Object?> _ => '{}',
  final Iterable<Object?> _ => '[]',
  _ => '$value',
};

ItemDetails _compaction(CompactionMarkerTimelineItem item) => ItemDetails(
  title: 'Compaction memory',
  accent: DetailAccent.emphasis,
  provenance: Provenance.harness,
  measurements: _at(item.timestamp),
  properties: [
    FactsSection([
      DetailFact('Folded', '${item.tokensBefore.withCommas} tok'),
    ]),
  ],
  content: [
    if (item.summaryReasoning.isNotEmpty)
      TextSection(
        item.summaryReasoning,
        label: 'Reasoning',
        streaming: item.running,
      ),
    TextSection(item.summary, label: 'Summary', streaming: item.running),
  ],
);

ItemDetails _modelCard(ModelCardTimelineItem item) {
  final card = item.card;
  return ItemDetails(
    title: card.displayName,
    accent: DetailAccent.emphasis,
    provenance: Provenance.harness,
    subtitle: 'Model',
    measurements: _at(item.timestamp),
    properties: [
      FactsSection([
        DetailFact('Model', card.modelId),
        DetailFact('Provider', card.provider),
        DetailFact('Context', card.contextSize.withCommas),
        ?switch (card.error) {
          final error? => DetailFact(
            'Error',
            error,
            accent: DetailAccent.error,
          ),
          _ => null,
        },
      ]),
    ],
  );
}

ItemDetails _notice(NoticeTimelineItem item) => ItemDetails(
  title: 'System',
  accent: DetailAccent.emphasis,
  provenance: Provenance.harness,
  measurements: _at(item.timestamp),
  content: [TextSection(item.text)],
);

/// Timings belong on the measurement strip, not glued onto the value they
/// describe. Empty until the call lands, and the slot is drawn either way.
Measurement _elapsed(ToolCallResponse? result) =>
    Measurement(value: result?.elapsedMs?.asDuration);

LinksSection? _sources(ToolCallResponse? result) {
  if (result is! ToolCallSucceeded) return null;
  final seen = <String>{};
  final links = [
    for (final contribution in result.contributions)
      if (contribution is SourceContribution && seen.add(contribution.url))
        DetailLink(url: contribution.url, title: contribution.title),
  ];
  return links.isEmpty ? null : LinksSection(links);
}

/// Every file the call made, each as its text.
List<CreatedFileSection> _created(ToolCallResponse? result) => [
  if (result is ToolCallSucceeded)
    for (final contribution in result.contributions)
      if (contribution is CreatedFileContribution)
        CreatedFileSection(
          contribution.text,
          path: contribution.path,
          lines: contribution.lines,
          truncated: contribution.truncated,
        ),
];

/// Every file the call changed, each as its own diff.
List<DiffSection> _diffs(ToolCallResponse? result) => [
  if (result is ToolCallSucceeded)
    for (final contribution in result.contributions)
      if (contribution is DiffContribution)
        DiffSection(contribution.diff, path: contribution.path),
];

/// What a call that changed files did to them, or nothing for one that did
/// not.
String? _changeSummary(ToolCallSucceeded result) {
  final summaries = [
    ..._created(result).map(createdSummary),
    ..._diffs(result).map(diffSummary),
  ];
  return summaries.isEmpty ? null : summaries.join(', ');
}

BlockStat? _merge(BlockStat? a, BlockStat? b) {
  if (a == null) return b;
  if (b == null) return a;
  final tokens = (a.tokenCount ?? 0) + (b.tokenCount ?? 0);
  return BlockStat(
    startedAt: a.startedAt.isBefore(b.startedAt) ? a.startedAt : b.startedAt,
    endedAt: a.endedAt.isAfter(b.endedAt) ? a.endedAt : b.endedAt,
    tokenCount: tokens > 0 ? tokens : null,
  );
}
