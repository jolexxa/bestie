import 'dart:math' as math;

import 'package:bestie_ui/src/controls/loading/inline_spinner.dart';
import 'package:bestie_ui/src/effects/glitter_clock.dart';
import 'package:bestie_ui/src/effects/glitter_field.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A one-row strip of gently sparkling glitter on the theme's secondary, with
/// a [leading] reading at the left and a quieter [trailing] one at the right.
/// While something is [busy], a spinner and its label sit just inside the
/// trailing reading. The nameplate's accent sibling, for status that should
/// always be in view.
@view
class StatusBand extends StatefulComponent {
  const StatusBand({
    this.leading = '',
    this.trailing = '',
    this.busy,
    this.random,
    super.key,
  });

  /// Rows the band occupies.
  static const int height = 1;

  /// Cells between each edge of the band and its text.
  static const int inset = 1;

  /// How far [trailing] fades from the text color toward the fill.
  static const double trailingFade = 0.4;

  /// Separates the busy label from the trailing reading.
  static const String separator = ' · ';

  /// Set at the left in the full text-on-secondary color.
  final String leading;

  /// Set at the right, faded toward the fill.
  final String trailing;

  /// What is still in progress, spun beside; null when nothing is.
  final String? busy;

  /// Passed through to the glitter for deterministic tests.
  final math.Random? random;

  @override
  State<StatusBand> createState() => _StatusBandState();
}

class _StatusBandState extends State<StatusBand> with GlitterClock {
  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final busy = component.busy;
    final trailingStyle = TextStyle(
      color: Color.lerp(
        theme.onSecondary,
        theme.secondary,
        StatusBand.trailingFade,
      ),
      backgroundColor: theme.secondary,
    );
    return SizedBox(
      height: StatusBand.height.toDouble(),
      child: Stack(
        children: [
          Positioned.fill(
            child: GlitterField(
              tick: tick,
              random: component.random,
              palette: GlitterPalette.secondary,
            ),
          ),
          Positioned(
            left: StatusBand.inset.toDouble(),
            top: 0,
            child: Text(
              component.leading,
              style: TextStyle(
                color: theme.onSecondary,
                backgroundColor: theme.secondary,
              ),
            ),
          ),
          Positioned(
            right: StatusBand.inset.toDouble(),
            top: 0,
            child: Row(
              children: [
                if (busy != null) ...[
                  InlineSpinner(
                    color: theme.onSecondary,
                    backgroundColor: theme.secondary,
                  ),
                  Text(
                    ' $busy${StatusBand.separator}',
                    style: TextStyle(
                      color: theme.onSecondary,
                      backgroundColor: theme.secondary,
                    ),
                  ),
                ],
                Text(component.trailing, style: trailingStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
