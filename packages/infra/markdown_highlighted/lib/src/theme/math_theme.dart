import 'package:collection/collection.dart';
import 'package:math_render/math_render.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

const _styleEquality = ListEquality<TextStyle>();

/// How math is coloured: what the slots *mean* ([tagger]) and what they look
/// like ([slotStyles]).
///
/// Compares by value, so a theme derived fresh on every build is still
/// recognized as the one already rendered.
@immutable
class MathTheme {
  /// Creates a theme from a tagging rule and a slot cycle.
  const MathTheme({this.tagger = tagNothing, this.slotStyles = const []});

  /// What the slots mean. Runs over the parsed expression before layout.
  final MathTagger tagger;

  /// Styles cycled across slots. Empty paints nothing.
  final List<TextStyle> slotStyles;

  /// Paints nothing at all: the rendering is exactly the picture, with
  /// whatever style surrounds it. Equivalent to not colorizing.
  static const MathTheme none = MathTheme();

  /// Whether this theme would paint anything.
  bool get isPlain => slotStyles.isEmpty;

  /// The style for [slot], or null when nothing should be painted — the
  /// surrounding span's colour then shows through unchanged.
  TextStyle? styleFor(int? slot) => slot == null || slotStyles.isEmpty
      ? null
      : slotStyles[slot % slotStyles.length];

  @override
  bool operator ==(Object other) =>
      other is MathTheme &&
      other.tagger == tagger &&
      _styleEquality.equals(other.slotStyles, slotStyles);

  @override
  int get hashCode => Object.hash(tagger, _styleEquality.hash(slotStyles));
}
