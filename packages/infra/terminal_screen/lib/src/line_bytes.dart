import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Told about a line as it leaves, as three arguments rather than an object so
/// nothing is allocated for it, describing buffers reused for the next line —
/// so a listener that means to keep them copies them first.
typedef LineSink = void Function(Uint8List text, Uint8List pen, int units);

/// A line of terminal output as bytes, kept in two halves because most readers
/// want only the first.
@immutable
final class LineBytes {
  /// A line reading [text], drawn as [pen] describes, [units] wide.
  const LineBytes({
    required this.text,
    required this.pen,
    required this.units,
  });

  /// The line's text, as UTF-8.
  final Uint8List text;

  /// The pen behind it, as `pen_codec` writes runs. Empty means the default
  /// pen from end to end.
  final Uint8List pen;

  /// UTF-16 code units in [text], which is what everything above measures
  /// text in and what UTF-8 bytes cannot be counted as.
  final int units;
}
