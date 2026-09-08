import 'package:agent_repository/agent_repository.dart'
    show AgentSessionId, SubagentSummary, primaryAgentSessionId;
import 'package:bestie_chat_view/src/state/subagent_zone/subagent_zone_data.dart';
import 'package:bestie_chat_view/src/state/subagent_zone/subagent_zone_input.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

// ── Base state ──────────────────────────────────────────────

@model
sealed class SubagentZoneState extends StateLogic<SubagentZoneState> {
  SubagentZoneData get data => get<SubagentZoneData>();

  bool get active => data.active;

  /// Highlighted row: `0` is Primary, `1..N` address `subagents[i-1]`.
  int get highlightedIndex => data.highlightedIndex;
  List<SubagentSummary> get subagents => data.subagents;

  /// The session under the highlight: the Primary row resolves to the
  /// primary, any other row to its subagent.
  AgentSessionId get selectedSessionId =>
      selectedSubagentId ?? primaryAgentSessionId;

  /// The highlighted subagent's id, or null on the Primary row.
  AgentSessionId? get selectedSubagentId {
    final subagentIndex = data.highlightedIndex - 1;
    final inRange = subagentIndex >= 0 && subagentIndex < subagents.length;
    return inRange ? subagents[subagentIndex].id : null;
  }

  int get _lastRow => data.subagents.length;

  /// Refresh the roster and clamp the highlight into range.
  void applyRoster(List<SubagentSummary> roster) {
    data.subagents = roster;
    data.highlightedIndex = data.highlightedIndex.clamp(0, _lastRow);
  }

  /// Jump the highlight to [index] (mouse click) and activate the zone, so
  /// the clicked row, Primary included, reads as selected.
  Transition selectRow(int index) {
    if (data.subagents.isEmpty) {
      data.active = false;
      data.highlightedIndex = 0;
      return to<ZoneInactive>();
    }
    data.active = true;
    data.highlightedIndex = index.clamp(0, _lastRow);
    return to<ZoneActive>();
  }
}

// ── States ──────────────────────────────────────────────────

/// Pseudo-focus is on the text field; the zone bar is passive.
@model
final class ZoneInactive extends SubagentZoneState {
  ZoneInactive() {
    on<EnterZone>((_) {
      if (data.subagents.isEmpty) return toSelf();
      data.active = true;
      data.highlightedIndex = 0;
      return to<ZoneActive>();
    });
    on<ZoneRosterChanged>((input) {
      applyRoster(input.subagents);
      return toSelf();
    });
    on<ZoneSelectRow>((input) => selectRow(input.index));
  }
}

/// Pseudo-focus is in the zone; arrows browse, up off Primary exits.
@model
final class ZoneActive extends SubagentZoneState {
  ZoneActive() {
    on<ZoneMoveDown>((_) {
      if (data.highlightedIndex < _lastRow) data.highlightedIndex++;
      return toSelf();
    });
    on<ZoneMoveUp>((_) {
      if (data.highlightedIndex == 0) return _exit();
      data.highlightedIndex--;
      return toSelf();
    });
    on<ExitZone>((_) => _exit());
    on<ZoneRosterChanged>((input) {
      applyRoster(input.subagents);
      if (data.subagents.isEmpty) return _exit();
      return toSelf();
    });
    on<ZoneSelectRow>((input) => selectRow(input.index));
  }

  Transition _exit() {
    data.active = false;
    data.highlightedIndex = 0;
    return to<ZoneInactive>();
  }
}

// ── Logic block ─────────────────────────────────────────────

@model
final class SubagentZoneLogic extends LogicBlock<SubagentZoneState> {
  SubagentZoneLogic() {
    set(SubagentZoneData());
    set(ZoneInactive());
    set(ZoneActive());
  }

  @override
  Transition getInitialState() => to<ZoneInactive>();
}
