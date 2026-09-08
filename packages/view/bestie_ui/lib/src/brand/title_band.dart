import 'dart:math' as math;

import 'package:bestie_ui/src/brand/app_info.dart';
import 'package:bestie_ui/src/controls/block_font.dart';
import 'package:bestie_ui/src/effects/glitter_clock.dart';
import 'package:bestie_ui/src/effects/glitter_field.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The app's nameplate: three rows of gently sparkling glitter on the
/// theme's primary with the app name in block letters and the version set
/// quietly beside it.
@view
class TitleBand extends StatefulComponent {
  const TitleBand({
    required this.version,
    this.title = 'Bestie',
    this.random,
    super.key,
  });

  /// Rows the band occupies: the block font's height.
  static const int height = 3;

  /// Cells between the band's left edge and the title.
  static const int inset = 2;

  /// Cells between the block letters and the version.
  static const int gap = 2;

  /// How far the version fades from the title color toward the fill.
  static const double versionFade = 0.4;

  final String title;

  /// Shown as [AppInfo.version] is: plain text on the band's middle row.
  final String version;

  /// Passed through to the glitter for deterministic tests.
  final math.Random? random;

  @override
  State<TitleBand> createState() => _TitleBandState();
}

class _TitleBandState extends State<TitleBand> with GlitterClock {
  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: TitleBand.height.toDouble(),
      child: Stack(
        children: [
          Positioned.fill(
            child: GlitterField(tick: tick, random: component.random),
          ),
          Positioned(
            left: TitleBand.inset.toDouble(),
            top: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AsciiText(
                  component.title,
                  font: const BlockFont(),
                  style: TextStyle(
                    color: theme.onPrimary,
                    backgroundColor: theme.primary,
                  ),
                ),
                SizedBox(width: TitleBand.gap.toDouble()),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    component.version,
                    style: TextStyle(
                      color: Color.lerp(
                        theme.onPrimary,
                        theme.primary,
                        TitleBand.versionFade,
                      ),
                      backgroundColor: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
