import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

KeyAction _action(String label, {int? index, bool visible = true}) => KeyAction(
  label: label,
  key: LogicalKey.keyA,
  index: index,
  visible: visible,
  onActivate: () {},
);

void main() {
  group('ActionFooter.ordered', () {
    test('sorts by index and keeps scope order for ties', () {
      final ordered = ActionFooter.ordered([
        _action('late', index: 900),
        _action('first'),
        _action('second'),
        _action('early', index: -1),
      ]);
      expect(ordered.map((action) => action.label), [
        'early',
        'first',
        'second',
        'late',
      ]);
    });
  });

  group('ActionFooter.fit', () {
    test('joins everything that fits with the gap', () {
      expect(ActionFooter.fit(['[A] One', '[B] Two'], 80), '[A] One   [B] Two');
    });

    test('drops trailing hints and marks the omission', () {
      expect(
        ActionFooter.fit(['[A] One', '[B] Two', '[C] Three'], 21),
        '[A] One   [B] Two   …',
      );
      expect(
        ActionFooter.fit(['[A] One', '[B] Two', '[C] Three'], 12),
        '[A] One   …',
      );
    });

    test('falls back to a lone ellipsis when nothing fits', () {
      expect(ActionFooter.fit(['[A] One'], 3), '…');
      expect(ActionFooter.fit([], 3), '');
    });
  });

  test('renders visible labels muted on one line', () async {
    await testNocterm('action footer', (tester) async {
      await tester.pumpComponent(
        TuiTheme(
          data: appThemeDefault,
          child: AppTheme(
            data: appThemeDefault,
            child: Column(
              children: [
                PageFooter(
                  actions: [
                    _action('Hidden', visible: false),
                    _action('Shown'),
                  ],
                  leading: const Text('12k/128k'),
                ),
              ],
            ),
          ),
        ),
      );
      final text = tester.terminalState.getText();
      expect(text, contains('12k/128k   [A] Shown'));
      expect(text, isNot(contains('Hidden')));
      final cell = tester.terminalState.getCellAt(13, 0);
      expect(cell?.style.color, appThemeDefault.muted);
    });
  });
}
