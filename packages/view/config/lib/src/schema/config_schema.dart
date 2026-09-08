import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_config_view/src/schema/app_config_contribution.dart';
import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:bestie_config_view/src/schema/config_layout.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// The typed key handle and the overlay layout every feature contributed to.
@model
final class ConfigSchema {
  const ConfigSchema({required this.keys, required this.layout});

  final BestieConfigKeys keys;
  final ConfigLayout layout;
}

/// Gathers every feature's config contribution, assembles the typed key handle,
/// and composes the overlay layout.
ConfigSchema buildConfigSchema({
  required String defaultSystemPrompt,
  required String defaultTheme,
  required List<String> availableThemes,
}) {
  final app = AppConfigContribution(
    defaultTheme: defaultTheme,
    availableThemes: availableThemes,
  );
  final mascot = MascotConfigContribution();
  final chat = ChatConfigContribution(defaultSystemPrompt: defaultSystemPrompt);
  final tools = ToolsConfigContribution();
  final shell = ShellConfigContribution();
  final sandbox = SandboxConfigContribution();
  final provider = ProviderConfigContribution();

  final contributions = <ConfigContribution>[
    app,
    mascot,
    chat,
    tools,
    shell,
    sandbox,
    provider,
  ];

  final keys = BestieConfigKeys(
    app: app.configKeys,
    mascot: mascot.configKeys,
    chat: chat.configKeys,
    provider: provider.configKeys,
    shell: shell.configKeys,
    sandbox: sandbox.configKeys,
    tools: tools.configKeys,
  );

  return ConfigSchema(
    keys: keys,
    layout: buildConfigLayout(contributions, keys),
  );
}
