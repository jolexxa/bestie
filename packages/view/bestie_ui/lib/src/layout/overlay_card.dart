import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Centered, bordered card used as the backdrop for browse overlays
/// (resolve spinner, quant picker, error).
@view
class OverlayCard extends StatelessComponent {
  const OverlayCard({
    required this.child,
    this.maxWidth = 48,
    this.maxHeight,
    super.key,
  });

  /// Content rendered inside the bordered card.
  final Component child;

  /// Maximum width constraint.
  final int maxWidth;

  /// Optional maximum height constraint.
  final int? maxHeight;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth.toDouble(),
          maxHeight: maxHeight?.toDouble() ?? double.infinity,
        ),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: theme.outlineVariant),
          color: theme.background,
        ),
        child: child,
      ),
    );
  }
}
