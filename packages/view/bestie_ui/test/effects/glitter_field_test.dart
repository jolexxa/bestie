import 'dart:math';

import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide isNotEmpty;
import 'package:test/test.dart';

const _size = Size(20, 2);

Component _field(int tick, Random random) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: GlitterField(tick: tick, random: random),
  ),
);

List<Cell?> _cells(NoctermTester tester) => [
  for (var y = 0; y < _size.height; y++)
    for (var x = 0; x < _size.width; x++) tester.terminalState.getCellAt(x, y),
];

void main() {
  final palette = GlitterPalette.of(appThemeDefault);

  test('tick zero is the untouched resting field', () async {
    await testNocterm('glitter rest', size: _size, (tester) async {
      await tester.pumpComponent(_field(0, Random(7)));
      for (final cell in _cells(tester)) {
        expect(cell?.char, glitterGlyphs.first);
        expect(cell?.style.color, palette.resting);
        expect(cell?.style.backgroundColor, palette.fill);
      }
    });
  });

  test('ticks scatter sparkles that never leave the primary fill', () async {
    await testNocterm('glitter sparkle', size: _size, (tester) async {
      await tester.pumpComponent(_field(0, Random(7)));
      await tester.pumpComponent(_field(1, Random(7)));
      final cells = _cells(tester);
      final lit = cells.where((cell) => cell?.char != glitterGlyphs.first);
      expect(lit, isNotEmpty);
      for (final cell in cells) {
        expect(glitterGlyphs, contains(cell?.char));
        expect(cell?.style.backgroundColor, palette.fill);
      }
    });
  });

  test('the same seed and tick paint the same frame', () async {
    await testNocterm('glitter still', size: _size, (tester) async {
      await tester.pumpComponent(_field(5, Random(3)));
      final first = _cells(tester).map((cell) => cell?.char).toList();
      await tester.pumpComponent(_field(5, Random(3)));
      expect(_cells(tester).map((cell) => cell?.char).toList(), first);
    });
  });

  test('one sparkle at a time climbs to its peak and fades', () async {
    await testNocterm('glitter life', size: const Size(10, 1), (tester) async {
      // Ten cells keep exactly one sparkle alive at a time.
      final random = Random(11);
      final glyphsSeen = <String>{};
      const life = glitterRestTicks + glitterRiseTicks + glitterFallTicks;
      for (var tick = 1; tick <= life * 3; tick++) {
        await tester.pumpComponent(_field(tick, random));
        final lit = tester.terminalState
            .getText()
            .trim()
            .split('')
            .where((glyph) => glyph != glitterGlyphs.first)
            .toList();
        expect(lit, hasLength(lessThanOrEqualTo(1)));
        glyphsSeen.addAll(lit);
      }
      expect(glyphsSeen, containsAll(glitterGlyphs.skip(1)));
    });
  });

  test('palette is one hue in three tones', () {
    expect(palette.fill, appThemeDefault.primary);
    expect(
      palette.rising,
      Color.lerp(appThemeDefault.primary, appThemeDefault.onBackground, 0.5),
    );
    expect(palette.peak, appThemeDefault.onBackground);
    expect(palette.at(0), palette.resting);
    expect(palette.at(3), palette.peak);
    expect(palette, GlitterPalette.of(appThemeDefault));
    expect(palette.hashCode, GlitterPalette.of(appThemeDefault).hashCode);
  });

  test('the secondary palette is the same three tones on secondary', () {
    final accent = GlitterPalette.secondary(appThemeDefault);
    expect(accent.fill, appThemeDefault.secondary);
    expect(
      accent.resting,
      Color.lerp(appThemeDefault.secondary, appThemeDefault.onSecondary, 0.3),
    );
    expect(
      accent.rising,
      Color.lerp(appThemeDefault.secondary, appThemeDefault.onBackground, 0.5),
    );
    expect(accent.peak, appThemeDefault.onBackground);
    expect(accent, isNot(palette));
  });

  test('the error palette is the same three tones on error', () {
    final alarm = GlitterPalette.error(appThemeDefault);
    expect(alarm.fill, appThemeDefault.error);
    expect(
      alarm.resting,
      Color.lerp(appThemeDefault.error, appThemeDefault.onError, 0.3),
    );
    expect(
      alarm.rising,
      Color.lerp(appThemeDefault.error, appThemeDefault.onBackground, 0.5),
    );
    expect(alarm.peak, appThemeDefault.onBackground);
    expect(alarm, isNot(palette));
  });

  test('a field takes the palette it is handed', () async {
    await testNocterm('secondary field', size: const Size(12, 2), (
      tester,
    ) async {
      await tester.pumpComponent(
        AppTheme(
          data: appThemeDefault,
          child: TuiTheme(
            data: appThemeDefault,
            child: GlitterField(
              tick: 0,
              random: Random(1),
              palette: GlitterPalette.secondary,
            ),
          ),
        ),
      );
      expect(
        tester.terminalState.getCellAt(3, 1)?.style.backgroundColor,
        appThemeDefault.secondary,
      );
    });
  });
}
