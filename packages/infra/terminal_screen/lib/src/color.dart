import 'package:meta/meta.dart';

/// A terminal cell color. One of four variants:
///
///   * [DefaultForeground] — "use whatever the user's color scheme
///     says the default foreground is."
///   * [DefaultBackground] — same for background.
///   * [IndexedColor] — one of the 256 indexed colors (0..15 are the
///     ANSI base + bright palette; 16..231 are the 6×6×6 color cube;
///     232..255 are the grayscale ramp).
///   * [RgbColor] — 24-bit truecolor.
///
/// Sealed so callers can `switch` exhaustively.
@immutable
sealed class Color {
  const Color();

  /// The default foreground sentinel.
  static const Color defaultFg = DefaultForeground._();

  /// The default background sentinel.
  static const Color defaultBg = DefaultBackground._();
}

/// Terminal default foreground.
final class DefaultForeground extends Color {
  const DefaultForeground._();

  @override
  bool operator ==(Object other) => other is DefaultForeground;

  @override
  int get hashCode => (DefaultForeground).hashCode;

  @override
  String toString() => 'DefaultForeground';
}

/// Terminal default background.
final class DefaultBackground extends Color {
  const DefaultBackground._();

  @override
  bool operator ==(Object other) => other is DefaultBackground;

  @override
  int get hashCode => (DefaultBackground).hashCode;

  @override
  String toString() => 'DefaultBackground';
}

/// One of the 256 indexed colors.
final class IndexedColor extends Color {
  /// Create an indexed color. [index] must be in `0..255`.
  const IndexedColor(this.index)
    : assert(index >= 0 && index <= 255, 'index out of range');

  /// The palette index.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is IndexedColor && other.index == index;

  @override
  int get hashCode => Object.hash(IndexedColor, index);

  @override
  String toString() => 'IndexedColor($index)';
}

/// A 24-bit truecolor.
final class RgbColor extends Color {
  /// Create a truecolor. Each channel must be in `0..255`.
  const RgbColor(this.r, this.g, this.b)
    : assert(r >= 0 && r <= 255, 'r out of range'),
      assert(g >= 0 && g <= 255, 'g out of range'),
      assert(b >= 0 && b <= 255, 'b out of range');

  /// Red channel.
  final int r;

  /// Green channel.
  final int g;

  /// Blue channel.
  final int b;

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(RgbColor, r, g, b);

  @override
  String toString() => 'RgbColor($r, $g, $b)';
}
