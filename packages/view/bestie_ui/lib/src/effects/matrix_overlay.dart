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

final String _themeName = neo.name;

const Color _headColor = Color(0xCCFFCC);
const Color _brightTail = Color(0x00FF41);
const Color _midTail = Color(0x008822);
const Color _dimTail = Color(0x004A14);

const double _spawnProbability = 0.005;
const double _minSpeed = 0.5;
const double _maxSpeed = 1.5;

@view
class MatrixOverlay extends StatefulComponent {
  const MatrixOverlay({super.key});

  @override
  State<MatrixOverlay> createState() => _MatrixOverlayState();
}

class _MatrixOverlayState extends State<MatrixOverlay> {
  Timer? _timer;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isMatrix = AppTheme.of(context).name == _themeName;
    if (isMatrix && _timer == null) {
      _timer = Timer.periodic(overlayTickInterval, (_) {
        if (!mounted) return;
        setState(() => _tick++);
      });
    } else if (!isMatrix && _timer != null) {
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
    return _MatrixRain(tick: _tick);
  }
}

class _MatrixRain extends SingleChildRenderObjectComponent {
  const _MatrixRain({required this.tick});

  final int tick;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMatrixRain(tick: tick);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMatrixRain renderObject,
  ) {
    renderObject.tick = tick;
  }
}

class _Drop {
  _Drop({
    required this.headRow,
    required this.chars,
    required this.speed,
  });
  int headRow;
  final List<String> chars;
  final double speed;
  double progress = 0;
}

class _RenderMatrixRain extends RenderObject {
  _RenderMatrixRain({required int tick}) : _tick = tick;

  int _tick;
  final math.Random _rng = math.Random();
  List<_Drop?> _drops = const <_Drop?>[];
  int _columns = 0;

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
    final newColumns = size.width.floor();
    if (newColumns != _columns) {
      _columns = newColumns;
      _drops = List<_Drop?>.filled(_columns, null);
    }
  }

  void _advance() {
    final rows = size.height.floor();
    if (rows <= 0 || _columns <= 0) return;

    for (var c = 0; c < _columns; c++) {
      final drop = _drops[c];
      if (drop == null) {
        if (_rng.nextDouble() < _spawnProbability) {
          _drops[c] = _Drop(
            headRow: 0,
            chars: <String>[_randomChar()],
            speed: _minSpeed + _rng.nextDouble() * (_maxSpeed - _minSpeed),
          );
        }
        continue;
      }
      drop.progress += drop.speed;
      while (drop.progress >= 1) {
        drop.progress -= 1;
        drop.headRow++;
        drop.chars.insert(0, _randomChar());
        if (drop.chars.length > 4) {
          drop.chars.removeLast();
        }
      }
      // Recycle once the entire trail has fallen off the bottom.
      if (drop.headRow - drop.chars.length > rows) {
        _drops[c] = null;
      }
    }
  }

  String _randomChar() => String.fromCharCode(33 + _rng.nextInt(94));

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    final rows = size.height.floor();
    if (rows <= 0 || _columns <= 0) return;

    final ox = offset.dx.round();
    final oy = offset.dy.round();

    for (var c = 0; c < _columns; c++) {
      final drop = _drops[c];
      if (drop == null) continue;
      for (var i = 0; i < drop.chars.length; i++) {
        final row = drop.headRow - i;
        if (row < 0 || row >= rows) continue;
        final color = switch (i) {
          0 => _headColor,
          1 => _brightTail,
          2 => _midTail,
          _ => _dimTail,
        };
        canvas.setRaw(
          ox + c,
          oy + row,
          Cell(
            char: drop.chars[i],
            style: TextStyle(color: color),
          ),
        );
      }
    }
  }
}
