import 'dart:math' as math;

import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas isn't in nocterm's public exports; mirrors the direct
// import used by the other effect overlays.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// Cells per live sparkle; the field keeps about this many twinkling.
const int glitterCellsPerSparkle = 6;

/// Most sparkles alive at once, however wide the field.
const int glitterMaxSparkles = 48;

/// Typical ticks a sparkle takes to brighten from the base glyph to its
/// peak; each sparkle draws its own between half and one and a half of this.
const int glitterRiseTicks = 8;

/// Typical ticks a sparkle takes to fade from its peak back to the base
/// glyph; each sparkle draws its own the same way.
const int glitterFallTicks = 10;

/// Longest a fresh sparkle rests, unseen, before it starts to rise, so
/// sparkles never come on in step.
const int glitterRestTicks = 16;

/// Glyphs from the resting field up to a sparkle's peak.
const List<String> glitterGlyphs = <String>['░', '▒', '▓', '█'];

/// How far the resting glyph sinks from the fill toward the text-on-fill.
const double _restingGlyphMix = 0.3;

/// How far a rising sparkle climbs from the fill toward the body text color.
const double _risingGlyphMix = 0.5;

/// The colors a [GlitterField] paints with, resolved once from a theme.
@model
@immutable
final class GlitterPalette {
  const GlitterPalette({
    required this.fill,
    required this.resting,
    required this.rising,
    required this.peak,
  });

  /// One hue, three tones: the field sits on the theme's primary, resting
  /// glyphs sink a little toward the text-on-primary, and sparkles climb the
  /// same hue toward the body text color so nothing clashes.
  factory GlitterPalette.of(AppThemeData theme) => GlitterPalette._tones(
    fill: theme.primary,
    onFill: theme.onPrimary,
    text: theme.onBackground,
  );

  /// The same three tones built on the theme's secondary, for a band that
  /// should read as an accent rather than the nameplate.
  factory GlitterPalette.secondary(AppThemeData theme) => GlitterPalette._tones(
    fill: theme.secondary,
    onFill: theme.onSecondary,
    text: theme.onBackground,
  );

  /// The same three tones built on the theme's error color, for a band that
  /// must be noticed before anything else on screen.
  factory GlitterPalette.error(AppThemeData theme) => GlitterPalette._tones(
    fill: theme.error,
    onFill: theme.onError,
    text: theme.onBackground,
  );

  factory GlitterPalette._tones({
    required Color fill,
    required Color onFill,
    required Color text,
  }) => GlitterPalette(
    fill: fill,
    resting: Color.lerp(fill, onFill, _restingGlyphMix) ?? fill,
    rising: Color.lerp(fill, text, _risingGlyphMix) ?? fill,
    peak: text,
  );

  final Color fill;
  final Color resting;
  final Color rising;
  final Color peak;

  /// The glyph color for a sparkle at [level] 0 (resting) through 3 (peak).
  Color at(int level) => switch (level) {
    0 => resting,
    1 => Color.lerp(resting, rising, 0.5) ?? rising,
    2 => rising,
    _ => peak,
  };

  @override
  bool operator ==(Object other) =>
      other is GlitterPalette &&
      other.fill == fill &&
      other.resting == resting &&
      other.rising == rising &&
      other.peak == peak;

  @override
  int get hashCode => Object.hash(fill, resting, rising, peak);
}

/// A field of block cells on the theme's primary that twinkle gently: a
/// sparse set of sparkles ease up through brighter glyphs and colors, fade
/// back, and respawn elsewhere.
///
/// Time is driven from outside through [tick]; the field itself never
/// schedules anything, so a still frame is just a fixed tick.
@view
class GlitterField extends StatelessComponent {
  const GlitterField({
    required this.tick,
    this.random,
    this.palette,
    super.key,
  });

  /// Monotonic frame counter. Tick 0 is the untouched resting field.
  final int tick;

  /// Which tones the field is built from; the theme's primary when null.
  final GlitterPalette Function(AppThemeData theme)? palette;

  /// Source of sparkle positions and ages; injectable for deterministic
  /// tests.
  final math.Random? random;

  @override
  Component build(BuildContext context) => _GlitterFieldRender(
    tick: tick,
    random: random ?? math.Random(),
    palette: (palette ?? GlitterPalette.of)(AppTheme.of(context)),
  );
}

class _GlitterFieldRender extends SingleChildRenderObjectComponent {
  const _GlitterFieldRender({
    required this.tick,
    required this.random,
    required this.palette,
  });

  final int tick;
  final math.Random random;
  final GlitterPalette palette;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlitterField(tick: tick, random: random, palette: palette);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGlitterField renderObject,
  ) {
    renderObject
      ..palette = palette
      ..tick = tick;
  }
}

class _Sparkle {
  _Sparkle({
    required this.col,
    required this.row,
    required this.rise,
    required this.fall,
    required this.age,
  });

  /// A sparkle with its own pace, resting for a random while before it
  /// shows, or already part way through its life when [staggered].
  factory _Sparkle.spawn(
    math.Random random, {
    required int col,
    required int row,
    required bool staggered,
  }) {
    final rise = _jitter(random, glitterRiseTicks);
    final fall = _jitter(random, glitterFallTicks);
    return _Sparkle(
      col: col,
      row: row,
      rise: rise,
      fall: fall,
      age: staggered
          ? random.nextInt(rise + fall)
          : -random.nextInt(glitterRestTicks + 1),
    );
  }

  /// Between half and one and a half of [typical], never under one.
  static int _jitter(math.Random random, int typical) =>
      math.max(1, typical ~/ 2 + random.nextInt(typical + 1));

  /// Longest any sparkle can take from spawn to death.
  static const int longestLife =
      glitterRestTicks + (glitterRiseTicks + glitterFallTicks) * 3 ~/ 2 + 2;

  final int col;
  final int row;
  final int rise;
  final int fall;

  /// Ticks since it began to rise; negative while it still rests.
  int age;

  bool get dead => age >= rise + fall;

  /// 0 (resting) through 3 (peak), rising then falling with [age].
  int get level {
    if (age < 0) return 0;
    final intensity = age < rise ? age / rise : 1 - (age - rise) / fall;
    return (intensity * (glitterGlyphs.length - 1)).round().clamp(
      0,
      glitterGlyphs.length - 1,
    );
  }
}

class _RenderGlitterField extends RenderObject {
  _RenderGlitterField({
    required int tick,
    required this.random,
    required GlitterPalette palette,
  }) : _tick = tick,
       _pendingTicks = tick,
       _palette = palette;

  final math.Random random;
  final List<_Sparkle> _sparkles = <_Sparkle>[];

  int _tick;

  /// Advances owed to the field but not yet applied, because they can only
  /// be settled once the field has a size.
  int _pendingTicks;

  GlitterPalette _palette;

  GlitterPalette get palette => _palette;
  set palette(GlitterPalette value) {
    if (_palette == value) return;
    _palette = value;
    markNeedsPaint();
  }

  int get tick => _tick;
  set tick(int value) {
    if (value == _tick) return;
    _pendingTicks += math.max(0, value - _tick);
    _tick = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  int get _rows => size.height.floor();
  int get _cols => size.width.floor();

  /// Applies owed ticks. Past the longest sparkle life the field is
  /// statistically the same, so a long gap costs one life of work.
  void _settle() {
    final steps = math.min(_pendingTicks, _Sparkle.longestLife);
    for (var step = 0; step < steps; step++) {
      _advance(staggered: _sparkles.isEmpty);
    }
    _pendingTicks = 0;
  }

  void _advance({required bool staggered}) {
    final cells = _rows * _cols;
    if (cells <= 0) return;
    for (final sparkle in _sparkles) {
      sparkle.age++;
    }
    _sparkles.removeWhere((sparkle) => sparkle.dead);
    final target = math.min(
      glitterMaxSparkles,
      cells ~/ glitterCellsPerSparkle,
    );
    while (_sparkles.length < target) {
      final free = _freeCell();
      if (free == null) break;
      _sparkles.add(
        _Sparkle.spawn(
          random,
          col: free % _cols,
          row: free ~/ _cols,
          staggered: staggered,
        ),
      );
    }
  }

  /// A random unoccupied cell index, or null when the field is full.
  int? _freeCell() {
    final occupied = {for (final s in _sparkles) s.row * _cols + s.col};
    final cells = _rows * _cols;
    if (occupied.length >= cells) return null;
    var pick = random.nextInt(cells);
    while (occupied.contains(pick)) {
      pick = (pick + 1) % cells;
    }
    return pick;
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (_rows <= 0 || _cols <= 0) return;
    _settle();
    final resting = TextStyle(
      color: _palette.resting,
      backgroundColor: _palette.fill,
    );
    for (var row = 0; row < _rows; row++) {
      canvas.drawText(
        offset + Offset(0, row.toDouble()),
        glitterGlyphs.first * _cols,
        style: resting,
      );
    }
    for (final sparkle in _sparkles) {
      if (sparkle.row >= _rows || sparkle.col >= _cols) continue;
      final level = sparkle.level;
      canvas.drawText(
        offset + Offset(sparkle.col.toDouble(), sparkle.row.toDouble()),
        glitterGlyphs[level],
        style: TextStyle(
          color: _palette.at(level),
          backgroundColor: _palette.fill,
        ),
      );
    }
  }
}
