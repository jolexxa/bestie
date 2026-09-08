import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A reusable list item for displaying models in both the
/// browser, local models, and chat views.
///
/// Layout:
/// ```text
/// [badge] [name]                    [trailing]
///   [stat1]  [stat2]  [stat3]  ...
///   [progress bar]  or  [empty spacer]
/// ```
///
/// This is a pure presentational widget — it renders exactly
/// what it's given. Domain-specific logic (download phases,
/// load states, etc.) should be resolved by the caller.
@view
class ModelListItem extends StatelessComponent {
  /// Creates a [ModelListItem].
  const ModelListItem({
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    this.hovered = false,
    this.index = 0,
    this.stats = const [],
    this.trailing,
    this.subtitle,
    this.alternateBackground = false,
    this.progress,
    this.indeterminate = false,
    this.progressColor,
    super.key,
  });

  /// Display name for the model.
  final String name;

  /// Optional subtitle shown below the name (e.g. model ID).
  final String? subtitle;

  /// Badge symbol (e.g. '●', '○', '✓', '◐').
  final String badge;

  /// Badge color.
  final Color badgeColor;

  /// Whether this item is currently selected.
  final bool selected;

  /// Whether the mouse is currently hovering this item.
  final bool hovered;

  /// Index in the list (used for alternating backgrounds).
  final int index;

  /// Stats or metadata shown on the second line.
  final List<Component> stats;

  /// Optional trailing widget (e.g. assigned star).
  final Component? trailing;

  /// Whether to use alternating row backgrounds.
  final bool alternateBackground;

  /// Progress value (0.0–1.0). When non-null, a progress bar
  /// is rendered on the third line.
  final double? progress;

  /// Whether the progress bar should animate in indeterminate mode.
  final bool indeterminate;

  /// Color of the progress bar. Defaults to [TuiThemeData.primary].
  final Color? progressColor;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final bgColor = selected
        ? theme.surfaceAccent
        : hovered
        ? theme.hover
        : alternateBackground && index.isOdd
        ? theme.surface
        : null;
    final nameColor = theme.onSurface;
    final nameWeight = selected ? FontWeight.bold : FontWeight.normal;
    final subtitleColor = theme.muted;

    final barColor = progressColor ?? theme.primary;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                badge,
                style: TextStyle(color: badgeColor),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: nameColor,
                    fontWeight: nameWeight,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle case final s?)
            Container(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                s,
                style: TextStyle(color: subtitleColor),
              ),
            ),
          if (stats.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(left: 2),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    stats[i],
                  ],
                ],
              ),
            ),
          if (progress != null || indeterminate)
            Row(
              children: [
                Expanded(
                  child: ProgressBar(
                    value: progress ?? 0,
                    indeterminate: indeterminate,
                    borderStyle: ProgressBarBorderStyle.single,
                    valueColor: barColor,
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 1),
        ],
      ),
    );
  }
}
