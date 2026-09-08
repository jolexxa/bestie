import 'package:intentions/intentions.dart';

/// Inputs to the selection logic state machine.
@model
sealed class SelectionInput {
  const SelectionInput();
}

/// Move position one slot earlier (toward older messages).
@model
final class MoveUp extends SelectionInput {
  const MoveUp();
}

/// Move position one slot later (toward newer messages).
@model
final class MoveDown extends SelectionInput {
  const MoveDown();
}

/// Jump the cursor directly to [itemIndex] (sub-slot `0`).
@model
final class SelectItem extends SelectionInput {
  const SelectItem(this.itemIndex);

  final int itemIndex;
}

@model
final class FollowTail extends SelectionInput {
  const FollowTail();
}

/// Drop position, return to unobserved, forget observed tail.
@model
final class ResetSelection extends SelectionInput {
  const ResetSelection();
}

/// The timeline shape changed (new messages, edits, compaction).
/// Carries the current child-selection counts per item.
@model
final class TimelineShapeChanged extends SelectionInput {
  const TimelineShapeChanged(this.childCounts);

  final List<int> childCounts;
}
