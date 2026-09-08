import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:bestie_config_view/src/state/info_layout.dart';
import 'package:config_protocol/config_protocol.dart';

/// Arranges the flat entries contributed by each feature into the config
/// overlay's cross-feature page layout.
ConfigLayout buildConfigLayout(
  List<ConfigContribution> contributions,
  BestieConfigKeys keys,
) {
  final byId = <String, ConfigEntry>{
    for (final contribution in contributions)
      for (final entry in contribution.entries) entry.key.id: entry,
  };

  ConfigEntry at(ConfigKeyBase key) => byId[key.id]!;

  final provider = keys.provider;
  final sampling = provider.sampling;

  return ConfigLayout(
    initialPageId: 'app',
    orphanEntries: [at(provider.model)],
    pages: [
      ConfigParamPage(
        id: 'app',
        label: 'App',
        sections: [
          ConfigSection(
            heading: 'App',
            entries: [
              at(keys.app.themeName),
              at(keys.app.themeEffects),
              at(keys.app.mathColors),
              at(keys.mascot.mascot),
            ],
          ),
        ],
      ),
      ConfigParamPage(
        id: 'agent',
        label: 'Agent',
        sections: [
          ConfigSection(
            heading: 'Prompt',
            entries: [at(keys.chat.systemPrompt)],
          ),
          ConfigSection(
            heading: 'Memory',
            entries: [at(keys.chat.memoryCompactionRatio)],
          ),
          ConfigSection(
            heading: 'Tools',
            entries: [
              at(keys.chat.maxToolCallCharacters),
              at(keys.tools.concurrentTools),
            ],
          ),
        ],
      ),
      ConfigParamPage(
        id: 'provider',
        label: 'Provider',
        sections: [
          ConfigSection(
            heading: 'OpenRouter',
            entries: [at(provider.openRouterApiKey)],
          ),
          ConfigSection(
            heading: 'Fireworks AI',
            entries: [at(provider.fireworksApiKey)],
          ),
          ConfigSection(
            heading: 'Custom endpoint',
            entries: [
              at(provider.customBaseUrl),
              at(provider.customApiKey),
              at(provider.customContextWindow),
            ],
          ),
          ConfigSection(
            heading: 'Agents',
            entries: [at(provider.maxAgents)],
          ),
          ConfigSection(
            heading: 'Sampling',
            entries: [
              at(sampling.temperature),
              at(sampling.topP),
              at(sampling.frequencyPenalty),
              at(sampling.presencePenalty),
              at(sampling.seed),
            ],
          ),
        ],
      ),
      ConfigParamPage(
        id: 'sandbox',
        label: 'Sandbox',
        sections: [
          ConfigSection(
            heading: 'Agent Shell',
            entries: [
              at(keys.sandbox.sandboxAgentShell),
              at(keys.sandbox.sandboxFailClosed),
            ],
          ),
          ConfigSection(
            heading: 'Network',
            entries: [at(keys.sandbox.sandboxNetworkTier)],
          ),
        ],
      ),
      ConfigInfoPage(
        id: 'info',
        label: 'Info',
        rowCount: (entryCount) => infoSelectableCount(toolCount: entryCount),
        visualIndex: (rowIndex, entryCount) =>
            infoVisualIndexFor(rowIndex, toolCount: entryCount),
      ),
      const ConfigDocumentPage(id: 'credits', label: 'Credits'),
    ],
  );
}
