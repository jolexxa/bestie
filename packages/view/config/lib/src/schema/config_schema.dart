import 'package:bestie_built_in_server_use_case/bestie_built_in_server_use_case.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:bestie_config_view/src/schema/config_layout.dart';
import 'package:bestie_fireworks_use_case/bestie_fireworks_use_case.dart';
import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_openai_endpoint_use_case/bestie_openai_endpoint_use_case.dart';
import 'package:bestie_openrouter_use_case/bestie_openrouter_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// The typed key handle and the overlay layout built from it.
@model
final class ConfigSchema {
  const ConfigSchema({required this.keys, required this.layout});

  final BestieConfigKeys keys;
  final ConfigLayout layout;
}

/// Assembles every feature's keys into the typed key handle and composes the
/// overlay layout.
ConfigSchema buildConfigSchema({
  required String defaultSystemPrompt,
  required String defaultTheme,
  required List<String> availableThemes,
}) {
  final keys = BestieConfigKeys(
    app: AppConfigKeys.defaults(
      defaultTheme: defaultTheme,
      availableThemes: availableThemes,
    ),
    mascot: MascotConfigKeys.defaults(),
    chat: ChatConfigKeys.defaults(defaultSystemPrompt: defaultSystemPrompt),
    provider: ProviderConfigKeys.defaults(),
    builtInServer: BuiltInServerConfigKeys.defaults(),
    openAiEndpoint: OpenAiEndpointConfigKeys.defaults(),
    openRouter: OpenRouterConfigKeys.defaults(),
    fireworks: FireworksConfigKeys.defaults(),
    localModels: LocalModelsConfigKeys.defaults(),
    shell: ShellConfigKeys.defaults(),
    sandbox: SandboxConfigKeys.defaults(),
    tools: ToolsConfigKeys.defaults(),
  );

  return ConfigSchema(keys: keys, layout: buildConfigLayout(keys));
}
