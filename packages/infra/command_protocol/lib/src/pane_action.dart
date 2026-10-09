import 'package:command_protocol/src/command.dart';
import 'package:command_protocol/src/pane.dart';
import 'package:meta/meta.dart';

/// The key that runs a pane action.
@immutable
sealed class PaneKey {
  const PaneKey();
}

/// Enter: the row's main action.
final class PrimaryKey extends PaneKey {
  const PrimaryKey();

  @override
  bool operator ==(Object other) => other is PrimaryKey;

  @override
  int get hashCode => (PrimaryKey).hashCode;
}

/// A single printable character, e.g. `d`.
final class CharKey extends PaneKey {
  const CharKey(this.char);

  final String char;

  @override
  bool operator ==(Object other) => other is CharKey && other.char == char;

  @override
  int get hashCode => char.hashCode;
}

/// Something the user can do to a pane row with one key.
@immutable
final class PaneAction {
  const PaneAction({
    required this.key,
    required this.label,
    required this.invoke,
    this.danger = false,
  });

  /// The row's main action, run on Enter.
  const PaneAction.primary({
    required this.label,
    required this.invoke,
    this.danger = false,
  }) : key = const PrimaryKey();

  final PaneKey key;

  /// The footer hint, e.g. `Delete`.
  final String label;

  /// Whether the action destroys something.
  final bool danger;

  final Future<PaneActionResult> Function() invoke;

  bool get primary => key is PrimaryKey;
}

/// What the palette does once a pane action finishes.
@immutable
sealed class PaneActionResult {
  const PaneActionResult();
}

/// Keep showing the pane; its content stream reflects any change.
final class PaneStay extends PaneActionResult {
  const PaneStay();
}

/// Dismiss the palette.
final class PaneClose extends PaneActionResult {
  const PaneClose();
}

/// Close this pane and go back to the one under it, as Esc does.
final class PanePop extends PaneActionResult {
  const PanePop();
}

/// The action could not run; the pane shows [reason].
final class PaneRejected extends PaneActionResult {
  const PaneRejected(this.reason);

  final String reason;
}

/// Open [pane] on top of the current one; Esc comes back.
final class PanePush extends PaneActionResult {
  const PanePush(this.pane);

  final Pane pane;
}

/// Run [command] through its parameter flow, then come back to the pane.
final class PaneOpenCommand extends PaneActionResult {
  const PaneOpenCommand(this.command);

  final Command command;
}

/// Looking an action up by the key that runs it.
extension PaneActionLookup on List<PaneAction> {
  /// The action [key] runs, if any.
  PaneAction? forKey(PaneKey key) {
    for (final action in this) {
      if (action.key == key) return action;
    }
    return null;
  }
}
