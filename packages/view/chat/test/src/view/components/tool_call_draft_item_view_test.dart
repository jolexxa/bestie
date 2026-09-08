import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/tool_call_draft_item_view.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

final _item = ToolCallDraftTimelineItem(
  id: 'live-tool-draft',
  timestamp: DateTime.utc(2025),
);

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

void main() {
  group('ToolCallDraftItemView', () {
    test('draws the flowing dots across the stub row', () async {
      await testNocterm('tool call draft', size: const Size(24, 1), (
        tester,
      ) async {
        await tester.pumpComponent(_themed(ToolCallDraftItemView(_item)));

        final text = tester.terminalState.getText();
        expect(text, startsWith(' · '));
        expect(text, startsWith(' ·   ···'));
      });
    });

    test('keeps the dots moving', () async {
      await testNocterm('tool call draft moving', size: const Size(24, 1), (
        tester,
      ) async {
        await tester.pumpComponent(_themed(ToolCallDraftItemView(_item)));
        final first = tester.terminalState.getText();

        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(tester.terminalState.getText(), isNot(first));
      });
    });

    test('marks the gutter when selected', () async {
      await testNocterm('tool call draft selected', size: const Size(24, 1), (
        tester,
      ) async {
        await tester.pumpComponent(
          _themed(ToolCallDraftItemView(_item, selected: true)),
        );

        final gutter = tester.terminalState.getCellAt(3, 0);
        expect(gutter?.char, '┃');
        expect(gutter?.style.color, appThemeDefault.primary);
      });
    });
  });
}
