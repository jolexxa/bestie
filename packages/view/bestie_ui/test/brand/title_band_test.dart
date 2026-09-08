import 'dart:math';

import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _size = Size(40, 4);

Component _band({required bool effects}) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: ThemeEffects(
      enabled: effects,
      child: Column(
        children: [
          TitleBand(version: '1.2.3', random: Random(1)),
          const Text('below'),
        ],
      ),
    ),
  ),
);

List<String?> _rowChars(NoctermTester tester, int y) => [
  for (var x = 0; x < _size.width; x++)
    tester.terminalState.getCellAt(x, y)?.char,
];

void main() {
  test('sets the block-letter title and a quiet version on primary', () async {
    await testNocterm('band text', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      // "Bestie" in the block font is 21 cells wide and 3 tall; the version
      // sits on the middle row after the gap.
      final title = tester.terminalState.getCellAt(TitleBand.inset, 0);
      expect(title?.char, '█');
      expect(title?.style.color, appThemeDefault.onPrimary);
      expect(title?.style.backgroundColor, appThemeDefault.primary);
      const versionX = TitleBand.inset + 21 + TitleBand.gap;
      final version = tester.terminalState.getCellAt(versionX, 1);
      expect(version?.char, '1');
      expect(
        version?.style.color,
        Color.lerp(
          appThemeDefault.onPrimary,
          appThemeDefault.primary,
          TitleBand.versionFade,
        ),
      );
      expect(version?.style.backgroundColor, appThemeDefault.primary);
      expect(tester.terminalState.getCellAt(versionX, 0)?.char, isNot('1'));
    });
  });

  test('is exactly three rows tall', () async {
    await testNocterm('band height', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      for (var y = 0; y < TitleBand.height; y++) {
        expect(
          tester.terminalState.getCellAt(0, y)?.style.backgroundColor,
          appThemeDefault.primary,
        );
      }
      expect(_rowChars(tester, 3).join().trim(), 'below');
    });
  });

  test('holds still without theme effects and twinkles with them', () async {
    await testNocterm('band motion', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      final still = _rowChars(tester, 2);
      await Future<void>.delayed(overlayTickInterval * 3);
      await tester.pump();
      expect(_rowChars(tester, 2), still);

      await tester.pumpComponent(_band(effects: true));
      final start = [..._rowChars(tester, 1), ..._rowChars(tester, 2)];
      await Future<void>.delayed(overlayTickInterval * 8);
      await tester.pump();
      final later = [..._rowChars(tester, 1), ..._rowChars(tester, 2)];
      expect(later, isNot(start));

      await tester.pumpComponent(const SizedBox());
    });
  });
}
