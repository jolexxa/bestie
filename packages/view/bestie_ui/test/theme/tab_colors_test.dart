import 'package:bestie_ui/bestie_ui.dart';
import 'package:test/test.dart';

/// The tab colors are derived rather than authored per theme, so a bad
/// derivation would silently flatten every theme at once. These assert the
/// derived values stay distinguishable in each one.
void main() {
  group('derived tab colors', () {
    for (final theme in appThemes.values) {
      group(theme.name, () {
        test('separates the bar from the page and the surface', () {
          expect(theme.tabBarBackground, isNot(theme.background));
          expect(theme.tabBarBackground, isNot(theme.surface));
        });

        test('separates an idle chip from the bar it sits on', () {
          expect(theme.tabUnselectedBackground, isNot(theme.tabBarBackground));
        });

        test('separates an idle chip from the active one', () {
          // The active tab is filled with the page background, so an idle chip
          // matching it would erase the distinction between the two states.
          expect(theme.tabUnselectedBackground, isNot(theme.background));
        });

        test('keeps idle ink off the ground it is drawn on', () {
          expect(theme.muted, isNot(theme.tabUnselectedBackground));
          expect(theme.muted, isNot(theme.tabBarBackground));
        });

        test('keeps the active edge off the fill behind it', () {
          expect(theme.tabSelectedBorder, isNot(theme.background));
        });
      });
    }
  });
}
