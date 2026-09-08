import 'package:bestie_chat_view/src/view/details/detail_section_rule.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _pane = Size(20, 3);

Component _rule(String label) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: SizedBox(
      width: _pane.width,
      height: _pane.height,
      child: DetailSectionRule(label),
    ),
  ),
);

String _drawn(NoctermTester tester) =>
    tester.terminalState.getText().split('\n').first.trimRight();

void main() {
  group('DetailSectionRule', () {
    test('sets the label into a rule that runs to the edge', () async {
      await testNocterm('section rule', (tester) async {
        await tester.pumpComponent(_rule('Output'));

        // The rail the rule starts at is the row it has to end at too, or the
        // pane reads as ragged on one side only.
        expect(_drawn(tester), ' ─ Output ──────────');
      }, size: _pane);
    });

    // Two code units, four cells. Counting units would run the rule two
    // columns past the row it is supposed to end at.
    test('measures the label in cells, not code units', () async {
      await testNocterm('section rule wide glyph', (tester) async {
        await tester.pumpComponent(_rule('出力'));

        expect(UnicodeWidth.stringWidth(_drawn(tester)), _pane.width);
      }, size: _pane);
    });

    test('draws the label alone when there is no room to rule it', () async {
      await testNocterm('section rule cramped', (tester) async {
        await tester.pumpComponent(_rule('a-label-with-no-room-at-all'));

        expect(
          '─ a-label-with-no-room-at-all ',
          startsWith(_drawn(tester).trim()),
          reason: 'a rule with no room left is all label and no rule',
        );
      }, size: _pane);
    });
  });
}
