import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class AppConfigContribution implements ConfigContribution {
  AppConfigContribution({
    required String defaultTheme,
    required List<String> availableThemes,
  }) : configKeys = AppConfigKeys.defaults(defaultTheme: defaultTheme),
       _availableThemes = availableThemes;

  final AppConfigKeys configKeys;
  final List<String> _availableThemes;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.themeName,
      field: EnumField<String>(
        label: 'Theme',
        description: 'Color theme used across the app.',
        options: () => _availableThemes,
        optionLabel: (theme) => theme,
      ),
    ),
    globalEntry(
      key: configKeys.themeEffects,
      field: BoolField(
        label: 'Theme Effects',
        description: 'Animated overlays for select themes.',
      ),
    ),
    globalEntry(
      key: configKeys.mathColors,
      field: BoolField(
        label: 'Math Colors',
        description: 'Color each variable in rendered equations.',
      ),
    ),
  ];
}
