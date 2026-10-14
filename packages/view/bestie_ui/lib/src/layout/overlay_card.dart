import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Centered, bordered card used as the backdrop for overlays, with an
/// optional [footer] set apart from the body by a rule joined to the border.
@view
class OverlayCard extends StatelessComponent {
  const OverlayCard({
    required this.child,
    this.maxWidth = 48,
    this.maxHeight,
    this.footer,
    super.key,
  });

  /// Content rendered inside the bordered card.
  final Component child;

  /// Maximum width constraint.
  final int maxWidth;

  /// Optional maximum height constraint.
  final int? maxHeight;

  /// Drawn along the bottom of the card, under a `├──┤` rule.
  final Component? footer;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final color = theme.outlineVariant;
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth.toDouble(),
          maxHeight: maxHeight?.toDouble() ?? double.infinity,
        ),
        color: theme.background,
        child: switch (footer) {
          null => Container(
            decoration: BoxDecoration(border: BoxBorder.all(color: color)),
            child: child,
          ),
          final Component footer => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EdgeRule(left: '┌', right: '┐', color: color),
              Flexible(
                child: _Sides(color: color, child: child),
              ),
              _EdgeRule(left: '├', right: '┤', color: color),
              _Sides(color: color, child: footer),
              _EdgeRule(left: '└', right: '┘', color: color),
            ],
          ),
        },
      ),
    );
  }
}

/// A horizontal border line capped by [left] and [right].
class _EdgeRule extends StatelessComponent {
  const _EdgeRule({
    required this.left,
    required this.right,
    required this.color,
  });

  final String left;
  final String right;
  final Color color;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: LayoutBuilder(
      builder: (context, constraints) => Text(
        '$left${'─' * (constraints.maxWidth.toInt() - 2)}$right',
        style: TextStyle(color: color),
      ),
    ),
  );
}

/// [child] between a vertical border line on each side.
class _Sides extends StatelessComponent {
  const _Sides({required this.color, required this.child});

  final Color color;
  final Component child;

  @override
  Component build(BuildContext context) {
    final edge = LayoutBuilder(
      builder: (context, constraints) => Text(
        List.filled(constraints.maxHeight.toInt(), '│').join('\n'),
        style: TextStyle(color: color),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: child,
          ),
          Positioned(left: 0, top: 0, bottom: 0, width: 1, child: edge),
          Positioned(right: 0, top: 0, bottom: 0, width: 1, child: edge),
        ],
      ),
    );
  }
}
