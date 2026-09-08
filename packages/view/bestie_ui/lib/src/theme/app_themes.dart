import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:bestie_ui/src/theme/theme_presets.dart';

const AppThemeData appThemeDefault = asdn;

/// Every selectable theme by display name: the generated palettes first,
/// then the hand-authored gimmicks.
final Map<String, AppThemeData> appThemes = {
  asdn.name: asdn,
  hotCocoa.name: hotCocoa,
  midnight.name: midnight,
  honeyBee.name: honeyBee,
  santa.name: santa,
  pasture.name: pasture,
  newspaper.name: newspaper,
  lavenderField.name: lavenderField,
  seafoam.name: seafoam,
  doubleBubble.name: doubleBubble,
  neo.name: neo,
  floppyDrive.name: floppyDrive,
};
