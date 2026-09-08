import 'package:nocterm/nocterm.dart';

extension ColorPercent on Color {
  /// Lerps across four stops based on a [percent] value (0–100):
  /// [high] (100%) → [mid] (50%) → [low] (25%) → [critical] (0%).
  static Color forPercent({
    required int percent,
    required Color high,
    required Color mid,
    required Color low,
    required Color critical,
  }) {
    if (percent >= 50) {
      return Color.lerp(mid, high, (percent - 50) / 50.0)!;
    }
    if (percent >= 25) {
      return Color.lerp(low, mid, (percent - 25) / 25.0)!;
    }
    return Color.lerp(critical, low, percent / 25.0)!;
  }
}
