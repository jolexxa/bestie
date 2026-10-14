import 'package:command_protocol/src/pane_action.dart';
import 'package:command_protocol/src/pane_tone.dart';
import 'package:meta/meta.dart';

/// Everything a pane lists at one moment, section by section.
@immutable
final class PaneContent {
  const PaneContent(this.sections);

  const PaneContent.empty() : sections = const [];

  final List<PaneSection> sections;

  /// Every row in listing order.
  List<PaneRow> get rows => [
    for (final section in sections) ...section.rows,
  ];
}

/// A run of rows under an optional header.
@immutable
final class PaneSection {
  const PaneSection({
    required this.rows,
    this.title,
    this.count,
    this.columns = const [],
    this.notes = const [],
  });

  /// The group header; no header when null.
  final String? title;

  /// A number set beside [title], e.g. how many downloads are running.
  final int? count;

  /// Lays the section out as a table: the first column holds each row's
  /// label and the rest hold its cells, in order. Empty for plain rows.
  final List<PaneColumn> columns;

  /// Lines of text set above the rows, such as an explanation or an empty
  /// state; they can't be selected.
  final List<PaneNote> notes;

  final List<PaneRow> rows;

  /// This section holding [rows] in place of its own.
  PaneSection withRows(List<PaneRow> rows) => PaneSection(
    title: title,
    count: count,
    columns: columns,
    notes: notes,
    rows: rows,
  );
}

/// One line of text in a section that can't be selected; blank when it has
/// no spans.
@immutable
final class PaneNote {
  const PaneNote(this.spans);

  const PaneNote.blank() : spans = const [];

  final List<PaneSpan> spans;
}

/// Which side of its column a table cell hugs.
enum PaneAlign { start, end }

/// One column of a table section.
@immutable
final class PaneColumn {
  const PaneColumn({this.title = '', this.width, this.align = PaneAlign.start});

  /// The column header; a section draws a header line when any column has
  /// one.
  final String title;

  /// Cells the column spans; null takes whatever room is left.
  final int? width;

  final PaneAlign align;
}

/// How a row stands out from the rest.
enum PaneTint {
  /// No fill.
  none,

  /// The fill the palette uses for app-wide actions.
  primary,
}

/// One selectable entry in a pane.
@immutable
final class PaneRow {
  const PaneRow({
    required this.id,
    required this.label,
    this.glyph,
    this.glyphTone = PaneTone.secondary,
    this.labelTone = PaneTone.plain,
    this.cells = const [],
    this.trailing = const [],
    this.detail = const [],
    this.progress,
    this.actions = const [],
    this.tint = PaneTint.none,
    String? keywords,
  }) : keywords = keywords ?? label;

  /// Stable identity across content updates.
  final String id;

  /// One-cell symbol set before [label]; no glyph column when null.
  final String? glyph;
  final PaneTone glyphTone;

  final String label;
  final PaneTone labelTone;

  /// The row's values for its section's table columns after the first.
  final List<List<PaneSpan>> cells;

  /// Right-aligned text on the row's first line.
  final List<PaneSpan> trailing;

  /// The row's second line; the row is a single line when empty.
  final List<PaneSpan> detail;

  /// A bar drawn on a line of its own under the row.
  final PaneProgress? progress;

  final List<PaneAction> actions;

  final PaneTint tint;

  /// What a fuzzy filter matches typed queries against; the label alone
  /// unless the pane wants more to be findable.
  final String keywords;

  /// The action [key] runs on this row, if any.
  PaneAction? actionFor(PaneKey key) => actions.forKey(key);
}

/// How far along a piece of work is.
@immutable
sealed class PaneProgress {
  const PaneProgress({this.label});

  /// Text set after the bar; the palette's own caption when null.
  final String? label;
}

/// Progress as a share of the whole, from 0 to 1.
final class PaneFraction extends PaneProgress {
  const PaneFraction(this.value, {super.label});

  final double value;

  /// [value] kept between 0 and 1.
  double get clamped => value.clamp(0, 1).toDouble();
}

/// Progress with no measurable end.
final class PaneIndeterminate extends PaneProgress {
  const PaneIndeterminate({super.label});
}

/// The band under a pane's query field: one line, plus a line of key hints
/// when it offers [actions].
@immutable
final class PaneStatus {
  const PaneStatus({
    required this.spans,
    this.glyph,
    this.glyphTone = PaneTone.muted,
    this.trailing = const [],
    this.progress,
    this.actions = const [],
  });

  /// One-cell symbol leading the band; none when null.
  final String? glyph;
  final PaneTone glyphTone;

  final List<PaneSpan> spans;

  /// Right-aligned text at the end of the band.
  final List<PaneSpan> trailing;

  /// A bar drawn after [spans].
  final PaneProgress? progress;

  /// Letter-key actions on what the band reports, such as retrying a
  /// failure. They run while the list has the keyboard, unless the selected
  /// row has an action for the same key.
  final List<PaneAction> actions;

  /// The action [key] runs on the band, if any.
  PaneAction? actionFor(PaneKey key) => actions.forKey(key);
}
