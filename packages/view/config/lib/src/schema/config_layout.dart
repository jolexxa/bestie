import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:bestie_config_view/src/state/info_layout.dart';
import 'package:config_protocol/config_protocol.dart';

/// Arranges each feature's settings into the config overlay's cross-feature
/// page layout.
ConfigLayout buildConfigLayout(BestieConfigKeys keys) {
  final provider = keys.provider;
  final sampling = keys.chat.sampling;

  return ConfigLayout(
    initialPageId: 'app',
    pages: [
      ConfigParamPage(
        id: 'app',
        label: 'App',
        sections: [
          ConfigSection(
            heading: 'App',
            addresses: [
              keys.app.themeName.global,
              keys.app.themeEffects.global,
              keys.app.mathColors.global,
              keys.mascot.mascot.global,
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
            addresses: [keys.chat.systemPrompt.global],
          ),
          ConfigSection(
            heading: 'Memory',
            addresses: [keys.chat.memoryCompactionRatio.global],
          ),
          ConfigSection(
            heading: 'Tools',
            addresses: [
              keys.chat.maxToolCallCharacters.global,
              keys.tools.concurrentTools.global,
            ],
          ),
        ],
      ),
      ConfigParamPage(
        id: 'provider',
        label: 'Provider',
        sections: [
          ConfigSection(
            heading: 'Local models',
            addresses: [
              keys.localModels.paths.global,
              provider.contextCap.global,
            ],
          ),
          for (final account in provider.accounts)
            if (account.addresses.isNotEmpty)
              ConfigSection(
                heading: account.provider.displayName,
                addresses: account.addresses,
              ),
          ConfigSection(
            heading: 'Agents',
            addresses: [provider.maxAgents.global],
          ),
          ConfigSection(
            heading: 'Sampling',
            addresses: [
              sampling.temperature.global,
              sampling.topP.global,
              sampling.frequencyPenalty.global,
              sampling.presencePenalty.global,
              sampling.seed.global,
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
            addresses: [
              keys.sandbox.sandboxAgentShell.global,
              keys.sandbox.sandboxFailClosed.global,
            ],
          ),
          ConfigSection(
            heading: 'Network',
            addresses: [keys.sandbox.sandboxNetworkTier.global],
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
