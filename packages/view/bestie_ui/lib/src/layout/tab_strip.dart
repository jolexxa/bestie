import 'package:bestie_ui/src/input/hoverable.dart';
import 'package:bestie_ui/src/layout/wrap.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:characters/characters.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// One tab in a [TabStrip].
@model
class TabStripItem {
  const TabStripItem({
    required this.id,
    required this.label,
    this.closable = true,
  });

  /// Stable identity, reported back through the strip's callbacks.
  final String id;

  /// Text shown on the tab.
  final String label;

  /// Whether the tab carries a close affordance. A pinned tab sets this false.
  final bool closable;
}

/// A browser-style tab strip: selectable tabs that wrap onto more rows as they
/// overflow, each closable tab carrying a hover/click ×, and a trailing "+"
/// stub that opens a new tab. A rule runs under the strip, joined to each
/// tab's edges, and opens beneath the active tab so that tab reads as part of
/// the content below.
///
/// Presentational and controlled — it holds no state. Selection, closing and
/// creation are reported through callbacks; the owner decides what changes.
@view
class TabStrip extends StatelessComponent {
  const TabStrip({
    required this.tabs,
    required this.activeId,
    this.onSelect,
    this.onClose,
    this.onNew,
    super.key,
  });

  /// The tabs, in order.
  final List<TabStripItem> tabs;

  /// The id of the active tab; that tab is highlighted.
  final String activeId;

  /// Called when a tab body is clicked.
  final void Function(String id)? onSelect;

  /// Called when a closable tab's × is clicked.
  final void Function(String id)? onClose;

  /// Called when the trailing "+" stub is clicked. The stub is hidden when
  /// null.
  final VoidCallback? onNew;

  /// Widest a tab label may render, in cells; anything longer is clipped
  /// with an ellipsis.
  static const maxLabelCells = 18;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    return Container(
      color: appTheme.tabBarBackground,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(color: appTheme.tabSelectedBorder),
          ),
          Wrap(
            spacing: 1,
            items: [
              for (final tab in tabs)
                (
                  width: _tabWidth(tab),
                  child: _Tab(
                    tab: tab,
                    label: _clip(tab.label),
                    width: _tabWidth(tab),
                    selected: tab.id == activeId,
                    onSelect: onSelect == null ? null : () => onSelect!(tab.id),
                    onClose: onClose == null ? null : () => onClose!(tab.id),
                  ),
                ),
              if (onNew != null) (width: 3, child: _NewStub(onNew: onNew!)),
            ],
          ),
        ],
      ),
    );
  }

  /// Rows the strip occupies: its tabs plus the rule beneath them.
  static const height = 2;

  int _tabWidth(TabStripItem tab) =>
      UnicodeWidth.stringWidth(_clip(tab.label)) + (tab.closable ? 6 : 4);

  /// Clips [label] to [maxLabelCells] display cells, ellipsis included.
  String _clip(String label) {
    if (UnicodeWidth.stringWidth(label) <= maxLabelCells) return label;
    final clipped = StringBuffer();
    var cells = 0;
    for (final grapheme in label.characters) {
      final width = UnicodeWidth.graphemeWidth(grapheme);
      if (cells + width > maxLabelCells - 1) break;
      clipped.write(grapheme);
      cells += width;
    }
    return '$clipped…';
  }
}

class _Tab extends StatefulComponent {
  const _Tab({
    required this.tab,
    required this.label,
    required this.width,
    required this.selected,
    this.onSelect,
    this.onClose,
  });

  final TabStripItem tab;

  /// [TabStripItem.label], already clipped to fit the strip.
  final String label;

  /// Cells the tab spans, so its notch in the rule matches it exactly.
  final int width;

  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onClose;

  @override
  State<_Tab> createState() => _StripTabState();
}

class _StripTabState extends State<_Tab> {
  bool _hovered = false;

  /// Hovering the × itself, distinctly from the tab body.
  bool _closeHovered = false;

  void _setHovered({required bool value}) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setCloseHovered({required bool value}) {
    if (_closeHovered == value) return;
    setState(() => _closeHovered = value);
  }

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final appTheme = AppTheme.of(context);

    final selected = component.selected;
    final barColor = selected
        ? appTheme.tabSelectedBorder
        : appTheme.tabUnselectedBorder;
    final bar = Text('│', style: TextStyle(color: barColor));

    final background = selected
        ? theme.background
        : _hovered
        ? appTheme.hover
        : appTheme.tabUnselectedBackground;
    final fg = selected || _hovered ? theme.onBackground : appTheme.muted;
    final showClose = component.tab.closable && (_hovered || selected);

    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => _setHovered(value: true),
          onExit: (_) => _setHovered(value: false),
          child: Container(
            color: background,
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: component.onSelect,
                  child: Row(
                    children: [
                      bar,
                      Text(
                        component.tab.closable
                            ? ' ${component.label}'
                            : ' ${component.label} ',
                        style: TextStyle(
                          color: fg,
                          fontWeight: selected ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close: a reserved three-cell ` × ` button so hover never
                // reflows the strip.
                if (component.tab.closable)
                  MouseRegion(
                    onEnter: (_) => _setCloseHovered(value: true),
                    onExit: (_) => _setCloseHovered(value: false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: component.onClose,
                      child: Text(
                        showClose ? ' × ' : '   ',
                        style: TextStyle(
                          color: _closeHovered ? appTheme.error : fg,
                          backgroundColor: _closeHovered
                              ? appTheme.errorHover
                              : null,
                          fontWeight: _closeHovered ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                bar,
              ],
            ),
          ),
        ),
        Row(
          children: [
            Text(selected ? '┘' : '┴', style: TextStyle(color: barColor)),
            Text(
              (selected ? ' ' : '─') * (component.width - 2),
              style: selected
                  ? TextStyle(backgroundColor: theme.background)
                  : TextStyle(color: appTheme.tabSelectedBorder),
            ),
            Text(selected ? '└' : '┴', style: TextStyle(color: barColor)),
          ],
        ),
      ],
    );
  }
}

class _NewStub extends StatelessComponent {
  const _NewStub({required this.onNew});

  final VoidCallback onNew;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final appTheme = AppTheme.of(context);
    return Column(
      children: [
        Hoverable(
          onTap: onNew,
          builder: (context, {required hovered}) => Container(
            color: hovered ? appTheme.hover : appTheme.tabUnselectedBackground,
            child: Text(
              ' + ',
              style: TextStyle(
                color: hovered ? theme.onBackground : appTheme.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 1, width: 3),
      ],
    );
  }
}
