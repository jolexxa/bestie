import 'package:bestie_palette_view/src/view/palette_list_parts.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// Cells between neighbouring table columns.
const double paneColumnGap = 2;

/// Cells a row's glyph and the space after it take.
const double paneGlyphWidth = 2;

/// The columns a section lays its rows out in; a single label column that
/// takes the whole line when the section is not a table.
List<PaneColumn> paneColumnsOf(PaneSection section) =>
    section.columns.isEmpty ? const [PaneColumn()] : section.columns;

/// Whether any row in [section] sets a glyph, so its column header indents
/// past the glyph column.
bool paneSectionHasGlyphs(PaneSection section) =>
    section.rows.any((row) => row.glyph != null);

/// One line of table cells, each in its column's width and alignment.
@view
class PaneCells extends StatelessComponent {
  const PaneCells({required this.columns, required this.cells, super.key});

  final List<PaneColumn> columns;

  /// The spans for each column in order; missing cells stay blank.
  final List<List<PaneSpan>> cells;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          if (index > 0) const SizedBox(width: paneColumnGap),
          _cell(
            theme,
            columns[index],
            index < cells.length ? cells[index] : const [],
          ),
        ],
        if (columns.every((column) => column.width != null))
          Expanded(child: const SizedBox()),
      ],
    );
  }

  Component _cell(AppThemeData theme, PaneColumn column, List<PaneSpan> spans) {
    final line = SpanLine(paneSpans(theme, _aligned(column, spans)));
    return switch (column.width) {
      null => Expanded(child: line),
      final int width => SizedBox(width: width.toDouble(), child: line),
    };
  }

  List<PaneSpan> _aligned(PaneColumn column, List<PaneSpan> spans) =>
      switch (column) {
        PaneColumn(align: PaneAlign.end, :final int width) => [
          PaneSpan(' ' * (width - paneSpansWidth(spans)).clamp(0, width)),
          ...spans,
        ],
        PaneColumn() => spans,
      };
}

/// The muted column titles over a table section, lined up with its rows.
@view
class PaneColumnsHeader extends StatelessComponent {
  const PaneColumnsHeader(this.section, {super.key});

  final PaneSection section;

  @override
  Component build(BuildContext context) {
    final columns = paneColumnsOf(section);
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          SizedBox(
            width:
                PaletteListRow.gutter +
                (paneSectionHasGlyphs(section) ? paneGlyphWidth : 0),
          ),
          Expanded(
            child: PaneCells(
              columns: columns,
              cells: [
                for (final column in columns)
                  [PaneSpan(column.title, PaneTone.muted)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A line of a section's notes, in the list's gutter alignment; blank when
/// the note has no spans.
@view
class PaneNoteLine extends StatelessComponent {
  const PaneNoteLine(this.note, {super.key});

  final PaneNote note;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: Row(
      children: [
        const SizedBox(width: PaletteListRow.gutter),
        Expanded(child: SpanLine(paneSpans(AppTheme.of(context), note.spans))),
      ],
    ),
  );
}

/// A pane row: cursor, glyph, label or table cells and trailing text on the
/// first line, the detail under it, then the progress bar when it has one.
@view
class PaneRowView extends StatelessComponent {
  const PaneRowView({
    required this.row,
    required this.section,
    required this.selected,
    required this.hovered,
    super.key,
  });

  final PaneRow row;
  final PaneSection section;
  final bool selected;
  final bool hovered;

  /// Cells the bar of a row's progress line spans.
  static const int barWidth = 46;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final active = selected || hovered;
    final fill = switch (row.tint) {
      PaneTint.primary =>
        active ? theme.primaryTintSelected : theme.primaryTint,
      PaneTint.none => active ? theme.surfaceAccent : null,
    };
    final labelTone = selected ? PaneTone.emphasis : row.labelTone;
    return PaletteListRow(
      selected: selected,
      fill: fill,
      leading: switch (row.glyph) {
        null => null,
        final String glyph => SizedBox(
          width: paneGlyphWidth,
          child: Text(glyph, style: paneToneStyle(theme, row.glyphTone)),
        ),
      },
      leadingWidth: paneGlyphWidth,
      title: PaneCells(
        columns: paneColumnsOf(section),
        cells: [
          [PaneSpan(row.label, labelTone)],
          ...row.cells,
        ],
      ),
      trailing: row.trailing.isEmpty
          ? null
          : SpanLine(paneSpans(theme, row.trailing)),
      detail: row.detail.isEmpty
          ? null
          : SpanLine(paneSpans(theme, row.detail)),
      footer: switch (row.progress) {
        null => null,
        final PaneProgress progress => PaneProgressBar(
          progress: progress,
          barWidth: barWidth,
        ),
      },
    );
  }
}

/// A progress bar and its caption: a filled bar for a fraction, a spinner
/// for work with no measurable end.
@view
class PaneProgressBar extends StatelessComponent {
  const PaneProgressBar({
    required this.progress,
    required this.barWidth,
    super.key,
  });

  final PaneProgress progress;
  final int barWidth;

  /// The progress's label, or the percentage done for a fraction without
  /// one.
  static String captionOf(PaneProgress progress) => switch (progress) {
    PaneFraction(:final label?) || PaneIndeterminate(:final label?) => label,
    PaneFraction(:final clamped) => '${(clamped * 100).round()}%',
    PaneIndeterminate() => '',
  };

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final caption = Text(
      switch (progress) {
        PaneFraction() => '  ${captionOf(progress)}',
        PaneIndeterminate() => ' ${captionOf(progress)}',
      },
      style: TextStyle(color: theme.muted),
    );
    return SizedBox(
      height: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (progress) {
            PaneFraction(:final clamped) => SizedBox(
              width: barWidth.toDouble(),
              child: BlockProgressBar(
                fraction: clamped,
                color: theme.loading,
                track: theme.muted,
              ),
            ),
            PaneIndeterminate() => InlineSpinner(color: theme.loading),
          },
          caption,
        ],
      ),
    );
  }
}

/// The pane's status line: glyph, text, an optional bar, and right-aligned
/// trailing text, with the [actions] it offers on a line of their own.
@view
class PaneStatusBand extends StatelessComponent {
  const PaneStatusBand(this.status, {this.actions = const [], super.key});

  final PaneStatus status;

  final List<PaneAction> actions;

  /// Cells the band's progress bar spans.
  static const int barWidth = 28;

  /// Cells the action line is indented by, so it lines up with the text
  /// after the glyph.
  static const double actionIndent = 2;

  @override
  Component build(BuildContext context) {
    final line = _line(AppTheme.of(context));
    if (actions.isEmpty) return line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        Padding(
          padding: const EdgeInsets.only(left: actionIndent),
          child: PaneHintLine([
            for (final action in actions) PaneHint.of(action),
          ]),
        ),
      ],
    );
  }

  Component _line(AppThemeData theme) {
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (status.glyph case final String glyph)
                  Text(
                    '$glyph ',
                    style: paneToneStyle(theme, status.glyphTone),
                  ),
                Flexible(child: EllipsizedSpanLine(status.spans)),
                if (status.progress case final PaneProgress progress) ...[
                  const Text('  '),
                  PaneProgressBar(progress: progress, barWidth: barWidth),
                ],
              ],
            ),
          ),
          SpanLine(paneSpans(theme, status.trailing)),
        ],
      ),
    );
  }
}

/// The line naming the action still running, with a spinner.
@view
class PanePendingBand extends StatelessComponent {
  const PanePendingBand(this.action, {super.key});

  final PaneAction action;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          InlineSpinner(color: theme.loading),
          Text(' ${action.label}…', style: TextStyle(color: theme.muted)),
        ],
      ),
    );
  }
}

/// One `[key] Label` pair in the pane footer.
@model
@immutable
final class PaneHint {
  const PaneHint(this.key, this.label, {this.danger = false});

  /// The hint for [action]: `↵` for Enter, else its letter.
  PaneHint.of(PaneAction action)
    : key = switch (action.key) {
        PrimaryKey() => '↵',
        CharKey(:final char) => char,
      },
      label = action.label,
      danger = action.danger;

  final String key;
  final String label;
  final bool danger;

  /// Cells the pair takes up on screen.
  int get width => UnicodeWidth.stringWidth('[$key] $label');
}

/// The pane footer: as many `[key] Label` hints as fit on one line.
@view
class PaneHints extends StatelessComponent {
  const PaneHints(this.hints, {super.key});

  final List<PaneHint> hints;

  @override
  Component build(BuildContext context) => Container(
    color: AppTheme.of(context).surface,
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: PaneHintLine(hints),
  );
}

/// As many `[key] Label` hints as fit on one line.
@view
class PaneHintLine extends StatelessComponent {
  const PaneHintLine(this.hints, {super.key});

  final List<PaneHint> hints;

  static const String gap = '   ';

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final kept = fitting(hints, constraints.maxWidth.toInt());
          return SpanLine(
            TextSpan(
              children: [
                for (var index = 0; index < kept.length; index++) ...[
                  if (index > 0) const TextSpan(text: gap),
                  TextSpan(
                    text: '[${kept[index].key}]',
                    style: TextStyle(color: theme.secondary),
                  ),
                  TextSpan(
                    text: ' ${kept[index].label}',
                    style: TextStyle(
                      color: kept[index].danger ? theme.error : theme.muted,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// The leading [hints] that fit in [width] cells.
  static List<PaneHint> fitting(List<PaneHint> hints, int width) {
    final kept = <PaneHint>[];
    var used = 0;
    for (final hint in hints) {
      final needed = hint.width + (kept.isEmpty ? 0 : gap.length);
      if (used + needed > width) break;
      kept.add(hint);
      used += needed;
    }
    return kept;
  }
}
