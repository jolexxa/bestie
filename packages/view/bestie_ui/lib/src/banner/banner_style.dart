import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Visual style for a banner notification.
///
/// Each style resolves to a body color, a darker accent gutter color, and
/// the appropriate "on" text color from the active app theme.
enum BannerStyle {
  /// Primary-themed banner. The default.
  normal,

  /// Informational banner (info palette).
  info,

  /// Success banner (success palette).
  success,

  /// Error banner (error palette).
  error,

  /// De-emphasized/muted banner.
  muted,
}

/// Resolved colors for rendering a banner of a particular [BannerStyle]
/// against the active app theme.
@model
class BannerPalette {
  /// Creates a [BannerPalette].
  const BannerPalette({
    required this.body,
    required this.gutter,
    required this.onBody,
  });

  /// Background color for the message area.
  final Color body;

  /// Background color for the leading icon gutter (a darker accent).
  final Color gutter;

  /// Foreground color for text and icon glyphs.
  final Color onBody;
}
