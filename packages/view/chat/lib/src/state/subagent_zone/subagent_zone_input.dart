import 'package:agent_repository/agent_repository.dart' show SubagentSummary;
import 'package:intentions/intentions.dart';

/// Inputs to the subagent-zone logic block.
@model
sealed class SubagentZoneInput {
  const SubagentZoneInput();
}

/// Give the zone pseudo-focus, landing the highlight on the Primary row.
@model
final class EnterZone extends SubagentZoneInput {
  const EnterZone();
}

/// Drop pseudo-focus back to the text field.
@model
final class ExitZone extends SubagentZoneInput {
  const ExitZone();
}

/// Move the highlight one row up; up off the Primary row exits the zone.
@model
final class ZoneMoveUp extends SubagentZoneInput {
  const ZoneMoveUp();
}

/// Move the highlight one row down (bounded by the last subagent).
@model
final class ZoneMoveDown extends SubagentZoneInput {
  const ZoneMoveDown();
}

/// The roster changed; refresh and clamp the highlight.
@model
final class ZoneRosterChanged extends SubagentZoneInput {
  const ZoneRosterChanged(this.subagents);

  final List<SubagentSummary> subagents;
}

/// Jump the highlight to a row (mouse click). Row `0` is Primary and leaves
/// the zone; `1..N` select a subagent and enter it.
@model
final class ZoneSelectRow extends SubagentZoneInput {
  const ZoneSelectRow(this.index);

  final int index;
}
