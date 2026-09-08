import 'package:bestie_chat_view/src/view/components/rewind_hint_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

void main() {
  group('RewindHintRow', () {
    test('names the mode and spells out the keys', () async {
      await testNocterm('rewind hint', (tester) async {
        await tester.pumpComponent(_themed(const RewindHintRow()));

        expect(tester.terminalState, containsText('⟲ Rewind'));
        expect(tester.terminalState, containsText(RewindHintRow.hint));
        expect(
          tester.terminalState.getCellAt(2, 0)?.style.color,
          appThemeDefault.error,
        );
      });
    });

    test('trims the keys before the name on a narrow terminal', () async {
      await testNocterm('rewind hint narrow', (tester) async {
        await tester.pumpComponent(_themed(const RewindHintRow()));

        expect(tester.terminalState, containsText('⟲ Rewind'));
        expect(tester.terminalState, isNot(containsText('Esc to cancel')));
      }, size: const Size(30, 6));
    });
  });
}
