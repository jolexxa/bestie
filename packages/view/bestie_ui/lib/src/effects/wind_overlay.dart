import 'dart:async';
import 'dart:math' as math;

import 'package:bestie_ui/src/effects/overlay_tick.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas isn't in nocterm's public exports; mirrors the direct
// import used by guttered.dart and nocterm's own renders.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';

const String _pastureThemeName = 'Pasture';

const Color _moteBright = Color(0xFFE468);
const Color _moteMid = Color(0xE8C040);
const Color _moteDim = Color(0xA08820);

const List<String> _moteChars = <String>['.', '*'];

const int _maxMotes = 20;
const double _spawnProbability = 0.32;

// --- Wind sim --------------------------------------------------------------
// A single global wind field drives all motes. It gusts via a slow sine
// (windX) with a smaller orthogonal sine for vertical sway (windY). Each
// mote integrates its own velocity, steering toward the wind force scaled
// by its parallax tier — closer motes respond more, distant ones drift
// sluggishly. Per-particle turbulence keeps the field from looking too
// uniform.

const double _windBaseSpeed = 0.70;
const double _windGustAmp = 0.36;
const double _windGustSpeed = 0.042;
const double _verticalWindAmp = 0.072;
const double _turbulenceX = 0.12;
const double _turbulenceY = 0.06;

double _tierScale(int tier) => switch (tier) {
  0 => 1.0,
  1 => 0.65,
  _ => 0.40,
};

@view
class WindOverlay extends StatefulComponent {
  const WindOverlay({super.key});

  @override
  State<WindOverlay> createState() => _WindOverlayState();
}

class _WindOverlayState extends State<WindOverlay> {
  Timer? _timer;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPasture = AppTheme.of(context).name == _pastureThemeName;
    if (isPasture && _timer == null) {
      _timer = Timer.periodic(overlayTickInterval, (_) {
        if (!mounted) return;
        setState(() => _tick++);
      });
    } else if (!isPasture && _timer != null) {
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
    if (AppTheme.of(context).name != _pastureThemeName) {
      return const SizedBox.shrink();
    }
    return _WindField(tick: _tick);
  }
}

class _WindField extends SingleChildRenderObjectComponent {
  const _WindField({required this.tick});

  final int tick;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderWindField(tick: tick);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWindField renderObject,
  ) {
    renderObject.tick = tick;
  }
}

class _Mote {
  _Mote({
    required this.col,
    required this.row,
    required this.vx,
    required this.vy,
    required this.responsiveness,
    required this.char,
    required this.colorTier,
  });

  double col;
  double row;
  double vx;
  double vy;
  // 0..1 — how quickly the mote's velocity converges on the wind force.
  // Lighter/responsive motes whip around, heavier ones glide.
  final double responsiveness;
  final String char;
  // 0 = near (bright/fast), 1 = mid, 2 = far (dim/sluggish).
  final int colorTier;
}

class _RenderWindField extends RenderObject {
  _RenderWindField({required int tick}) : _tick = tick;

  int _tick;
  double _windPhase = 0;
  final math.Random _rng = math.Random();
  final List<_Mote> _motes = <_Mote>[];

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

    _windPhase += _windGustSpeed;
    final windX = _windBaseSpeed + math.sin(_windPhase) * _windGustAmp;
    final windY = math.sin(_windPhase * 0.7) * _verticalWindAmp;

    if (_motes.length < _maxMotes && _rng.nextDouble() < _spawnProbability) {
      final tier = _rng.nextInt(3);
      final scale = _tierScale(tier);
      _motes.add(
        _Mote(
          col: -1,
          row: _rng.nextDouble() * rows,
          vx: windX * scale,
          vy: 0,
          responsiveness: 0.12 + _rng.nextDouble() * 0.12,
          char: _moteChars[_rng.nextInt(_moteChars.length)],
          colorTier: tier,
        ),
      );
    }

    for (var i = _motes.length - 1; i >= 0; i--) {
      final mote = _motes[i];
      final scale = _tierScale(mote.colorTier);
      final targetVx = windX * scale + (_rng.nextDouble() - 0.5) * _turbulenceX;
      final targetVy = windY * scale + (_rng.nextDouble() - 0.5) * _turbulenceY;
      mote
        ..vx = mote.vx + (targetVx - mote.vx) * mote.responsiveness
        ..vy = mote.vy + (targetVy - mote.vy) * mote.responsiveness
        ..col += mote.vx
        ..row += mote.vy;

      if (mote.col >= cols ||
          mote.col < -2 ||
          mote.row < -2 ||
          mote.row >= rows + 2) {
        _motes.removeAt(i);
      }
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    final rows = size.height.floor();
    final cols = size.width.floor();
    if (rows <= 0 || cols <= 0) return;

    for (final mote in _motes) {
      final x = mote.col.floor();
      final y = mote.row.floor();
      if (x < 0 || x >= cols || y < 0 || y >= rows) continue;
      final color = switch (mote.colorTier) {
        0 => _moteBright,
        1 => _moteMid,
        _ => _moteDim,
      };
      // drawText (not setRaw) so the existing cell's background is
      // preserved — the mote is just a colored glyph, not a tinted square.
      canvas.drawText(
        offset + Offset(x.toDouble(), y.toDouble()),
        mote.char,
        style: TextStyle(color: color),
      );
    }
  }
}
