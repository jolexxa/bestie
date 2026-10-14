import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

String _row(NoctermTester tester, int y, int from, int to) => [
  for (var x = from; x <= to; x++) tester.terminalState.getCellAt(x, y)?.char,
].join();

void main() {
  test('a card without a footer is one bordered box', () async {
    await testNocterm('overlay card', (tester) async {
      await tester.pumpComponent(
        const TuiTheme(
          data: appThemeDefault,
          child: OverlayCard(maxWidth: 10, maxHeight: 4, child: Text('body')),
        ),
      );
      final text = tester.terminalState.getText();
      expect(text, contains('┌'));
      expect(text, contains('body'));
      expect(text, isNot(contains('├')));
    }, size: const Size(10, 4));
  });

  test('a footer sits under a rule joined to the border', () async {
    await testNocterm('overlay card footer', (tester) async {
      await tester.pumpComponent(
        TuiTheme(
          data: appThemeDefault,
          child: OverlayCard(
            maxWidth: 10,
            maxHeight: 6,
            footer: const Text('hints'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: const Text('body'))],
            ),
          ),
        ),
      );
      expect(_row(tester, 0, 0, 9), '┌────────┐');
      expect(_row(tester, 1, 0, 9), '│body    │');
      expect(_row(tester, 2, 0, 9), '│        │');
      expect(_row(tester, 3, 0, 9), '├────────┤');
      expect(_row(tester, 4, 0, 9), '│hints   │');
      expect(_row(tester, 5, 0, 9), '└────────┘');
      expect(
        tester.terminalState.getCellAt(0, 3)?.style.color,
        appThemeDefault.outlineVariant,
      );
    }, size: const Size(10, 6));
  });
}
