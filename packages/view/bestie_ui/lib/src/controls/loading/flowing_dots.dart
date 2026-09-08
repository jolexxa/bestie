import 'dart:math';

import 'package:bestie_ui/src/effects/running_clock.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Ticks in one pass: every dot sent from one edge to the other.
const int flowingDotsTicksPerPass = 48;

/// How a dot moves once sent: quick through the middle, settling as it lands.
const Curve flowingDotsCurve = Curves.easeInOutCubic;

/// Track width when there is no width to fill.
const int flowingDotsDefaultWidth = 8;

/// Dots parked at the edges.
const int flowingDotsCount = 3;

/// Share of a pass between one dot leaving and the next.
const double flowingDotsStagger = 0.2;

/// Times a dot swells and shrinks while crossing.
const int flowingDotsPulsesPerFlight = 2;

const List<String> _glyphs = ['·', '•', '●'];

/// Track width for a row allowed [maxWidth] cells: all of a bounded width,
/// and [flowingDotsDefaultWidth] for an unbounded one.
int flowingDotsTrackWidth(double maxWidth) =>
    maxWidth.isFinite ? max(1, maxWidth.toInt()) : flowingDotsDefaultWidth;

/// The [width] cells of one frame: [flowingDotsCount] dots parked at one edge
/// are sent across one at a time, innermost first, each swelling and
/// shrinking on the way, and park at the far edge; the next pass sends them
/// back.
String flowingDotsFrame({required int tick, required int width}) {
  final pass = tick ~/ flowingDotsTicksPerPass;
  final time = (tick % flowingDotsTicksPerPass) / (flowingDotsTicksPerPass - 1);
  const flight = 1 - (flowingDotsCount - 1) * flowingDotsStagger;
  final cells = List.filled(width, ' ');
  for (var dot = 0; dot < flowingDotsCount; dot++) {
    final progress = ((time - dot * flowingDotsStagger) / flight).clamp(
      0.0,
      1.0,
    );
    final (from, to) = pass.isEven
        ? (flowingDotsCount - 1 - dot, width - 1 - dot)
        : (width - flowingDotsCount + dot, dot);
    final cell = (from + flowingDotsCurve.transform(progress) * (to - from))
        .round()
        .clamp(0, width - 1);
    final swell = sin(progress * pi * flowingDotsPulsesPerFlight).abs();
    final glyph = (swell * (_glyphs.length - 1)).round();
    cells[cell] = _glyphs[max(glyph, _glyphs.indexOf(cells[cell]))];
  }
  return cells.join();
}

/// Three dots sent one by one across the available width — the sign that
/// something is being spun up whose shape is not known yet.
@view
class FlowingDots extends StatefulComponent {
  const FlowingDots({super.key, this.color});

  /// Dot color. Defaults to `theme.secondary`.
  final Color? color;

  @override
  State<FlowingDots> createState() => _FlowingDotsState();
}

class _FlowingDotsState extends State<FlowingDots> with RunningClock {
  @override
  Duration get runningClockInterval => const Duration(milliseconds: 70);

  @override
  void initState() {
    super.initState();
    syncRunningClock(running: true);
  }

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final color = component.color ?? theme.secondary;
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        flowingDotsFrame(
          tick: tick,
          width: flowingDotsTrackWidth(constraints.maxWidth),
        ),
        style: TextStyle(color: color),
      ),
    );
  }
}
