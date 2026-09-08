import 'package:bestie_palette_view/src/models/indexed_option.dart';
import 'package:bestie_palette_view/src/models/palette_row.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:bestie_palette_view/src/state/palette_logic.dart';
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
  Param? _lastParam;

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
    super.dispose();
  }

  /// Scrolls the moved-to row into view.
  void _onCursorMoved(int index) {
    final state = _cubit.state;
    final offset = state is BrowsingState
        ? _headersBefore(state.rows, index)
        : 0;
    _listController.ensureIndexVisible(index: index + offset);
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

  /// Clears stale text when the palette closes or the collected param
  /// changes, so each step starts from an empty field.
  void _onStateChanged(BuildContext _, PaletteState state) {
    if (state is ClosedState && _queryController.text.isNotEmpty) {
      _queryController.clear();
    }
    final param = state is CollectingState ? state.currentParam : null;
    if (!identical(param, _lastParam)) {
      _lastParam = param;
      _valueController.clear();
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
            final BrowsingState s => _buildBrowsing(s, theme),
            final CollectingState s => _buildCollecting(s, theme),
            final InvokingState s => _buildInvoking(s, theme),
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
                      itemBuilder: (_, i) => switch (entries[i]) {
                        _GroupHeaderEntry(:final group) => _GroupHeader(group),
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
            children: [
              _header(
                theme,
                children: [
                  SizedBox(
                    height: 1,
                    child: Text(
                      '$title › ${param.label}',
                      style: TextStyle(color: theme.secondary),
                    ),
                  ),
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
      itemBuilder: (_, i) => Hoverable(
        onTap: () => _selectRow(i, state.selectedIndex),
        onActivate: () {
          _selectRow(i, state.selectedIndex);
          if (multi) {
            _cubit.toggleOption();
          } else {
            _cubit.submitChoice();
          }
        },
        builder: (context, {required hovered}) => _OptionRow(
          entry: options[i],
          selected: i == state.selectedIndex,
          hovered: hovered,
          toggled: multi && state.toggled.contains(options[i].index),
          multi: multi,
        ),
      ),
    );
  }

  // ── Invoking ────────────────────────────────────────────

  Component _buildInvoking(InvokingState state, AppThemeData theme) => _card(
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

  Component _card({required List<Component> children}) => OverlayCard(
    maxWidth: 64,
    maxHeight: 29,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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

@view
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

/// A group label in the cursor gutter's alignment with a faint rule running
/// from it to the card's edge, set off from the rows above by a blank line.
@view
class _GroupHeader extends StatelessComponent {
  const _GroupHeader(this.group);

  final String group;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 1),
      child: SizedBox(
        height: 1,
        child: Row(
          children: [
            const SizedBox(width: _TwoLineRow.gutter),
            Text(
              group,
              style: TextStyle(color: theme.muted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 1),
            Expanded(child: _Rule(color: theme.outline)),
          ],
        ),
      ),
    );
  }
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
    final trailing = [?command.shortcut];
    return _TwoLineRow(
      selected: selected,
      fill: fill,
      leading: SizedBox(
        width: glyphWidth,
        child: Text(command.glyph ?? '', style: TextStyle(color: glyphColor)),
      ),
      leadingWidth: glyphWidth,
      title: Text(
        command.title,
        style: TextStyle(
          color: titleColor,
          fontWeight: selected || primary ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: trailing.isEmpty
          ? null
          : Text(trailing.join('  '), style: TextStyle(color: theme.muted)),
      detail: detail,
    );
  }
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
    return _TwoLineRow(
      selected: selected,
      fill: selected || hovered ? theme.surfaceAccent : null,
      leading: multi
          ? SizedBox(
              width: _TwoLineRow.defaultLeadingWidth,
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
      detail: entry.option.detail,
    );
  }
}

/// A list row with a cursor gutter, a title line, and an optional muted
/// detail line underneath.
@view
class _TwoLineRow extends StatelessComponent {
  const _TwoLineRow({
    required this.selected,
    required this.fill,
    required this.title,
    this.leading,
    this.leadingWidth = defaultLeadingWidth,
    this.trailing,
    this.detail,
  });

  final bool selected;

  /// Background behind the text lines.
  final Color? fill;

  final Component title;
  final Component? leading;

  /// Cells [leading] spans, so the detail line indents past it.
  final double leadingWidth;
  final Component? trailing;
  final String? detail;

  /// Cells reserved for the selection cursor at the left of every row.
  static const double gutter = 2;
  static const double defaultLeadingWidth = 4;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final detail = this.detail;
    return Container(
      color: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 1,
            child: Row(
              children: [
                SizedBox(
                  width: gutter,
                  child: Text(
                    selected ? '▸' : '',
                    style: TextStyle(color: theme.info),
                  ),
                ),
                if (leading case final Component leading) leading,
                Expanded(child: title),
                if (trailing case final Component trailing) trailing,
              ],
            ),
          ),
          if (detail != null)
            SizedBox(
              height: 1,
              child: Padding(
                padding: EdgeInsets.only(
                  left: gutter + (leading == null ? 0 : leadingWidth),
                ),
                child: Text(detail, style: TextStyle(color: theme.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A one-row horizontal rule that stretches to its parent's width.
@view
class _Rule extends StatelessComponent {
  const _Rule({required this.color});

  final Color color;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: LayoutBuilder(
      builder: (context, constraints) => Text(
        '─' * constraints.maxWidth.toInt(),
        style: TextStyle(color: color),
      ),
    ),
  );
}
