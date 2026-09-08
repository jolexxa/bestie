import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A full-width rule with an inset label, marking a point in the transcript
/// rather than a message. [body] renders beneath the rule when given.
///
/// The rules brighten while [hovered] and turn primary while [selected],
/// when the label also goes bold so the user can see they've parked on the
/// marker during page-up/down navigation. The label's colors are its own.
@view
class TimelineMarker extends StatelessComponent {
  const TimelineMarker({
    required this.label,
    required this.selected,
    this.hovered = false,
    this.body,
    super.key,
  });

  final TextSpan label;
  final bool selected;
  final bool hovered;
  final Component? body;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final ruleColor = selected
        ? theme.primary
        : hovered
        ? theme.muted
        : theme.outline;
    final labelStyle = selected
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: ruleColor)),
              const SizedBox(width: 1),
              RichText(
                text: TextSpan(style: labelStyle, children: [label]),
              ),
              const SizedBox(width: 1),
              Expanded(child: Container(height: 1, color: ruleColor)),
            ],
          ),
          if (body case final Component body) body,
        ],
      ),
    );
  }
}
