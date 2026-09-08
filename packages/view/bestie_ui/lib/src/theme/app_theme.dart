import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

@model
class AppThemeData extends TuiThemeData {
  const AppThemeData({
    required this.name,
    required super.brightness,
    required super.background,
    required super.onBackground,
    required super.surface,
    required super.onSurface,
    required super.primary,
    required super.onPrimary,
    required this.accent,
    required super.secondary,
    required super.onSecondary,
    required super.error,
    required super.onError,
    required this.errorAccent,
    required super.success,
    required super.onSuccess,
    required this.successAccent,
    required super.warning,
    required super.onWarning,
    required super.outline,
    required super.outlineVariant,
    required super.selection,
    required super.onSelection,
    required this.info,
    required this.onInfo,
    required this.infoAccent,
    required this.muted,
    required this.onMuted,
    required this.mutedAccent,
    required this.loading,
    required this.surfaceAccent,
    required this.highVisibility,
  });

  /// The name of the theme.
  final String name;

  /// Darker, less saturated accent version of [primary].
  final Color accent;

  /// Darker, less saturated accent version of [error].
  final Color errorAccent;

  /// Darker, less saturated accent version of [success].
  final Color successAccent;

  /// Informational/neutral-cool content (cyan-ish tones).
  final Color info;

  /// Text/icon color on top of [info].
  final Color onInfo;

  /// Darker, less saturated accent version of [info].
  final Color infoAccent;

  /// De-emphasized/subdued content (gray tones).
  final Color muted;

  /// Text/icon color on top of [muted].
  final Color onMuted;

  /// Darker, less saturated accent version of [muted].
  final Color mutedAccent;

  /// Progress bar color for loading/in-progress operations.
  final Color loading;

  /// Accented surface color for selected/highlighted items (e.g., messages).
  final Color surfaceAccent;

  /// Eye-catching color for non-error emphasis (system messages, tool calls).
  final Color highVisibility;

  /// Background color for the tab bar strip behind the tabs.
  ///
  /// Sits between [background] and [surface] so the strip reads as a distinct
  /// band without competing with either.
  Color get tabBarBackground => Color.lerp(background, surface, 0.7) ?? surface;

  /// Border/edge color for the currently selected tab.
  Color get tabSelectedBorder => outlineVariant;

  /// Background color for unselected tab chips.
  ///
  /// Lifted off [background] but short of [tabBarBackground], so an idle chip
  /// reads as raised from the page yet still recessed into the bar.
  Color get tabUnselectedBackground =>
      Color.lerp(background, surface, 0.35) ?? background;

  /// Border/edge color for unselected tab chips.
  Color get tabUnselectedBorder => accent;

  /// Subtle background tint for the row/item under the mouse cursor.
  Color get hover => Color.lerp(surface, primary, 0.05) ?? surface;

  /// Dimmed [error] background tint for a hovered destructive affordance —
  /// enough red to warn, not enough to shout.
  Color get errorHover => Color.lerp(surface, error, 0.3) ?? surface;

  /// Scrollbar grip.
  Color get scrollGrip => Color.lerp(muted, primary, 0.8) ?? muted;

  /// Resting fill behind a row that carries an app-wide action.
  Color get primaryTint => Color.lerp(background, primary, 0.12) ?? background;

  /// [primaryTint] deepened for the selected or hovered row.
  Color get primaryTintSelected =>
      Color.lerp(background, primary, 0.24) ?? background;
}

@model
class AppTheme extends InheritedComponent {
  const AppTheme({
    required this.data,
    required super.child,
    super.key,
  });

  final AppThemeData data;

  static AppThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedComponentOfExactType<AppTheme>();
    return theme!.data;
  }

  @override
  bool updateShouldNotify(AppTheme oldComponent) {
    return data != oldComponent.data;
  }
}

const AppThemeData floppyDrive = AppThemeData(
  name: 'Floppy Drive',
  brightness: Brightness.dark,
  background: Color(0x0000AA),
  onBackground: Color(0xFFFF55),
  surface: Color(0x1A1ABB),
  onSurface: Color(0xFFFF55),
  primary: Color(0xFFFF55),
  onPrimary: Color(0x0000AA),
  accent: Color(0xAAAA00),
  secondary: Color(0x55FFFF),
  onSecondary: Color(0x0000AA),
  error: Color(0xFF5555),
  onError: Color(0x0000AA),
  errorAccent: Color(0xAA0000),
  success: Color(0x55FF55),
  onSuccess: Color(0x0000AA),
  successAccent: Color(0x00AA00),
  warning: Color(0xFFAA00),
  onWarning: Color(0x0000AA),
  outline: Color(0x8888DD),
  outlineVariant: Color(0xAAAAAA),
  selection: Color(0xFFFF55),
  onSelection: Color(0x0000AA),
  info: Color(0x55FFFF),
  onInfo: Color(0x0000AA),
  infoAccent: Color(0x00AAAA),
  muted: Color(0x9999DD),
  onMuted: Color(0xFFFFFF),
  mutedAccent: Color(0x5555AA),
  loading: Color(0xFFFF55),
  surfaceAccent: Color(0x0000DD),
  highVisibility: Color(0xFFAA00),
);

const AppThemeData neo = AppThemeData(
  name: 'Neo',
  brightness: Brightness.dark,
  background: Color(0x000000),
  onBackground: Color(0x00DD33),
  surface: Color(0x001A06),
  onSurface: Color(0x00CC22),
  primary: Color(0x00FF41),
  onPrimary: Color(0x000000),
  accent: Color(0x008822),
  secondary: Color(0xCCFFCC),
  onSecondary: Color(0x000000),
  error: Color(0xFF3838),
  onError: Color(0x000000),
  errorAccent: Color(0xA01818),
  success: Color(0x60FF80),
  onSuccess: Color(0x000000),
  successAccent: Color(0x208840),
  warning: Color(0xFFCC00),
  onWarning: Color(0x000000),
  outline: Color(0x004A1A),
  outlineVariant: Color(0x006028),
  selection: Color(0x00FF41),
  onSelection: Color(0x000000),
  info: Color(0x00CCAA),
  onInfo: Color(0x000000),
  infoAccent: Color(0x008870),
  muted: Color(0x408050),
  onMuted: Color(0x00DD33),
  mutedAccent: Color(0x204828),
  loading: Color(0x40FF60),
  surfaceAccent: Color(0x002818),
  highVisibility: Color(0xFFFFFF),
);
