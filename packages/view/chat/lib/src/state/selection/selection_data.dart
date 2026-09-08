import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:intentions/intentions.dart';

/// Mutable blackboard data for the selection logic block.
@model
final class SelectionData {
  /// Always concrete — never null, never a sentinel. The state
  /// machine guarantees this via `TimelineShapeChanged` initialization
  /// on first observation.
  SelectionPosition position = const SelectionPosition(
    itemIndex: 0,
    subIndex: 0,
  );

  /// Position of the tail at the moment of the most recent timeline
  /// observation. Used to derive whether the cursor is "riding the
  /// tail" — when true, the next growth auto-advances position to
  /// the new tail.
  SelectionPosition? lastObservedTail;

  /// Cached child-selection counts per item, updated on every
  /// `TimelineShapeChanged` so move handlers don't need childCounts
  /// in their input payloads.
  List<int> childCounts = const [];
}
