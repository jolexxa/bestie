import 'package:bestie_ui/src/input/hoverable.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A keyboard-or-mouse actionable button: bordered by default, or a single
/// dense row for places with no room for a box. Fills when hovered or
/// [selected], so keyboard focus and the mouse read the same.
@view
class AppButton extends StatelessComponent {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.color,
    this.onColor,
    this.selected = false,
    this.dense = false,
    super.key,
  });

  /// The button caption. Callers may lead with a key glyph (e.g. `↵`) to
  /// hint at the equivalent shortcut.
  final String label;

  /// Invoked on click — wire this to the same callback as the bound key.
  final VoidCallback onPressed;

  /// Accent for the border and label (and the fill when hovered).
  /// Defaults to the theme primary.
  final Color? color;

  /// Label color when the button is filled. Defaults to the theme onPrimary.
  final Color? onColor;

  /// Whether keyboard focus rests here; drawn filled, as when hovered.
  final bool selected;

  /// One row with no border, for a row that cannot spare three.
  final bool dense;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final accent = color ?? theme.primary;
    final onAccent = onColor ?? theme.onPrimary;
    return Hoverable(
      onTap: onPressed,
      builder: (context, {required hovered}) {
        final filled = hovered || selected;
        // `color` is dropped when `decoration` is set, so the fill lives on
        // an inner Container nested inside the bordered one.
        final face = Container(
          color: filled ? accent : null,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? onAccent : accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        if (dense) return face;
        return Container(
          decoration: BoxDecoration(border: BoxBorder.all(color: accent)),
          child: face,
        );
      },
    );
  }
}
