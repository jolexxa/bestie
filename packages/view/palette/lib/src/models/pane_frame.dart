import 'dart:math';

import 'package:bestie_palette_view/src/fuzzy.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// One open pane in the palette's pane stack, with what the user has done in
/// it so far.
@model
final class PaneFrame {
  PaneFrame(this.pane);

  final Pane pane;

  String _query = '';
  PaneContent? _content;
  List<PaneSection>? _visibleSections;

  int selectedIndex = 0;

  /// The selected row's id, so the selection follows the row when the
  /// content reorders.
  String? selectedRowId;

  PaneStatus? status;

  /// Why the pane's last action or stream failed, shown in its error band.
  String? error;

  /// The action still running; further actions wait for it.
  PaneAction? pendingAction;

  String get query => _query;

  /// The latest listing; null until the first one arrives.
  PaneContent? get content => _content;

  /// The sections narrowed to the rows matching [query] when the palette
  /// does the filtering, keeping section and row order.
  List<PaneSection> get visibleSections =>
      _visibleSections ??= _narrowed(_content?.sections ?? const []);

  /// Every visible row in listing order.
  List<PaneRow> get visibleRows => [
    for (final section in visibleSections) ...section.rows,
  ];

  PaneRow? get selectedRow => visibleRows.elementAtOrNull(selectedIndex);

  /// Selects the visible row at [index], kept within the visible rows.
  void select(int index) {
    final rows = visibleRows;
    selectedIndex = index.clamp(0, max(0, rows.length - 1));
    selectedRowId = rows.elementAtOrNull(selectedIndex)?.id;
  }

  /// Lists [content], keeping the selected row selected wherever it moved,
  /// or the same position when it is gone.
  void show(PaneContent content) {
    _content = content;
    _visibleSections = null;
    final found = visibleRows.indexWhere((row) => row.id == selectedRowId);
    select(found < 0 ? selectedIndex : found);
  }

  /// Narrows to [query] with the selection back at the top.
  void search(String query) {
    _query = query;
    _visibleSections = null;
    selectedIndex = 0;
    selectedRowId = null;
  }

  List<PaneSection> _narrowed(List<PaneSection> sections) {
    if (pane.filter != PaneFilter.fuzzy || _query.isEmpty) return sections;
    final rows = [for (final section in sections) ...section.rows];
    final ranked = fuzzyRank(_query, [
      for (final row in rows) row.keywords,
    ], threshold: paletteMatchThreshold);
    final matched = {for (final index in ranked) rows[index]};
    return [
      for (final section in sections)
        if (section.rows.any(matched.contains))
          section.withRows([
            for (final row in section.rows)
              if (matched.contains(row)) row,
          ]),
    ];
  }
}
