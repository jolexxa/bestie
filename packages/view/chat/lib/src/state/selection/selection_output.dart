import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:intentions/intentions.dart';

/// Outputs produced by the selection logic block.
@model
sealed class SelectionOutput {
  const SelectionOutput();
}

/// Position changed. Carries the new position so the parent block
/// can re-emit a `CursorMoved` for the view to ensure visibility.
@model
final class PositionChanged extends SelectionOutput {
  const PositionChanged(this.position);

  final SelectionPosition position;
}
