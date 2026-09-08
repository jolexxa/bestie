import 'package:bestie_config_view/bestie_config_view.dart';
import 'package:bestie_config_view/src/view/components/credits_section.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Full-screen config overlay with two-pane layout.
///
/// Reads its [ConfigCubit] from an ancestral [BlocProvider] mounted by
/// the router (see `Router` in `app/router/router_component.dart`). The cubit
/// outlives this view across open/close toggles, so `selectedPageId`
/// and friends survive a `Ctrl+O` round-trip.
@view
class ConfigPageView extends StatefulComponent {
  const ConfigPageView({super.key});

  @override
  State<ConfigPageView> createState() => _ConfigPageViewState();
}

class _ConfigPageViewState extends State<ConfigPageView> {
  late final ConfigCubit _cubit;
  final ScrollController _listController = ScrollController();
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = BlocProvider.of<ConfigCubit>(context, listen: false)
      ..onCursorMoved = _onCursorMoved
      ..onPageChanged = _onPageChanged;
  }

  @override
  void dispose() {
    _cubit
      ..onCursorMoved = null
      ..onPageChanged = null;
    _listController.dispose();
    _editController.dispose();
    super.dispose();
  }

  /// Keeps the freshly-selected row visible after a nav input.
  void _onCursorMoved(int index) {
    _listController.ensureIndexVisible(index: _visualIndex(index));
  }

  /// Resets the viewport to the top after switching pages.
  void _onPageChanged() {
    _listController.jumpTo(0);
  }

  /// Maps a logical entry index to its visual row index, accounting for
  /// inline section headings on multi-section pages and the info page's
  /// custom layout.
  int _visualIndex(int paramIdx) {
    final state = _cubit.state;
    final page = state.selectedPage;
    if (page is ConfigInfoPage) {
      return page.visualIndex(paramIdx, state.data.toolCount);
    }
    if (page is ConfigParamPage && page.sections.length > 1) {
      return _visualIndexFor(page, paramIdx);
    }
    return paramIdx;
  }

  /// Moves the selection to entry [index] — the click equivalent of arrowing.
  void _selectEntry(int index) {
    final current = _cubit.state.selectedIndex;
    if (index != current) _cubit.moveSelection(index - current);
  }

  /// Double-click: select the entry, then begin editing if it's editable.
  void _activateEntry(int index, ConfigEntry entry) {
    _selectEntry(index);
    if (entry.field.customEditable) _cubit.beginEdit();
  }

  /// Click a section tab: change to that page (mouse equivalent of Tab).
  void _selectPage(List<ConfigPage> pages, int index) {
    final current = pages.indexWhere(
      (p) => p.id == _cubit.state.data.selectedPageId,
    );
    if (index != current && current != -1) _cubit.changePage(index - current);
  }

  /// Seed/clear the edit controller on Browsing↔Editing transitions.
  void _onStateTransition(BuildContext _, ConfigState state) {
    if (state is! EditingState) {
      _editController.clear();
      return;
    }
    final entry = state.selectedEntry;
    if (entry == null) return;
    final address = state.addressFor(entry);
    if (address == null) {
      _editController.text = '';
      return;
    }
    final value = state.editStartValueFor(entry, address);
    _editController.text = entry.field.formatValue(value);
  }

  /// Inserts a newline character at the current cursor position in the
  /// edit controller. Used by the `Ctrl+J` action — a fallback for
  /// terminals (e.g. macOS Terminal.app) that don't deliver
  /// `Shift+Enter` / `Alt+Enter` as a modified Enter key.
  void _insertNewline() {
    final text = _editController.text;
    final selection = _editController.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    _editController.text =
        '${text.substring(0, start)}\n${text.substring(end)}';
    _editController.selection = TextSelection.collapsed(offset: start + 1);
  }

  // ── Keyboard ────────────────────────────────────────────

  /// Base config-page actions (always present when not editing a value).
  List<KeyAction> _buildBaseActions(
    ConfigState state,
    AppThemeData appTheme,
  ) {
    final page = state.selectedPage;
    final editable = page is ConfigParamPage;

    // A document page scrolls its viewport with the arrow
    // keys; every other page moves a row selection.
    final scrollOnly = page is ConfigDocumentPage;

    return [
      KeyAction(
        label: scrollOnly ? 'Scroll' : 'Nav',
        key: LogicalKey.arrowUp,
        footerOverride: scrollOnly ? '[▴/▾] Scroll' : '[▴/▾] Nav',
        onActivate: scrollOnly
            ? () => _listController.scrollUp(3)
            : () => _cubit.moveSelection(-1),
      ),
      KeyAction(
        label: scrollOnly ? 'Scroll' : 'Nav',
        key: LogicalKey.arrowDown,
        visible: false,
        onActivate: scrollOnly
            ? () => _listController.scrollDown(3)
            : () => _cubit.moveSelection(1),
      ),
      if (editable && !state.editing) ...[
        KeyAction(
          label: 'Adjust',
          key: LogicalKey.arrowLeft,
          footerOverride: '[◂/▸] Adjust',
          onActivate: () => _cubit.adjustValue(-1),
        ),
        KeyAction(
          label: 'Adjust',
          key: LogicalKey.arrowRight,
          visible: false,
          onActivate: () => _cubit.adjustValue(1),
        ),
        if (state.selectedEntry?.field.customEditable ?? false)
          KeyAction(
            label: 'Edit',
            key: LogicalKey.enter,
            onActivate: _cubit.beginEdit,
          ),
        KeyAction(
          label: 'Reset',
          key: LogicalKey.keyR,
          onActivate: _cubit.resetParam,
        ),
      ],
      KeyAction(
        label: 'Page',
        key: LogicalKey.tab,
        footerOverride: '[Tab/⇧Tab] Page',
        onActivate: () => _cubit.changePage(1),
      ),
      KeyAction(
        label: 'Prev page',
        key: LogicalKey.tab,
        shift: true,
        visible: false,
        onActivate: () => _cubit.changePage(-1),
      ),
      KeyAction(
        label: 'Close',
        key: LogicalKey.escape,
        onActivate: _cubit.requestClose,
      ),
    ];
  }

  /// Editing-mode actions, contributed as a nested [InputActions] scope so
  /// `Esc=Cancel` shadows the base `Esc=Close` while editing. Submit is
  /// handled by the [TextField]'s own `onSubmitted`, not a [KeyAction].
  /// Returns `null` when not in edit mode.
  List<KeyAction>? _buildEditingActions(ConfigState state) {
    if (!state.editing) return null;
    return [
      KeyAction(
        label: 'Newline',
        key: LogicalKey.keyN,
        ctrl: true,
        onActivate: _insertNewline,
      ),
      KeyAction(
        label: 'Cancel',
        key: LogicalKey.escape,
        onActivate: _cubit.cancelEdit,
      ),
    ];
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return BlocListener<ConfigCubit, ConfigState>(
      listenWhen: (prev, curr) =>
          (prev is BrowsingState && curr is EditingState) ||
          (prev is EditingState && curr is BrowsingState),
      listener: _onStateTransition,
      child: BlocBuilder<ConfigCubit, ConfigState>(
        builder: (context, state) {
          final appTheme = AppTheme.of(context);
          final baseActions = _buildBaseActions(state, appTheme);
          final editingActions = _buildEditingActions(state);
          final resolver = _cubit.resolver;
          final targetScope = state.data.targetScope;
          final targetScopeLabel = targetScope?.path.last;

          Component pageContent(BuildContext ctx) => Focusable(
            focused: true,
            onKeyEvent: (event) => InputActions.dispatch(ctx, event),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: SectionTabs(
                          pages: state.layout.pages,
                          selectedPageId: state.data.selectedPageId,
                          onSelectPage: (index) =>
                              _selectPage(state.layout.pages, index),
                        ),
                      ),
                      SizedBox(
                        width: 1,
                        child: Container(color: theme.outlineVariant),
                      ),
                      Expanded(
                        child: _buildPage(
                          state,
                          appTheme,
                          resolver,
                          targetScope,
                          targetScopeLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                const PageFooter(),
              ],
            ),
          );

          return Container(
            color: theme.background,
            padding: const EdgeInsets.only(
              top: appEdgeInset,
              left: appEdgeInset,
              right: appEdgeInset,
              bottom: 1,
            ),
            child: InputActions(
              actions: baseActions,
              child: editingActions == null
                  ? Builder(builder: pageContent)
                  : InputActions(
                      actions: editingActions,
                      child: Builder(builder: pageContent),
                    ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the right-pane content for the selected page.
  Component _buildPage(
    ConfigState state,
    AppThemeData appTheme,
    ConfigView resolver,
    ConfigScope? targetScope,
    String? targetScopeLabel,
  ) {
    final page = state.selectedPage;
    return switch (page) {
      final ConfigParamPage p when p.sections.length > 1 => _buildSectionedPage(
        state: state,
        appTheme: appTheme,
        resolver: resolver,
        targetScope: targetScope,
        sections: p.sections,
        header: p.requiresTargetScope
            ? PageHeader(
                title: p.label,
                scope: state.hasTargetScope ? targetScopeLabel : 'no target',
                scopeWarning: !state.hasTargetScope,
              )
            : PageHeader(title: p.label),
      ),
      final ConfigParamPage p => _buildParamListPage(
        title: p.label,
        state: state,
        appTheme: appTheme,
        resolver: resolver,
        targetScope: targetScope,
      ),
      ConfigInfoPage(:final label) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: label),
          Expanded(
            child: InfoSection(
              selectedIndex: state.selectedIndex,
              controller: _listController,
              onSelect: _selectEntry,
            ),
          ),
        ],
      ),
      ConfigDocumentPage(:final id, :final label) when id == 'credits' =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: label),
            Expanded(child: CreditsSection(controller: _listController)),
          ],
        ),
      ConfigDocumentPage(:final id) => throw StateError(
        'No document renderer for config page "$id"',
      ),
      null => const SizedBox(),
    };
  }

  /// Single-section editable page: page title + flat scrollable entry list.
  Component _buildParamListPage({
    required String title,
    required ConfigState state,
    required AppThemeData appTheme,
    required ConfigView resolver,
    required ConfigScope? targetScope,
  }) {
    final entries = state.visibleEntries;
    final header = PageHeader(title: title);

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Center(
              child: Text(
                'No parameters.',
                style: TextStyle(color: appTheme.muted),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ScrollableListShell(
            controller: _listController,
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final isSelected = i == state.selectedIndex;
              final isEditing = state.editing && isSelected;
              return Hoverable(
                onTap: () => _selectEntry(i),
                onActivate: () => _activateEntry(i, entries[i]),
                builder: (context, {required hovered}) => ConfigRow(
                  entry: entries[i],
                  resolver: resolver,
                  targetScope: targetScope,
                  isSelected: isSelected,
                  isEditing: isEditing,
                  hovered: hovered,
                  editController: isEditing ? _editController : null,
                  editError: isEditing ? state.editError : null,
                  onConfirm: isEditing ? _cubit.confirmEdit : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Multi-section editable page: page title + flat scrollable entry list
  /// with inline section headings from [ConfigSection.heading].
  Component _buildSectionedPage({
    required ConfigState state,
    required AppThemeData appTheme,
    required ConfigView resolver,
    required ConfigScope? targetScope,
    required List<ConfigSection> sections,
    required PageHeader header,
  }) {
    final entries = sections.expand((s) => s.entries).toList();

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Center(
              child: Text(
                'No parameters.',
                style: TextStyle(color: appTheme.muted),
              ),
            ),
          ),
        ],
      );
    }

    // Flatten entries into a visual list with inline section headings
    // sourced from the layout.
    final visual = <Component>[];
    var paramIdx = 0;
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      visual.add(
        SectionHeading(
          label: section.heading,
          suppressTopSpacer: s == 0,
        ),
      );
      for (final entry in section.entries) {
        final index = paramIdx;
        final isSelected = index == state.selectedIndex;
        final isEditing = state.editing && isSelected;
        visual.add(
          Hoverable(
            onTap: () => _selectEntry(index),
            onActivate: () => _activateEntry(index, entry),
            builder: (context, {required hovered}) => ConfigRow(
              entry: entry,
              resolver: resolver,
              targetScope: targetScope,
              isSelected: isSelected,
              isEditing: isEditing,
              hovered: hovered,
              editController: isEditing ? _editController : null,
              editError: isEditing ? state.editError : null,
              onConfirm: isEditing ? _cubit.confirmEdit : null,
            ),
          ),
        );
        paramIdx++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ScrollableListShell(
            controller: _listController,
            itemCount: visual.length,
            itemBuilder: (_, i) => visual[i],
          ),
        ),
      ],
    );
  }
}

int _visualIndexFor(ConfigParamPage page, int paramIdx) {
  if (paramIdx < 0) return 0;
  var offset = 0;
  var remaining = paramIdx;
  for (final section in page.sections) {
    if (remaining < section.entries.length) return offset + 1 + remaining;
    remaining -= section.entries.length;
    offset += section.entries.length + 1;
  }
  return offset;
}
