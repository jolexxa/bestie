import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// Concrete position addressed by the selection cursor.
///
/// [itemIndex] points into the timeline-items list. [subIndex] is the
/// sub-slot within that item: `0` is the row itself; `1..N` address
/// selectable children (e.g. attachments under a message).
@immutable
@model
class SelectionPosition {
  const SelectionPosition({required this.itemIndex, required this.subIndex});

  final int itemIndex;
  final int subIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionPosition &&
          itemIndex == other.itemIndex &&
          subIndex == other.subIndex;

  @override
  int get hashCode => Object.hash(itemIndex, subIndex);

  @override
  String toString() =>
      'SelectionPosition(itemIndex: $itemIndex, subIndex: $subIndex)';
}
