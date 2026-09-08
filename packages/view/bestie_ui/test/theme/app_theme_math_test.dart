import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Reports the math theme its context resolves to.
class _Capture extends StatelessComponent {
  const _Capture({required this.onBuild});

  final void Function(MathTheme theme) onBuild;

  @override
  Component build(BuildContext context) {
    onBuild(MathThemeScope.of(context));
    return const SizedBox();
  }
}

/// An achromatic palette, so the slot colours can only differ by luminance.
const AppThemeData _monochrome = AppThemeData(
  name: 'Monochrome',
  brightness: Brightness.light,
  background: Color(0xFFFFFF),
  onBackground: Color(0x000000),
  surface: Color(0xF0F0F0),
  onSurface: Color(0x000000),
  primary: Color(0x000000),
  onPrimary: Color(0xFFFFFF),
  accent: Color(0x333333),
  secondary: Color(0x4D4D4D),
  onSecondary: Color(0xFFFFFF),
  error: Color(0x1A1A1A),
  onError: Color(0xFFFFFF),
  errorAccent: Color(0x000000),
  success: Color(0x4D4D4D),
  onSuccess: Color(0xFFFFFF),
  successAccent: Color(0x333333),
  warning: Color(0x808080),
  onWarning: Color(0x000000),
  outline: Color(0xB3B3B3),
  outlineVariant: Color(0x999999),
  selection: Color(0x000000),
  onSelection: Color(0xFFFFFF),
  info: Color(0x595959),
  onInfo: Color(0xFFFFFF),
  infoAccent: Color(0x333333),
  muted: Color(0x707070),
  onMuted: Color(0x000000),
  mutedAccent: Color(0x4D4D4D),
  loading: Color(0x333333),
  surfaceAccent: Color(0xDDDDDD),
  highVisibility: Color(0x000000),
);

void main() {
  group('AppThemeData.math', () {
    test('gives symbols a four-slot cycle drawn from the palette', () {
      expect(appThemeDefault.math.slotStyles.map((s) => s.color), [
        appThemeDefault.primary,
        appThemeDefault.info,
        appThemeDefault.success,
        appThemeDefault.secondary,
      ]);
    });

    test('colours by identifier', () {
      expect(appThemeDefault.math.tagger, same(tagSymbols));
    });

    test('paints only slotted cells', () {
      // Operators, delimiters and bars keep the surrounding style: colour is
      // spent on symbols alone.
      expect(appThemeDefault.math.styleFor(null), isNull);
      expect(appThemeDefault.math.styleFor(0), isNotNull);
    });

    test('derives an equal theme every time it is asked', () {
      // Derived fresh per build, so it has to compare by value: an instance
      // that merely looks new would invalidate MarkdownView's parse cache on
      // every frame.
      expect(appThemeDefault.math, appThemeDefault.math);
      expect(
        appThemeDefault.math.hashCode,
        appThemeDefault.math.hashCode,
      );
    });

    test('derives a distinct theme per app theme', () {
      expect(appThemeDefault.math, isNot(appThemes['Neo']!.math));
    });

    test('every built-in theme gets four usable slot colours', () {
      for (final theme in appThemes.values) {
        expect(theme.math.slotStyles, hasLength(4), reason: theme.name);
        expect(
          theme.math.slotStyles.every((s) => s.color != null),
          isTrue,
          reason: theme.name,
        );
      }
    });

    test('a monochrome app theme degrades to greys, not hues', () {
      // The right degradation, and it needs no special case: the slots just
      // resolve through a palette that has no colour in it. Symbols are then
      // told apart by luminance alone, or not at all.
      for (final style in _monochrome.math.slotStyles) {
        final color = style.color!;
        expect(
          {color.red, color.green, color.blue},
          hasLength(1),
          reason: 'expected an achromatic slot, got $color',
        );
      }
    });
  });

  group('MathThemeScope', () {
    test('resolves to none where no scope was installed', () async {
      await testNocterm('no scope', (tester) async {
        MathTheme? captured;
        await tester.pumpComponent(
          _Capture(onBuild: (theme) => captured = theme),
        );
        expect(captured, same(MathTheme.none));
      });
    });

    test('hands its data to descendants', () async {
      await testNocterm('scoped', (tester) async {
        MathTheme? captured;
        await tester.pumpComponent(
          MathThemeScope(
            data: appThemeDefault.math,
            child: _Capture(onBuild: (theme) => captured = theme),
          ),
        );
        expect(captured, appThemeDefault.math);
      });
    });

    test('notifies only when the theme changes', () {
      const child = SizedBox();
      // Two separate derivations of the same app theme: a rebuild that changed
      // nothing must not repaint every equation on screen.
      final before = MathThemeScope(data: appThemeDefault.math, child: child);
      final rederived = MathThemeScope(
        data: appThemeDefault.math,
        child: child,
      );
      const other = MathThemeScope(data: MathTheme.none, child: child);
      expect(rederived.updateShouldNotify(before), isFalse);
      expect(other.updateShouldNotify(before), isTrue);
    });
  });
}
