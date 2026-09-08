import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/timeline_marker.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The model in play from a point in the transcript on, drawn as a one-line
/// marker: a phase glyph, the provider, and the model's name.
@view
class ModelCardItem extends StatelessComponent {
  const ModelCardItem({
    required this.card,
    required this.selected,
    this.hovered = false,
    super.key,
  });

  final ModelSnapshot card;
  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final mark = _PhaseMark.of(card.phase, theme);

    return TimelineMarker(
      selected: selected,
      hovered: hovered,
      label: TextSpan(
        children: [
          TextSpan(
            text: '${mark.glyph} ',
            style: TextStyle(color: mark.color),
          ),
          TextSpan(
            text: card.provider,
            style: TextStyle(color: theme.primary),
          ),
          TextSpan(
            text: ' ◆ ',
            style: TextStyle(color: theme.muted),
          ),
          TextSpan(text: card.displayName),
          if (card.error case final error?)
            TextSpan(
              text: ' · $error',
              style: TextStyle(color: theme.error),
            ),
        ],
      ),
    );
  }
}

/// The glyph that leads the marker, colored for the model's phase.
@model
final class _PhaseMark {
  const _PhaseMark({required this.glyph, required this.color});

  factory _PhaseMark.of(ModelCardPhase phase, AppThemeData theme) =>
      switch (phase) {
        ModelCardPhase.loading => _PhaseMark(glyph: '◑', color: theme.loading),
        ModelCardPhase.ready => _PhaseMark(glyph: '●', color: theme.success),
        ModelCardPhase.failed => _PhaseMark(glyph: '✕', color: theme.error),
      };

  final String glyph;
  final Color color;
}
