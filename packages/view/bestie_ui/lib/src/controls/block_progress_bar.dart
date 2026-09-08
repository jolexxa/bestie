import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A unicode-block progress bar that fills its parent's width.
///
/// Layout-aware: measures the available width via [LayoutBuilder] and
/// renders `width` cells split between filled (`█`) and empty (`░`)
/// runs. Two-color so the empty track stays visible against the bg.
@view
class BlockProgressBar extends StatelessComponent {
  const BlockProgressBar({
    required this.fraction,
    required this.color,
    required this.track,
    super.key,
  });

  /// Filled portion, clamped to `[0, 1]` by callers.
  final double fraction;

  /// Color used for the filled portion.
  final Color color;

  /// Color used for the unfilled track.
  final Color track;

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        if (width <= 0) return const SizedBox.shrink();
        final filled = (width * fraction).round();
        final empty = width - filled;
        return Row(
          children: [
            if (filled > 0) Text('█' * filled, style: TextStyle(color: color)),
            if (empty > 0) Text('░' * empty, style: TextStyle(color: track)),
          ],
        );
      },
    );
  }
}
