import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/state/subagent_zone/subagent_zone.dart';
import 'package:test/test.dart';

SubagentSummary _s(String id) => SubagentSummary(
  id: 'subagent:$id',
  title: id,
  status: SubagentStatus.running,
);

List<SubagentSummary> _roster(int n) => [for (var i = 0; i < n; i++) _s('$i')];

void main() {
  late SubagentZoneLogic logic;

  setUp(() => logic = SubagentZoneLogic()..start());
  tearDown(() => logic.dispose());

  test('starts inactive, viewing the primary', () {
    expect(logic.value.active, isFalse);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSessionId, primaryAgentSessionId);
    expect(logic.value.selectedSubagentId, isNull);
  });

  test('EnterZone is a no-op with no subagents', () {
    logic.input(const EnterZone());
    expect(logic.value.active, isFalse);
  });

  test('EnterZone activates on the Primary row', () {
    logic
      ..input(ZoneRosterChanged(_roster(2)))
      ..input(const EnterZone());
    expect(logic.value.active, isTrue);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSessionId, primaryAgentSessionId);
    expect(logic.value.selectedSubagentId, isNull);
  });

  test('MoveDown steps through subagents and clamps at the last', () {
    logic
      ..input(ZoneRosterChanged(_roster(2)))
      ..input(const EnterZone())
      ..input(const ZoneMoveDown());
    expect(logic.value.highlightedIndex, 1);
    expect(logic.value.selectedSessionId, 'subagent:0');
    expect(logic.value.selectedSubagentId, 'subagent:0');

    logic.input(const ZoneMoveDown());
    expect(logic.value.highlightedIndex, 2);
    expect(logic.value.selectedSessionId, 'subagent:1');

    logic.input(const ZoneMoveDown()); // clamp
    expect(logic.value.highlightedIndex, 2);
  });

  test('MoveUp returns to Primary, then off Primary exits the zone', () {
    logic
      ..input(ZoneRosterChanged(_roster(2)))
      ..input(const EnterZone())
      ..input(const ZoneMoveDown()) // → subagent 0
      ..input(const ZoneMoveUp()); // → Primary, still active
    expect(logic.value.active, isTrue);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSessionId, primaryAgentSessionId);

    logic.input(const ZoneMoveUp()); // exit
    expect(logic.value.active, isFalse);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSessionId, primaryAgentSessionId);
  });

  test('ExitZone deactivates and resets the highlight', () {
    logic
      ..input(ZoneRosterChanged(_roster(2)))
      ..input(const EnterZone())
      ..input(const ZoneMoveDown())
      ..input(const ExitZone());
    expect(logic.value.active, isFalse);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSubagentId, isNull);
  });

  test('a roster shrink clamps the highlight into range', () {
    logic
      ..input(ZoneRosterChanged(_roster(3)))
      ..input(const EnterZone())
      ..input(const ZoneMoveDown())
      ..input(const ZoneMoveDown())
      ..input(const ZoneMoveDown()); // row 3 (third subagent)
    expect(logic.value.highlightedIndex, 3);

    logic.input(ZoneRosterChanged(_roster(1)));
    expect(logic.value.highlightedIndex, 1);
    expect(logic.value.selectedSubagentId, 'subagent:0');
  });

  test('clicking a subagent row activates and highlights it', () {
    logic
      ..input(ZoneRosterChanged(_roster(3)))
      ..input(const ZoneSelectRow(3));
    expect(logic.value.active, isTrue);
    expect(logic.value.highlightedIndex, 3);
    expect(logic.value.selectedSubagentId, 'subagent:2');
  });

  test('clicking the Primary row activates it', () {
    logic
      ..input(ZoneRosterChanged(_roster(3)))
      ..input(const ZoneSelectRow(0));
    expect(logic.value.active, isTrue);
    expect(logic.value.highlightedIndex, 0);
    expect(logic.value.selectedSubagentId, isNull);
  });

  test('clicking past the last row clamps to it', () {
    logic
      ..input(ZoneRosterChanged(_roster(2)))
      ..input(const ZoneSelectRow(9));
    expect(logic.value.highlightedIndex, 2);
  });

  test('clicking any row on an empty roster leaves the zone', () {
    logic.input(const ZoneSelectRow(0));
    expect(logic.value.active, isFalse);
    expect(logic.value.highlightedIndex, 0);
  });

  test('emptying the roster while active exits the zone', () {
    logic
      ..input(ZoneRosterChanged(_roster(1)))
      ..input(const EnterZone())
      ..input(const ZoneRosterChanged([]));
    expect(logic.value.active, isFalse);
  });
}
