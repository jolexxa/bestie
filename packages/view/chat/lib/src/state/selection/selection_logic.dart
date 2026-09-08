import 'package:bestie_chat_view/src/state/selection/selection_data.dart';
import 'package:bestie_chat_view/src/state/selection/selection_input.dart';
import 'package:bestie_chat_view/src/state/selection/selection_output.dart';
import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

// ── Base state ──────────────────────────────────────────────

@model
sealed class SelectionState extends StateLogic<SelectionState> {
  SelectionData get data => get<SelectionData>();

  /// Always concrete.
  SelectionPosition get position => data.position;

  /// Derived: cursor sits on the most recently observed tail. Drives
  /// auto-advance behavior on the next [TimelineShapeChanged].
  bool get followsTail =>
      data.lastObservedTail != null && data.position == data.lastObservedTail;

  /// Shared `ResetSelection` handler — return to [Unobserved] with a
  /// fresh data slate. [Unobserved] leaves it unregistered (no-op).
  Transition handleReset(ResetSelection _) {
    data.position = const SelectionPosition(itemIndex: 0, subIndex: 0);
    data.lastObservedTail = null;
    data.childCounts = const [];
    return to<Unobserved>();
  }
}

/// Initial state — no timeline observed yet.
@model
final class Unobserved extends SelectionState {
  Unobserved() {
    on<TimelineShapeChanged>((input) {
      data.childCounts = input.childCounts;
      if (input.childCounts.isEmpty) return toSelf();
      data.position = SelectionPosition(
        itemIndex: input.childCounts.length - 1,
        subIndex: 0,
      );
      data.lastObservedTail = data.position;
      output(PositionChanged(data.position));
      return to<Observed>();
    });
  }
}

/// Timeline observed.
@model
final class Observed extends SelectionState {
  Observed() {
    on<TimelineShapeChanged>(_onTimelineShape);

    on<MoveUp>((_) {
      _moveTo(_previousSlot(data.position, data.childCounts));
      return toSelf();
    });

    on<MoveDown>((_) {
      _moveTo(_nextSlot(data.position, data.childCounts));
      return toSelf();
    });

    // Snap onto the current tail and re-engage tail-following.
    on<FollowTail>((_) {
      if (data.childCounts.isEmpty) return toSelf();
      final tail = SelectionPosition(
        itemIndex: data.childCounts.length - 1,
        subIndex: 0,
      );
      data.lastObservedTail = tail;
      _moveTo(tail);
      return toSelf();
    });

    // Mouse path: land on the clicked item.
    on<SelectItem>((input) {
      if (data.childCounts.isEmpty) return toSelf();
      final item = input.itemIndex.clamp(0, data.childCounts.length - 1);
      data.position = SelectionPosition(itemIndex: item, subIndex: 0);
      return toSelf();
    });

    on<ResetSelection>(handleReset);
  }

  /// Move the cursor to [next], emitting [PositionChanged] only when it
  /// differs from the current position.
  void _moveTo(SelectionPosition next) {
    if (next == data.position) return;
    data.position = next;
    output(PositionChanged(data.position));
  }

  /// Ride the tail if parked on it, otherwise clamp into range.
  /// An empty timeline drops back to [Unobserved].
  Transition _onTimelineShape(TimelineShapeChanged input) {
    final newCounts = input.childCounts;
    if (newCounts.isEmpty) {
      data.position = const SelectionPosition(itemIndex: 0, subIndex: 0);
      data.lastObservedTail = null;
      data.childCounts = const [];
      output(PositionChanged(data.position));
      return to<Unobserved>();
    }
    data.childCounts = newCounts;
    final newTail = SelectionPosition(
      itemIndex: newCounts.length - 1,
      subIndex: 0,
    );
    final SelectionPosition next;
    if (data.position == data.lastObservedTail) {
      next = newTail;
    } else {
      final clampedItem = data.position.itemIndex.clamp(
        0,
        newCounts.length - 1,
      );
      final clampedSub = data.position.subIndex.clamp(
        0,
        newCounts[clampedItem],
      );
      next = SelectionPosition(itemIndex: clampedItem, subIndex: clampedSub);
    }
    data.lastObservedTail = newTail;
    _moveTo(next);
    return toSelf();
  }
}

// ── Slot arithmetic ─────────────────────────────────────────

SelectionPosition _previousSlot(
  SelectionPosition from,
  List<int> childCounts,
) {
  if (from.subIndex > 0) {
    return SelectionPosition(
      itemIndex: from.itemIndex,
      subIndex: from.subIndex - 1,
    );
  }
  if (from.itemIndex > 0) {
    final prev = from.itemIndex - 1;
    return SelectionPosition(
      itemIndex: prev,
      subIndex: childCounts[prev],
    );
  }
  return from;
}

SelectionPosition _nextSlot(
  SelectionPosition from,
  List<int> childCounts,
) {
  final lastItem = childCounts.length - 1;
  final lastSubOfCurrent = childCounts[from.itemIndex];
  if (from.subIndex < lastSubOfCurrent) {
    return SelectionPosition(
      itemIndex: from.itemIndex,
      subIndex: from.subIndex + 1,
    );
  }
  if (from.itemIndex < lastItem) {
    return SelectionPosition(itemIndex: from.itemIndex + 1, subIndex: 0);
  }
  return from;
}

// ── Logic block ─────────────────────────────────────────────

@model
final class SelectionLogic extends LogicBlock<SelectionState> {
  SelectionLogic() {
    set(SelectionData());
    set(Unobserved());
    set(Observed());
  }

  @override
  Transition getInitialState() => to<Unobserved>();
}
