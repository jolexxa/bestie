import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Shared one-line layout for an activity stub (a reasoning run or tool call)
/// in the chat list: a status glyph — or a spinner while [running] — followed
/// by [label], wrapped in the selection gutter so it highlights like a message
/// row and aligns to the same left margin.
@view
class ActivityStubRow extends StatelessComponent {
  const ActivityStubRow({
    required this.running,
    required this.accent,
    required this.glyph,
    required this.label,
    this.secondLine,
    this.selected = false,
    this.hovered = false,
    super.key,
  });

  final bool running;

  /// Color of the leading glyph / spinner — the call's status color.
  final Color accent;

  /// Glyph shown when not [running].
  final String glyph;

  final Component label;

  /// Optional line rendered under [label], indented within the same selection
  /// tint — used for the live prefill progress bar on a running reasoning stub.
  final Component? secondLine;

  final bool selected;
  final bool hovered;

  @override
  Component build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 1),
        SizedBox(
          width: 1,
          child: running
              ? InlineSpinner(color: accent)
              : Text(glyph, style: TextStyle(color: accent)),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: SelectionGutter(
            selected: selected,
            hovered: hovered,
            child: secondLine == null
                ? label
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, secondLine!],
                  ),
          ),
        ),
      ],
    );
  }
}
