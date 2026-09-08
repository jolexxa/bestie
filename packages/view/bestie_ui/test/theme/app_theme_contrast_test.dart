import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// The preset themes are hand-tuned to these contrast rules; the gimmick
/// themes (Neo, Floppy Drive) are exempt on purpose.
void main() {
  final presets = appThemes.values.where(
    (theme) => theme != neo && theme != floppyDrive,
  );

  for (final theme in presets) {
    group(theme.name, () {
      final dark = theme.brightness == Brightness.dark;
      double against(Color color) => color.contrastWith(theme.background);

      test('body text is legible without glare', () {
        final ratio = against(theme.onBackground);
        expect(ratio, greaterThanOrEqualTo(dark ? 11 : 12));
        expect(ratio, lessThanOrEqualTo(dark ? 14 : 15));
        expect(
          theme.onSurface.contrastWith(theme.surface),
          greaterThanOrEqualTo(10),
        );
      });

      test('muted text still reads', () {
        expect(against(theme.muted), greaterThanOrEqualTo(5));
        expect(against(theme.mutedAccent), inInclusiveRange(2.2, 2.8));
      });

      test('every accent role passes AA', () {
        for (final color in [
          theme.primary,
          theme.secondary,
          theme.info,
          theme.success,
          theme.warning,
          theme.error,
        ]) {
          expect(against(color), greaterThanOrEqualTo(4.5), reason: '$color');
        }
        expect(against(theme.highVisibility), greaterThanOrEqualTo(7));
      });

      test('primary-tier rows stay legible on their tint', () {
        expect(
          theme.primary.contrastWith(theme.primaryTint),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          theme.onBackground.contrastWith(theme.primaryTintSelected),
          greaterThanOrEqualTo(7),
        );
        expect(
          theme.muted.contrastWith(theme.primaryTintSelected),
          greaterThanOrEqualTo(3),
        );
      });

      test('outlines are faint but present', () {
        expect(against(theme.outline), inInclusiveRange(1.3, 1.5));
        expect(against(theme.outlineVariant), inInclusiveRange(1.7, 1.9));
      });

      test('text on accents uses the background', () {
        expect(theme.onPrimary, theme.background);
        expect(theme.onSecondary, theme.background);
        expect(theme.onError, theme.background);
        expect(theme.onSuccess, theme.background);
        expect(theme.onWarning, theme.background);
        expect(theme.onInfo, theme.background);
        expect(theme.onSelection, theme.background);
        expect(theme.selection, theme.primary);
      });
    });
  }

  test('twelve themes, four of them light', () {
    expect(appThemes, hasLength(12));
    expect(
      appThemes.values.where((t) => t.brightness == Brightness.light),
      hasLength(4),
    );
    expect(appThemeDefault, same(asdn));
  });
}
