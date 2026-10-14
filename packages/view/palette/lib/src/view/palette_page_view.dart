import 'dart:math';

import 'package:bestie_palette_view/src/models/indexed_option.dart';
import 'package:bestie_palette_view/src/models/palette_row.dart';
import 'package:bestie_palette_view/src/models/pane_frame.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:bestie_palette_view/src/state/palette_logic.dart';
import 'package:bestie_palette_view/src/view/palette_list_parts.dart';
import 'package:bestie_palette_view/src/view/pane_parts.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Centered command palette overlay.
@view
class PalettePageView extends StatefulComponent {
  const PalettePageView({super.key});

  @override
  State<PalettePageView> createState() => _PalettePageViewState();
}

class _PalettePageViewState extends State<PalettePageView> {
  late final PaletteCubit _cubit;
  final ScrollController _listController = ScrollController();
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _paneQueryController = TextEditingController();
  Param? _lastParam;
  PaneFrame? _lastFrame;

  /// The card's width while a pane shows, when the terminal has room.
  static const int paneWidth = 80;

  /// The card's width for the command list, and for panes on narrow
  /// terminals.
  static const int commandWidth = 64;

  static const int cardHeight = 29;

  @override
  void initState() {
    super.initState();
    _cubit = BlocProvider.of<PaletteCubit>(context, listen: false)
      ..onCursorMoved = _onCursorMoved;
  }

  @override
  void dispose() {
    _cubit.onCursorMoved = null;
    _listController.dispose();
    _queryController.dispose();
    _valueController.dispose();
    _paneQueryController.dispose();
    super.dispose();
  }

  /// Scrolls the moved-to row into view.
  void _onCursorMoved(int index) {
    final entry = switch (_cubit.state) {
      final BrowsingState state => index + _headersBefore(state.rows, index),
      final ViewingPaneState state => _paneEntries(
        state.visibleSections,
      ).indexWhere((entry) => entry is _PaneRowEntry && entry.index == index),
      _ => index,
    };
    _listController.ensureIndexVisible(index: entry);
  }

  int _headersBefore(List<PaletteRow> rows, int index) {
    if (rows.isEmpty) return 0;
    final upTo = rows.take(index + 1);
    return {for (final row in upTo) row.command.group}.length;
  }

  /// The browse list as drawn.
  List<_BrowseEntry> _entries(List<PaletteRow> rows) {
    final entries = <_BrowseEntry>[];
    for (var index = 0; index < rows.length; index++) {
      final group = rows[index].command.group;
      final opensGroup = index == 0 || rows[index - 1].command.group != group;
      if (opensGroup) entries.add(_GroupHeaderEntry(group));
      entries.add(_CommandEntry(index));
    }
    return entries;
  }

  /// The pane list as drawn: each section's header, notes and column titles,
  /// then its rows, numbered across sections.
  List<_PaneEntry> _paneEntries(List<PaneSection> sections) {
    final entries = <_PaneEntry>[];
    var index = 0;
    for (final section in sections) {
      if (section.title case final String title) {
        entries.add(_PaneHeaderEntry(title, section.count));
      }
      entries.addAll(section.notes.map(_PaneNoteEntry.new));
      if (section.columns.any((column) => column.title.isNotEmpty)) {
        entries.add(_PaneColumnsEntry(section));
      }
      for (final row in section.rows) {
        entries.add(_PaneRowEntry(section, row, index++));
      }
    }
    return entries;
  }

  /// Clears stale text when the palette closes or the collected param
  /// changes, so each step starts from an empty field, and shows each pane's
  /// own query as it comes into view.
  void _onStateChanged(BuildContext _, PaletteState state) {
    if (state is ClosedState && _queryController.text.isNotEmpty) {
      _queryController.clear();
    }
    final param = state is CollectingState ? state.currentParam : null;
    if (!identical(param, _lastParam)) {
      _lastParam = param;
      _valueController.clear();
    }
    final frame = state is ViewingPaneState ? state.frame : null;
    if (!identical(frame, _lastFrame)) {
      _lastFrame = frame;
      _paneQueryController.text = frame?.query ?? '';
    }
  }

  /// Moves the selection to row [index] — the click equivalent of arrowing.
  void _selectRow(int index, int current) {
    if (index != current) _cubit.moveSelection(index - current);
  }

  @override
  Component build(BuildContext context) {
    return BlocListener<PaletteCubit, PaletteState>(
      listener: _onStateChanged,
      child: BlocBuilder<PaletteCubit, PaletteState>(
        builder: (context, state) {
          final theme = AppTheme.of(context);
          return switch (state) {
            ClosedState() => const SizedBox(),
            final BrowsingState browsing => _buildBrowsing(browsing, theme),
            final CollectingState collecting => _buildCollecting(
              collecting,
              theme,
            ),
            final InvokingState invoking => _buildInvoking(invoking, theme),
            final ViewingPaneState viewing => _buildPane(viewing, theme),
          };
        },
      ),
    );
  }

  // ── Browsing ────────────────────────────────────────────

  Component _buildBrowsing(BrowsingState state, AppThemeData theme) {
    final rows = state.rows;
    final entries = _entries(rows);
    return InputActions(
      actions: [
        KeyAction(
          label: 'Nav',
          key: LogicalKey.arrowUp,
          footerOverride: '[▴/▾] Nav',
          onActivate: () => _cubit.moveSelection(-1),
        ),
        KeyAction(
          label: 'Nav',
          key: LogicalKey.arrowDown,
          visible: false,
          onActivate: () => _cubit.moveSelection(1),
        ),
        KeyAction(
          label: 'Run',
          key: LogicalKey.enter,
          onActivate: _cubit.activate,
        ),
        KeyAction(
          label: 'Close',
          key: LogicalKey.escape,
          onActivate: _cubit.requestClose,
        ),
      ],
      child: Builder(
        builder: (ctx) => _card(
          children: [
            _header(
              theme,
              children: [
                TextField(
                  controller: _queryController,
                  focused: true,
                  placeholder: 'Type a command…',
                  onChanged: _cubit.queryChanged,
                  onKeyEvent: (event) => InputActions.dispatch(ctx, event),
                ),
                if (state.error case final String error)
                  SizedBox(
                    height: 1,
                    child: Text(
                      '⚠ $error',
                      style: TextStyle(color: theme.error),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No matching commands.',
                        style: TextStyle(color: theme.muted),
                      ),
                    )
                  : ScrollableListShell(
                      controller: _listController,
                      itemCount: entries.length,
                      itemBuilder: (_, index) => switch (entries[index]) {
                        _GroupHeaderEntry(:final group) => PaletteGroupHeader(
                          group,
                        ),
                        _CommandEntry(:final index) => Hoverable(
                          onTap: () => _selectRow(index, state.selectedIndex),
                          onActivate: () {
                            _selectRow(index, state.selectedIndex);
                            _cubit.activate();
                          },
                          builder: (context, {required hovered}) => _CommandRow(
                            row: rows[index],
                            selected: index == state.selectedIndex,
                            hovered: hovered,
                          ),
                        ),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Collecting ──────────────────────────────────────────

  Component _buildCollecting(CollectingState state, AppThemeData theme) {
    final param = state.currentParam!;
    final title = state.activeCommand!.title;
    return InputActions(
      actions: [
        KeyAction(
          label: 'Back',
          key: LogicalKey.escape,
          onActivate: _cubit.back,
        ),
        ...switch (param) {
          TextParam() || NumberParam() => const <KeyAction>[],
          ConfirmParam() => [
            KeyAction(
              label: 'Confirm',
              key: LogicalKey.enter,
              onActivate: _cubit.submitChoice,
            ),
          ],
          ChoiceParam() || MultiChoiceParam() => [
            KeyAction(
              label: 'Nav',
              key: LogicalKey.arrowUp,
              footerOverride: '[▴/▾] Nav',
              onActivate: () => _cubit.moveSelection(-1),
            ),
            KeyAction(
              label: 'Nav',
              key: LogicalKey.arrowDown,
              visible: false,
              onActivate: () => _cubit.moveSelection(1),
            ),
            KeyAction(
              label: 'Select',
              key: LogicalKey.enter,
              onActivate: _cubit.submitChoice,
            ),
            if (param is MultiChoiceParam)
              KeyAction(
                label: 'Toggle',
                key: LogicalKey.space,
                onActivate: _cubit.toggleOption,
              ),
          ],
        },
      ],
      child: Builder(
        builder: (ctx) => Focusable(
          focused: true,
          onKeyEvent: (event) => InputActions.dispatch(ctx, event),
          child: _card(
            wide: state.hasPanes,
            children: [
              _header(
                theme,
                children: [
                  PaletteBreadcrumb([...state.paneTrail, title, param.label]),
                  ...switch (param) {
                    TextParam(:final hint) => [
                      TextField(
                        controller: _valueController,
                        focused: true,
                        placeholder: hint,
                        onSubmitted: _cubit.submitText,
                        onKeyEvent: (event) =>
                            InputActions.dispatch(ctx, event),
                      ),
                    ],
                    NumberParam() => [
                      TextField(
                        controller: _valueController,
                        focused: true,
                        placeholder: _numberHint(param),
                        onSubmitted: _cubit.submitText,
                        onKeyEvent: (event) =>
                            InputActions.dispatch(ctx, event),
                      ),
                    ],
                    ChoiceParam(filter: FuzzyFilter()) => [
                      _optionQueryField(ctx, placeholder: 'Filter…'),
                    ],
                    ChoiceParam(filter: SearchFilter()) => [
                      _optionQueryField(ctx, placeholder: 'Search…'),
                    ],
                    ChoiceParam(filter: NoFilter()) ||
                    MultiChoiceParam() => const [],
                    ConfirmParam(:final danger) => [
                      SizedBox(
                        height: 1,
                        child: Text(
                          danger
                              ? '⚠ Enter to confirm · Esc to cancel'
                              : 'Enter to confirm · Esc to cancel',
                          style: TextStyle(
                            color: danger ? theme.error : theme.secondary,
                          ),
                        ),
                      ),
                    ],
                  },
                  if (state.editError case final String problem)
                    SizedBox(
                      height: 1,
                      child: Text(
                        '⚠ $problem',
                        style: TextStyle(color: theme.error),
                      ),
                    ),
                ],
              ),
              switch (param) {
                ChoiceParam() => Expanded(
                  child: _optionList(state, theme, multi: false),
                ),
                MultiChoiceParam() => Expanded(
                  child: _optionList(state, theme, multi: true),
                ),
                _ => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Component _optionQueryField(
    BuildContext ctx, {
    required String placeholder,
  }) => TextField(
    controller: _valueController,
    focused: true,
    placeholder: placeholder,
    onChanged: _cubit.optionQueryChanged,
    onKeyEvent: (event) => InputActions.dispatch(ctx, event),
  );

  Component _optionList(
    CollectingState state,
    AppThemeData theme, {
    required bool multi,
  }) {
    final options = state.visibleOptions;
    if (options.isEmpty) {
      return Center(
        child: Text('No options.', style: TextStyle(color: theme.muted)),
      );
    }
    return ScrollableListShell(
      controller: _listController,
      itemCount: options.length,
      itemBuilder: (_, index) => Hoverable(
        onTap: () => _selectRow(index, state.selectedIndex),
        onActivate: () {
          _selectRow(index, state.selectedIndex);
          if (multi) {
            _cubit.toggleOption();
          } else {
            _cubit.submitChoice();
          }
        },
        builder: (context, {required hovered}) => _OptionRow(
          entry: options[index],
          selected: index == state.selectedIndex,
          hovered: hovered,
          toggled: multi && state.toggled.contains(options[index].index),
          multi: multi,
        ),
      ),
    );
  }

  // ── Pane ────────────────────────────────────────────────

  Component _buildPane(ViewingPaneState state, AppThemeData theme) {
    return InputActions(
      actions: [
        KeyAction(
          label: 'Move',
          key: LogicalKey.arrowUp,
          visible: false,
          onActivate: () => _cubit.moveSelection(-1),
        ),
        KeyAction(
          label: 'Move',
          key: LogicalKey.arrowDown,
          visible: false,
          onActivate: () => _cubit.moveSelection(1),
        ),
        KeyAction(
          label: 'Run',
          key: LogicalKey.enter,
          visible: false,
          onActivate: _cubit.activate,
        ),
        KeyAction(
          label: 'Back',
          key: LogicalKey.escape,
          visible: false,
          onActivate: _cubit.back,
        ),
      ],
      child: Builder(
        builder: (ctx) {
          bool onKey(KeyboardEvent event) =>
              InputActions.dispatch(ctx, event) || _claimPaneKey(state, event);
          return Focusable(
            focused: true,
            onKeyEvent: onKey,
            child: _card(
              wide: true,
              footer: PaneHints(_paneHints(state)),
              children: [
                _paneHeader(state, theme, onKey),
                Expanded(child: _paneBody(state, theme)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Runs a printable key the pane claims, so it never reaches the query.
  bool _claimPaneKey(ViewingPaneState state, KeyboardEvent event) {
    final char = event.character;
    final plain = !event.isControlPressed && !event.isAltPressed;
    if (char == null || !plain || !state.claimsKey(char)) return false;
    _cubit.pressPaneKey(char);
    return true;
  }

  /// The surface band: breadcrumb, query field, status line and error.
  Component _paneHeader(
    ViewingPaneState state,
    AppThemeData theme,
    bool Function(KeyboardEvent event) onKey,
  ) => Container(
    color: theme.surface,
    padding: const EdgeInsets.only(left: 1, right: 1, bottom: 1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaletteBreadcrumb(state.paneTrail),
        if (state.hasQuery)
          TextField(
            controller: _paneQueryController,
            focused: true,
            placeholder:
                state.pane.placeholder ??
                switch (state.pane.filter) {
                  PaneFilter.search => 'Search…',
                  PaneFilter.fuzzy || PaneFilter.none => 'Filter…',
                },
            onChanged: _cubit.queryChanged,
            onKeyEvent: onKey,
          ),
        if (state.status case final PaneStatus status)
          PaneStatusBand(status, actions: state.bandActions),
        if (state.pendingAction case final PaneAction action)
          PanePendingBand(action),
        if (state.error case final String error)
          SizedBox(
            height: 1,
            child: Text('⚠ $error', style: TextStyle(color: theme.error)),
          ),
      ],
    ),
  );

  Component _paneBody(ViewingPaneState state, AppThemeData theme) {
    final entries = _paneEntries(state.visibleSections);
    if (state.loading || entries.isEmpty) {
      return Center(
        child: Text(
          state.loading ? 'Loading…' : 'Nothing to show.',
          style: TextStyle(color: theme.muted),
        ),
      );
    }
    return ScrollableListShell(
      controller: _listController,
      itemCount: entries.length,
      itemBuilder: (_, index) => switch (entries[index]) {
        final _PaneHeaderEntry header => PaletteGroupHeader(
          header.label,
          gap: 0,
        ),
        _PaneNoteEntry(:final note) => PaneNoteLine(note),
        _PaneColumnsEntry(:final section) => PaneColumnsHeader(section),
        _PaneRowEntry(:final section, :final row, :final index) => Hoverable(
          onTap: () => _selectRow(index, state.selectedIndex),
          onActivate: () {
            _selectRow(index, state.selectedIndex);
            _cubit.activate();
          },
          builder: (context, {required hovered}) => PaneRowView(
            row: row,
            section: section,
            selected: index == state.selectedIndex,
            hovered: hovered,
          ),
        ),
      },
    );
  }

  /// The selected row's live actions, Enter's first, then moving, filtering
  /// and going back. Actions drop out while one is still running.
  List<PaneHint> _paneHints(ViewingPaneState state) {
    final actions = state.pendingAction == null
        ? state.liveActions
        : const <PaneAction>[];
    return [
      for (final action in [
        ...actions.where((action) => action.primary),
        ...actions.where((action) => !action.primary),
      ])
        PaneHint.of(action),
      const PaneHint('▴/▾', 'Move'),
      if (state.offersFilterKey)
        const PaneHint(ViewingPaneState.filterKey, 'Filter'),
      PaneHint('esc', state.pane.backLabel),
    ];
  }

  // ── Invoking ────────────────────────────────────────────

  Component _buildInvoking(InvokingState state, AppThemeData theme) => _card(
    wide: state.hasPanes,
    children: [
      Expanded(
        child: Center(
          child: Text(
            state.running ?? 'Running…',
            style: TextStyle(color: theme.loading),
          ),
        ),
      ),
    ],
  );

  /// The palette's card: [paneWidth] wide when [wide] and the terminal has
  /// room, [commandWidth] otherwise.
  Component _card({
    required List<Component> children,
    bool wide = false,
    Component? footer,
  }) => LayoutBuilder(
    builder: (context, constraints) => OverlayCard(
      maxWidth: wide && constraints.maxWidth >= paneWidth
          ? paneWidth
          : commandWidth,
      maxHeight: cardHeight,
      footer: footer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  /// The band where the user types: padded on every side and lifted onto the
  /// surface color so it reads apart from the list below.
  Component _header(
    AppThemeData theme, {
    required List<Component> children,
  }) => Container(
    color: theme.surface,
    padding: const EdgeInsets.all(1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  String? _numberHint(NumberParam<num> param) {
    final min = param.min;
    final max = param.max;
    if (min != null && max != null) return '$min – $max';
    if (min != null) return '≥ $min';
    if (max != null) return '≤ $max';
    return null;
  }
}

/// One item of the browse list: a group header or a command row by index.
sealed class _BrowseEntry {
  const _BrowseEntry();
}

final class _GroupHeaderEntry extends _BrowseEntry {
  const _GroupHeaderEntry(this.group);

  final String group;
}

final class _CommandEntry extends _BrowseEntry {
  const _CommandEntry(this.index);

  final int index;
}

class _CommandRow extends StatelessComponent {
  const _CommandRow({
    required this.row,
    required this.selected,
    required this.hovered,
  });

  final PaletteRow row;
  final bool selected;
  final bool hovered;

  /// Cells for the command's glyph and the space after it.
  static const double glyphWidth = 2;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final command = row.command;
    final available = row.availability is Available;
    final primary = available && command.tier == CommandTier.primary;
    final titleColor = switch (row.availability) {
      Unavailable() => theme.muted,
      Available() when selected => theme.onBackground,
      Available() when primary => theme.primary,
      Available() => theme.onSurface,
    };
    final detail = switch (row.availability) {
      Unavailable(:final reason) => reason,
      Available() => command.description,
    };
    final active = selected || hovered;
    final fill = primary
        ? (active ? theme.primaryTintSelected : theme.primaryTint)
        : (active ? theme.surfaceAccent : null);
    final glyphColor = switch (row.availability) {
      Unavailable() => theme.muted,
      Available() when primary => theme.primary,
      Available() => theme.secondary,
    };
    final title = Text(
      command.title,
      style: TextStyle(
        color: titleColor,
        fontWeight: selected || primary ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final status = row.status;
    final trailing = [
      if (status?.progress case final double progress) ...[
        Text(' ▕', style: TextStyle(color: theme.muted)),
        SizedBox(
          width: barWidth,
          child: BlockProgressBar(
            fraction: progress.clamp(0, 1).toDouble(),
            color: theme.loading,
            track: theme.muted,
          ),
        ),
      ],
      if (command.shortcut case final String shortcut)
        Text(
          status == null ? shortcut : '$statusGap$shortcut',
          style: TextStyle(color: theme.muted),
        ),
    ];
    return PaletteListRow(
      selected: selected,
      fill: fill,
      leading: SizedBox(
        width: glyphWidth,
        child: Text(command.glyph ?? '', style: TextStyle(color: glyphColor)),
      ),
      leadingWidth: glyphWidth,
      title: switch (status) {
        null => title,
        CommandStatus(:final spans) => _TitleWithStatus(
          title: title,
          titleCells: UnicodeWidth.stringWidth(command.title),
          status: spans,
        ),
      },
      trailing: trailing.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      detail: Text(detail, style: TextStyle(color: theme.muted)),
    );
  }

  /// Cells a status's progress bar spans.
  static const double barWidth = 5;

  /// The space between a status and the title or shortcut beside it.
  static const String statusGap = '  ';
}

/// A command's title with its status hugging the far end of the room left,
/// ellipsized when that room runs out; the title itself is clipped only when
/// it alone overflows.
class _TitleWithStatus extends StatelessComponent {
  const _TitleWithStatus({
    required this.title,
    required this.titleCells,
    required this.status,
  });

  final Component title;
  final int titleCells;
  final List<PaneSpan> status;

  @override
  Component build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cells = constraints.maxWidth.toInt();
      final shown = min(titleCells, cells);
      final gap = min(_CommandRow.statusGap.length, cells - shown);
      return Row(
        children: [
          SizedBox(width: shown.toDouble(), child: title),
          SizedBox(width: gap.toDouble()),
          Expanded(child: EllipsizedSpanLine(status, align: PaneAlign.end)),
        ],
      );
    },
  );
}

@view
class _OptionRow extends StatelessComponent {
  const _OptionRow({
    required this.entry,
    required this.selected,
    required this.hovered,
    required this.toggled,
    required this.multi,
  });

  final IndexedOption entry;
  final bool selected;
  final bool hovered;
  final bool toggled;
  final bool multi;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return PaletteListRow(
      selected: selected,
      fill: selected || hovered ? theme.surfaceAccent : null,
      leading: multi
          ? SizedBox(
              width: PaletteListRow.defaultLeadingWidth,
              child: Text(
                toggled ? '[x]' : '[ ]',
                style: TextStyle(color: toggled ? theme.info : theme.muted),
              ),
            )
          : null,
      title: Text(
        entry.option.label,
        style: TextStyle(
          color: selected ? theme.onBackground : theme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      detail: switch (entry.option.detail) {
        null => null,
        final String detail => Text(
          detail,
          style: TextStyle(color: theme.muted),
        ),
      },
    );
  }
}

/// One item of a pane list: a group header, a note, a table's column titles,
/// or a row numbered across sections.
sealed class _PaneEntry {
  const _PaneEntry();
}

final class _PaneHeaderEntry extends _PaneEntry {
  const _PaneHeaderEntry(this.title, this.count);

  final String title;
  final int? count;

  String get label => [title, ?count].join(' ');
}

final class _PaneNoteEntry extends _PaneEntry {
  const _PaneNoteEntry(this.note);

  final PaneNote note;
}

final class _PaneColumnsEntry extends _PaneEntry {
  const _PaneColumnsEntry(this.section);

  final PaneSection section;
}

final class _PaneRowEntry extends _PaneEntry {
  const _PaneRowEntry(this.section, this.row, this.index);

  final PaneSection section;
  final PaneRow row;
  final int index;
}
