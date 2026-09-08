import 'package:bestie_ui/src/input/hoverable.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Two-line horizontal tab strip standing on a rule that spans the width.
///
/// Idle tabs sit on the rule, their walls turning out to join it. The active
/// tab is lidded, stands a row taller, and breaks the rule either side so it
/// opens into the content below.
@view
class TabHeader<T> extends StatelessComponent {
  /// Creates a [TabHeader].
  const TabHeader({
    required this.tabs,
    required this.selected,
    required this.label,
    this.onSelect,
    super.key,
  });

  /// All tabs to display, in order.
  final List<T> tabs;

  /// The currently active tab.
  final T selected;

  /// Returns the display label for a tab.
  final String Function(T tab) label;

  /// Called with a tab when it is clicked.
  final void Function(T tab)? onSelect;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final consumed = tabs.fold(
          _leadingInset + tabs.length - 1,
          (total, tab) => total + UnicodeWidth.stringWidth(label(tab)) + 4,
        );
        final trailing = constraints.maxWidth.floor() - consumed;

        // The rule runs unbroken and every tab's feet turn into it, so the
        // whole strip is one continuous drawing.
        return Container(
          color: appTheme.tabBarBackground,
          child: Row(
            children: [
              const _Gap(width: _leadingInset),
              for (final tab in tabs) ...[
                if (tab != tabs.first) const _Gap(width: 1),
                Hoverable(
                  onTap: onSelect == null ? null : () => onSelect!(tab),
                  builder: (context, {required hovered}) => _Tab(
                    label: label(tab),
                    selected: tab == selected,
                    hovered: hovered,
                  ),
                ),
              ],
              if (trailing > 0) _Gap(width: trailing),
            ],
          ),
        );
      },
    );
  }
}

/// Blank columns before the first tab.
const _leadingInset = 2;

/// Filler beside and between tabs, carrying the baseline they stand on.
class _Gap extends StatelessComponent {
  const _Gap({required this.width});

  final int width;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Column(
      children: [
        Text(' ' * width),
        // Matches the tab feet that turn into it, so the rule and the walls
        // read as one drawing.
        Text(
          '━' * width,
          style: TextStyle(color: appTheme.outlineVariant),
        ),
      ],
    );
  }
}

class _Tab extends StatelessComponent {
  const _Tab({
    required this.label,
    required this.selected,
    this.hovered = false,
  });

  final String label;
  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final appTheme = AppTheme.of(context);

    // Hovering previews selection: the tab takes the same lidded shape and
    // edge, in muted ink and regular weight rather than page ink and bold.
    final lidded = selected || hovered;

    final edge = lidded
        ? selected
              ? appTheme.outlineVariant
              : appTheme.muted
        : appTheme.outlineVariant;
    final ink = selected ? theme.onBackground : appTheme.muted;

    // Every tab stands on the rule, its walls turning out to meet it. The feet
    // turn away from the interior, so the tab stays open at the bottom and the
    // active one still reads as continuous with the content below.
    final leftBar = Text('┛', style: TextStyle(color: edge));
    final rightBar = Text('┗', style: TextStyle(color: edge));

    // The active tab carries the page background so it reads as continuous
    // with the content below it.
    final background = selected
        ? theme.background
        : hovered
        ? appTheme.hover
        : appTheme.tabUnselectedBackground;

    final tabWidth = UnicodeWidth.stringWidth(label) + 4;

    return Column(
      children: [
        // A lidded tab stands a row taller. The rest get a low line that hugs
        // their top edge without claiming the row, inset to the interior
        // cells: a full-width line would run past the side bars, which sit
        // centred in the cells beneath its ends.
        Container(
          color: lidded ? background : appTheme.tabBarBackground,
          child: Text(
            lidded ? '┏${'━' * (tabWidth - 2)}┓' : ' ${'▁' * (tabWidth - 2)} ',
            style: TextStyle(color: edge),
          ),
        ),
        Container(
          color: background,
          child: Row(
            children: [
              leftBar,
              Text(
                ' $label ',
                style: TextStyle(
                  color: ink,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
              rightBar,
            ],
          ),
        ),
      ],
    );
  }
}
