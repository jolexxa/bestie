import 'package:meta/meta.dart';

/// The semantic role of a piece of pane text; the palette picks the colour.
enum PaneTone {
  /// Ordinary body text.
  plain,

  /// The app's key colour, for app-wide actions.
  primary,

  /// Supporting labels such as key names and breadcrumbs.
  secondary,

  /// Neutral facts worth a glance: sizes, counts, parameters.
  info,

  /// De-emphasised text.
  muted,

  /// Fainter than [muted], for separators.
  subtle,

  /// Something finished or healthy.
  success,

  /// Something needs a look but nothing broke.
  warning,

  /// Something failed or is destructive.
  danger,

  /// Work in progress.
  loading,

  /// Text that should stand out from its neighbours, drawn bold.
  emphasis,

  /// Eye-catching but not alarming.
  highlight,
}

/// A run of pane text in one tone.
@immutable
final class PaneSpan {
  const PaneSpan(this.text, [this.tone = PaneTone.plain]);

  final String text;
  final PaneTone tone;
}
