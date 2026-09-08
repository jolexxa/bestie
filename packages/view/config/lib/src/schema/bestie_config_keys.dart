import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class BestieConfigKeys {
  const BestieConfigKeys({
    required this.app,
    required this.mascot,
    required this.chat,
    required this.provider,
    required this.shell,
    required this.sandbox,
    required this.tools,
  });

  final AppConfigKeys app;
  final MascotConfigKeys mascot;
  final ChatConfigKeys chat;
  final ProviderConfigKeys provider;
  final ShellConfigKeys shell;
  final SandboxConfigKeys sandbox;
  final ToolsConfigKeys tools;
}

@model
final class AppConfigKeys {
  const AppConfigKeys({
    required this.themeName,
    required this.themeEffects,
    required this.mathColors,
  });

  factory AppConfigKeys.defaults({required String defaultTheme}) =>
      AppConfigKeys(
        themeName: ConfigKey<String>(
          id: 'app.theme',
          path: const ['app', 'themeName'],
          codec: ConfigCodecs.strings,
          defaultValue: () => defaultTheme,
        ),
        themeEffects: ConfigKey<bool>(
          id: 'app.theme_effects',
          path: const ['app', 'themeEffects'],
          codec: ConfigCodecs.booleans,
          defaultValue: () => true,
        ),
        mathColors: ConfigKey<bool>(
          id: 'app.math_colors',
          path: const ['app', 'mathColors'],
          codec: ConfigCodecs.booleans,
          defaultValue: () => true,
        ),
      );

  final ConfigKey<String> themeName;
  final ConfigKey<bool> themeEffects;
  final ConfigKey<bool> mathColors;
}
