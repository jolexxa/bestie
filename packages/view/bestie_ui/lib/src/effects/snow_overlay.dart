import 'dart:async';
import 'dart:math' as math;

import 'package:bestie_ui/src/effects/overlay_tick.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:bestie_ui/src/theme/theme_presets.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas isn't in nocterm's public exports; mirrors the direct
// import used by guttered.dart and nocterm's own renders.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';

final String _themeName = santa.name;

const Color _flakeBright = Color(0xFFFFFF);
const Color _flakeMid = Color(0xD8DCE8);
const Color _flakeDim = Color(0x8890A0);

const List<String> _flakeChars = <String>['*', '.', '•'];

const int _maxFlakes = 20;
const double _spawnProbability = 0.35;

@view
class SnowOverlay extends StatefulComponent {
  const SnowOverlay({super.key});

  @override
  State<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends State<SnowOverlay> {
  Timer? _timer;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isSanta = AppTheme.of(context).name == _themeName;
    if (isSanta && _timer == null) {
      _timer = Timer.periodic(overlayTickInterval, (_) {
        if (!mounted) return;
        setState(() => _tick++);
      });
    } else if (!isSanta && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    if (AppTheme.of(context).name != _themeName) {
      return const SizedBox.shrink();
    }
    return _SnowField(tick: _tick);
  }
}

class _SnowField extends SingleChildRenderObjectComponent {
  const _SnowField({required this.tick});

  final int tick;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSnowField(tick: tick);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSnowField renderObject,
  ) {
    renderObject.tick = tick;
  }
}

class _Flake {
  _Flake({
    required this.col,
    required this.row,
    required this.fallStep,
    required this.driftBias,
    required this.char,
    required this.colorTier,
  });

  double col;
  double row;
  // Rows per tick (sub-1.0 for slow drift).
  final double fallStep;
  // -1, 0, or 1 — gentle horizontal drift bias.
  final int driftBias;
  final String char;
  // 0 = bright, 1 = mid, 2 = dim — gives parallax depth.
  final int colorTier;
}

class _RenderSnowField extends RenderObject {
  _RenderSnowField({required int tick}) : _tick = tick;

  int _tick;
  final math.Random _rng = math.Random();
  final List<_Flake> _flakes = <_Flake>[];

  int get tick => _tick;
  set tick(int value) {
    if (_tick == value) return;
    _tick = value;
    _advance();
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  void _advance() {
    final rows = size.height.floor();
    final cols = size.width.floor();
    if (rows <= 0 || cols <= 0) return;

    // Spawn new flakes at the top.
    if (_flakes.length < _maxFlakes && _rng.nextDouble() < _spawnProbability) {
      final tier = _rng.nextInt(3);
      _flakes.add(
        _Flake(
          col: _rng.nextDouble() * cols,
          row: 0,
          // Brighter/closer flakes fall faster.
          fallStep: tier == 0
              ? 0.52 + _rng.nextDouble() * 0.38
              : tier == 1
              ? 0.34 + _rng.nextDouble() * 0.26
              : 0.21 + _rng.nextDouble() * 0.17,
          driftBias: _rng.nextInt(3) - 1,
          char: _flakeChars[_rng.nextInt(_flakeChars.length)],
          colorTier: tier,
        ),
      );
    }

    // Advance + recycle.
    for (var i = _flakes.length - 1; i >= 0; i--) {
      final flake = _flakes[i];
      flake.row += flake.fallStep;
      // Occasional sideways drift.
      if (_rng.nextDouble() < 0.18) {
        flake.col += flake.driftBias * 0.5;
      }
      if (flake.row.floor() >= rows || flake.col < 0 || flake.col >= cols) {
        _flakes.removeAt(i);
      }
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    final rows = size.height.floor();
    final cols = size.width.floor();
    if (rows <= 0 || cols <= 0) return;

    for (final flake in _flakes) {
      final x = flake.col.floor();
      final y = flake.row.floor();
      if (x < 0 || x >= cols || y < 0 || y >= rows) continue;
      final color = switch (flake.colorTier) {
        0 => _flakeBright,
        1 => _flakeMid,
        _ => _flakeDim,
      };
      // drawText (not setRaw) so the existing cell's background is
      // preserved — the flake is just a colored glyph, not a tinted square.
      canvas.drawText(
        offset + Offset(x.toDouble(), y.toDouble()),
        flake.char,
        style: TextStyle(color: color),
      );
    }
  }
}
