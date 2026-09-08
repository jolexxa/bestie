import 'package:bestie_ui/src/input/input_actions.dart';
import 'package:bestie_ui/src/input/key_action.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Renders the visible [KeyAction] labels as one muted line.
///
/// When [actions] is omitted, falls back to the merged ancestor-chain list
/// from the nearest [InputActions] scope, innermost scope first. Actions
/// are ordered by [KeyAction.index]; ties keep scope order. Hints that do
/// not fit the available width are dropped and the line ends in an
/// ellipsis.
@view
class ActionFooter extends StatelessComponent {
  const ActionFooter({this.actions, super.key});

  final List<KeyAction>? actions;

  static const String gap = '   ';
  static const String ellipsis = '…';

  @override
  Component build(BuildContext context) {
    final source = actions ?? InputActions.renderOrderOf(context);
    final labels = [
      for (final action in ordered(source))
        if (action.visible) action.footerLabel,
    ];
    final theme = AppTheme.of(context);
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) => Text(
          fit(labels, constraints.maxWidth.toInt()),
          style: TextStyle(color: theme.muted),
        ),
      ),
    );
  }

  /// Sorts [actions] by index without reordering equal indexes.
  static List<KeyAction> ordered(List<KeyAction> actions) {
    final positions = List<int>.generate(actions.length, (i) => i)
      ..sort((a, b) {
        final byIndex = (actions[a].index ?? 0).compareTo(
          actions[b].index ?? 0,
        );
        return byIndex != 0 ? byIndex : a.compareTo(b);
      });
    return [for (final position in positions) actions[position]];
  }

  /// Joins as many leading [labels] as fit in [width] cells, marking any
  /// omission with a trailing ellipsis.
  static String fit(List<String> labels, int width) {
    final kept = <String>[];
    for (final label in labels) {
      if (_width([...kept, label]) <= width) {
        kept.add(label);
        continue;
      }
      while (kept.isNotEmpty && _width([...kept, ellipsis]) > width) {
        kept.removeLast();
      }
      return [...kept, ellipsis].join(gap);
    }
    return kept.join(gap);
  }

  static int _width(List<String> parts) =>
      UnicodeWidth.stringWidth(parts.join(gap));
}

/// The one-line status row every full-screen page ends with: an optional
/// [leading] indicator, then the action hints.
@view
class PageFooter extends StatelessComponent {
  const PageFooter({this.actions, this.leading, super.key});

  final List<KeyAction>? actions;

  /// Drawn ahead of the hints, separated by [ActionFooter.gap].
  final Component? leading;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          if (leading case final Component leading) ...[
            leading,
            const Text(ActionFooter.gap),
          ],
          Expanded(child: ActionFooter(actions: actions)),
        ],
      ),
    ),
  );
}
