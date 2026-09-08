import 'dart:math';

import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _size = Size(40, 3);

Component _band({required bool effects, String? busy}) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: ThemeEffects(
      enabled: effects,
      child: Column(
        children: [
          StatusBand(
            leading: r'$1.20 spent',
            trailing: 'OpenRouter · Sonnet',
            busy: busy,
            random: Random(1),
          ),
          const Text('below'),
        ],
      ),
    ),
  ),
);

List<String?> _rowChars(NoctermTester tester, int y, {int? width}) => [
  for (var x = 0; x < (width ?? _size.width); x++)
    tester.terminalState.getCellAt(x, y)?.char,
];

void main() {
  test('sets the readings on secondary, the trailing one faded', () async {
    await testNocterm('band text', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      final leading = tester.terminalState.getCellAt(StatusBand.inset, 0);
      expect(leading?.char, r'$');
      expect(leading?.style.color, appThemeDefault.onSecondary);
      expect(leading?.style.backgroundColor, appThemeDefault.secondary);
      final trailingEnd = _size.width.toInt() - StatusBand.inset - 1;
      final trailing = tester.terminalState.getCellAt(trailingEnd, 0);
      expect(trailing?.char, 't');
      expect(
        trailing?.style.color,
        Color.lerp(
          appThemeDefault.onSecondary,
          appThemeDefault.secondary,
          StatusBand.trailingFade,
        ),
      );
      expect(trailing?.style.backgroundColor, appThemeDefault.secondary);
    });
  });

  test('spins a busy label just inside the trailing reading', () async {
    const wide = Size(60, 3);
    await testNocterm('band busy', size: wide, (tester) async {
      await tester.pumpComponent(_band(effects: false, busy: 'warming'));
      final row = _rowChars(tester, 0, width: wide.width.toInt()).join();
      const tail = 'warming${StatusBand.separator}OpenRouter · Sonnet';
      final tailStart = row.indexOf(tail);
      expect(tailStart + tail.length, wide.width.toInt() - StatusBand.inset);
      final spinnerX = tailStart - 2;
      final spinner = tester.terminalState.getCellAt(spinnerX, 0);
      expect(spinner?.style.color, appThemeDefault.onSecondary);
      expect(spinner?.style.backgroundColor, appThemeDefault.secondary);
      final label = tester.terminalState.getCellAt(tailStart, 0);
      expect(label?.char, 'w');
      expect(label?.style.color, appThemeDefault.onSecondary);

      await tester.pumpComponent(_band(effects: false));
      expect(
        _rowChars(tester, 0, width: wide.width.toInt()).join(),
        isNot(contains('warming')),
      );
      await tester.pumpComponent(const SizedBox());
    });
  });

  test('is exactly one row tall and glitters on secondary', () async {
    await testNocterm('band height', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      for (var x = 0; x < _size.width; x++) {
        expect(
          tester.terminalState.getCellAt(x, 0)?.style.backgroundColor,
          appThemeDefault.secondary,
          reason: 'fill at $x',
        );
      }
      expect(_rowChars(tester, 1).join().trim(), 'below');
      expect(
        tester.terminalState.getCellAt(0, 1)?.style.backgroundColor,
        isNot(appThemeDefault.secondary),
      );
      // Between the readings the field shows its resting glyphs.
      expect(
        _rowChars(tester, 0).sublist(13, 19),
        everyElement(isIn(glitterGlyphs)),
      );
    });
  });

  test('holds still without theme effects and twinkles with them', () async {
    await testNocterm('band motion', size: _size, (tester) async {
      await tester.pumpComponent(_band(effects: false));
      final still = _rowChars(tester, 0);
      await Future<void>.delayed(overlayTickInterval * 3);
      await tester.pump();
      expect(_rowChars(tester, 0), still);

      await tester.pumpComponent(_band(effects: true));
      final start = _rowChars(tester, 0);
      await Future<void>.delayed(overlayTickInterval * 8);
      await tester.pump();
      expect(_rowChars(tester, 0), isNot(start));

      await tester.pumpComponent(const SizedBox());
    });
  });
}
