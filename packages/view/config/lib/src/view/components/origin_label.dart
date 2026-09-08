import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Small presentation value: the inline source label rendered next to a
/// config field's name, with the color it should be drawn in.
@view
class OriginLabel {
  const OriginLabel({required this.text, required this.color});

  /// Short, human-readable description (e.g. `'overridden'`,
  /// `'model default'`).
  final String text;

  /// Color the label should be drawn in.
  final Color color;
}
