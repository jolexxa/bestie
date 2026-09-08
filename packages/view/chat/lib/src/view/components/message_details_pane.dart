import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/details/agent_shell_view.dart';
import 'package:bestie_chat_view/src/view/details/change_text.dart';
import 'package:bestie_chat_view/src/view/details/detail_accent_theme.dart';
import 'package:bestie_chat_view/src/view/details/detail_section_rule.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:bestie_chat_view/src/view/details/item_details_mapping.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart' hide MarkdownStyleSheet, MarkdownText;
import 'package:platform_repository/platform_repository.dart';

/// Columns the pane never shrinks below — room for a wrapped working directory
/// in the terminal plus the rails either side of it.
const int detailsPaneMinWidth = 26;

/// One face of the row under the selection cursor — either its `{ }` inputs or
/// its Details output, chosen by [tab]. Each face is a pinned tab in the
/// workspace, so the pane draws exactly one of them.

@view
class MessageDetailsPane extends StatefulComponent {
  const MessageDetailsPane({
    required this.selected,
    this.tab = DetailsTab.details,
    super.key,
  });

  /// The timeline item currently parked under the selection cursor.
  final TimelineItem? selected;

  /// Which face of [selected] to draw — its inputs or its output.
  final DetailsTab tab;

  @override
  State<MessageDetailsPane> createState() => _MessageDetailsPaneState();
}

class _MessageDetailsPaneState extends State<MessageDetailsPane>
    with RunningClock {
  /// The body's scroll. On the Details tab an item that is streaming text opens
  /// at its tail and follows it as it grows; anything else parks at the top.
  final AutoScrollController _controller = AutoScrollController();

  @override
  void initState() {
    super.initState();
    _reset();
    _syncClock();
  }

  @override
  void didUpdateComponent(MessageDetailsPane oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.selected?.id != oldComponent.selected?.id) {
      _reset();
    }
    _syncClock();
  }

  void _syncClock() => syncRunningClock(
    running: component.selected?.asItemDetails.live ?? false,
  );

  void _reset() {
    if (component.tab == DetailsTab.details && _streams(component.selected)) {
      _controller.enableAutoScroll();
    } else {
      _controller
        ..scrollToStart()
        ..disableAutoScroll();
    }
  }

  bool _streams(TimelineItem? item) =>
      item != null &&
      item.asItemDetails.content.any(
        (section) => section is TextSection && section.streaming,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    unawaited(
      RepositoryProvider.of<OSPlatformRepository>(
        context,
      ).copyToClipboard(text),
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final selected = component.selected;
    if (selected == null) return _nothingSelected(theme);
    final details = selected.asItemDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(details, theme),
        Expanded(
          child: switch (component.tab) {
            DetailsTab.properties => _propertiesBody(details, theme),
            DetailsTab.details => _detailsBody(details, theme),
          },
        ),
      ],
    );
  }

  Component _nothingSelected(AppThemeData theme) => Center(
    child: Column(
      children: [
        Text(
          'Pick a message to read it here.',
          style: TextStyle(color: theme.muted),
        ),
      ],
    ),
  );

  /// Badge, name, and the readings — the glance answer to "who is telling me
  /// this, what is it, and how did it go", above whichever tab is shown.
  Component _header(ItemDetails details, AppThemeData theme) {
    final accent = details.accent.resolve(theme);
    return Padding(
      padding: const EdgeInsets.only(
        left: detailRailInset,
        top: 1,
        bottom: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _provenanceLabel(details.provenance),
                  style: TextStyle(
                    color: _provenanceAccent(details.provenance).resolve(theme),
                  ),
                ),
                const TextSpan(text: ' '),
                if (details.glyph case final glyph?) ...[
                  TextSpan(
                    text: glyph,
                    style: TextStyle(color: accent),
                  ),
                  const TextSpan(text: ' '),
                ],
                TextSpan(
                  text: details.title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (details.subtitle case final subtitle?) ...[
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: subtitle,
                    style: TextStyle(color: theme.muted),
                  ),
                ],
              ],
            ),
          ),
          if (details.measurements.isNotEmpty)
            Text(
              [
                for (final m in details.measurements) m.displayAt(clock.now()),
              ].join('  '),
              style: TextStyle(color: theme.muted),
            ),
        ],
      ),
    );
  }

  /// The `{ }` tab: the inputs behind the row, drawn as scrolling fact tables.
  Component _propertiesBody(ItemDetails details, AppThemeData theme) {
    final rows = [
      for (final section in details.properties) _section(section, theme),
    ];
    return ScrollableListShell(
      controller: _controller,
      itemCount: rows.length,
      cacheExtent: 20,
      enableSelection: true,
      onSelectionCompleted: _copyToClipboard,
      showRailWhenEmpty: false,
      itemBuilder: (context, index) => rows[index],
    );
  }

  /// The Details tab: a full-pane terminal when the row ran a shell, else its
  /// output text (and any sources) flowing in a scroll.
  Component _detailsBody(ItemDetails details, AppThemeData theme) {
    final content = details.content;
    final first = content.isEmpty ? null : content.first;
    if (first is LiveSection) {
      final rest = <DetailSection>[
        ?first.fallback,
        for (final section in content)
          if (section is! LiveSection) section,
      ];
      // This LayoutBuilder is a relayout boundary that re-imposes the
      // pane's height on the shell.
      return LayoutBuilder(
        builder: (context, _) => AgentShellView(
          // The call id is the shell's address, so it is also the view's key.
          key: ValueKey(first.key),
          toolCallId: first.key,
          fallback: rest.isEmpty ? null : _flowing(rest, theme),
        ),
      );
    }
    return _flowing(content, theme);
  }

  /// A scroll of text/links rows that follows streaming text to its tail.
  Component _flowing(List<DetailSection> sections, AppThemeData theme) {
    final rows = [for (final section in sections) _section(section, theme)];
    return ScrollableListShell(
      controller: _controller,
      itemCount: rows.length,
      cacheExtent: 20,
      enableSelection: true,
      onSelectionCompleted: _copyToClipboard,
      showRailWhenEmpty: false,
      itemBuilder: (context, index) => rows[index],
    );
  }

  /// Every section is a stack of full-width rows with a blank line under it.
  Component _block(List<Component> children) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  /// Content set in from the rail its heading rule starts at.
  Component _railed(Component child) => Padding(
    padding: const EdgeInsets.only(left: detailRailInset),
    child: child,
  );

  Color _bodyColor(DetailAccent accent, AppThemeData theme) =>
      accent == DetailAccent.normal ? theme.muted : accent.resolve(theme);

  Component _section(
    DetailSection section,
    AppThemeData theme,
  ) => switch (section) {
    FactsSection(:final facts) => _block([
      DetailTable(
        rows: [
          for (final fact in facts)
            DetailRowData(
              fact.label,
              fact.value,
              color: _bodyColor(fact.accent, theme),
            ),
        ],
      ),
    ]),
    TextSection(:final text, :final label, :final accent, :final streaming) =>
      _block([
        if (label != null) DetailSectionRule(label),
        _railed(
          MarkdownView(
            text,
            theme: MarkdownTheme(
              paragraphStyle: TextStyle(color: _bodyColor(accent, theme)),
            ),
            highlightTheme: syntaxThemeFor(theme),
            streaming: streaming,
          ),
        ),
      ]),
    LinksSection(:final links, :final label) => _block([
      DetailSectionRule(label),
      for (final link in links)
        _railed(
          Row(
            children: [
              Expanded(
                child: Text(
                  link.title == null ? link.url : '${link.title} (${link.url})',
                  style: TextStyle(color: theme.muted),
                ),
              ),
            ],
          ),
        ),
    ]),
    final CreatedFileSection created => _block([
      DetailSectionRule(createdSummary(created)),
      _railed(
        CodeView(
          created.text,
          language: inferLanguageFromPath(created.path),
          theme: syntaxThemeFor(theme),
        ),
      ),
      if (created.truncated)
        _railed(
          Text('[file truncated]', style: TextStyle(color: theme.muted)),
        ),
    ]),
    final DiffSection diff => _block([
      DetailSectionRule(diffSummary(diff)),
      _railed(DiffView(unifiedDiff(diff), theme: syntaxThemeFor(theme))),
      if (diff.diff.truncated)
        _railed(
          Text('[diff truncated]', style: TextStyle(color: theme.muted)),
        ),
    ]),
    LiveSection() => const SizedBox.shrink(),
  };
}

String _provenanceLabel(Provenance provenance) => switch (provenance) {
  Provenance.you => 'you',
  Provenance.model => 'model',
  Provenance.tool => 'tool',
  Provenance.harness => 'harness',
};

DetailAccent _provenanceAccent(Provenance provenance) => switch (provenance) {
  Provenance.you => DetailAccent.success,
  Provenance.model => DetailAccent.emphasis,
  Provenance.tool => DetailAccent.running,
  Provenance.harness => DetailAccent.muted,
};
