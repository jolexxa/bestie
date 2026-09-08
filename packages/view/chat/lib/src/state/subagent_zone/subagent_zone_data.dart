import 'package:agent_repository/agent_repository.dart' show SubagentSummary;
import 'package:intentions/intentions.dart';

/// Mutable blackboard data for the subagent-zone logic block.
@model
final class SubagentZoneData {
  /// Whether pseudo-focus is in the zone. The text field keeps real focus;
  /// this only decides whether arrow/enter/esc keys drive the zone.
  bool active = false;

  /// Highlighted row: `0` is the Primary row, `1..N` address `subagents[i-1]`.
  int highlightedIndex = 0;

  /// The current roster, pushed in via `ZoneRosterChanged`.
  List<SubagentSummary> subagents = const [];
}
