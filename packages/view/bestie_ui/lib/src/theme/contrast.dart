import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// WCAG 2 relative luminance and contrast ratios.
extension ColorContrast on Color {
  double get relativeLuminance =>
      0.2126 * _linear(red) + 0.7152 * _linear(green) + 0.0722 * _linear(blue);

  /// The contrast ratio between this color and [other], from 1 to 21.
  double contrastWith(Color other) {
    final a = relativeLuminance;
    final b = other.relativeLuminance;
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  static double _linear(int channel) {
    final fraction = channel / 255;
    return fraction <= 0.03928
        ? fraction / 12.92
        : math.pow((fraction + 0.055) / 1.055, 2.4).toDouble();
  }
}
