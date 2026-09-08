import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show SamplingOptions;
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_provider_use_case/src/built_in_providers.dart';
import 'package:bestie_provider_use_case/src/provider_config_keys.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';

/// Keeps the provider session in step with configuration and exposes the
/// provider's account facts to the UI and the palette.
@useCase
class ProviderUseCase implements CommandContribution {
  ProviderUseCase({
    required ConfigRepository config,
    required ProviderConfigKeys configKeys,
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
  }) : _config = config,
       _configKeys = configKeys,
       _providers = providerRepository,
       _agents = agentRepository {
    commands = List.unmodifiable([
      Command(
        id: 'provider.refresh_credits',
        title: 'Refresh credits',
        glyph: r'$',
        description: 'Re-check the remaining provider balance',
        group: 'Provider',
        availability: _readyAvailability(),
        invoke: _refreshCreditsInvoke,
      ),
      Command(
        id: 'provider.select_model',
        title: 'Select model',
        glyph: '◆',
        description: 'Choose the model every new turn runs on',
        tier: CommandTier.primary,
        group: 'Provider',
        availability: _idleAvailability(),
        next: _selectModelFlow,
        invoke: _selectModelInvoke,
      ),
      Command(
        id: 'provider.reconnect',
        title: 'Reconnect provider',
        glyph: '↻',
        description: 'Reopen the connection to the configured providers',
        group: 'Provider',
        availability: _idleAvailability(),
        invoke: _reconnectInvoke,
      ),
    ]);
    _providers.configure(settings);
    _configSub = _config.changes.listen(_onConfigChange);
    _spendSub = _agents.spendStream.listen(_charge);
  }

  @override
  late final List<Command> commands;

  static const _modelKey = ParamKey<String>('model');
  static const _noProvider = 'no provider configured';
  static const _notReady = 'provider is not connected';
  static const _turnInProgress = 'turn in progress';
  static const _creditsUnsupportedReason =
      'this provider does not report credits';

  final ConfigRepository _config;
  final ProviderConfigKeys _configKeys;
  final ProviderRepository _providers;
  final AgentRepository _agents;
  late final StreamSubscription<ConfigChange> _configSub;
  late final StreamSubscription<double> _spendSub;
  final _creditsController = StreamController<CreditsResult>.broadcast();
  CreditsResult? _lastCredits;

  late final Set<String> _sessionKeyIds = {
    for (final key in _configKeys.sessionKeys) key.id,
  };

  /// The session settings as configured right now; accounts are listed in
  /// the order their models should appear, the user's own endpoint first.
  ProviderSettings get settings => ProviderSettings(
    accounts: [
      ProviderAccount(
        descriptor: customDescriptor,
        apiKey: _resolve(_configKeys.customApiKey),
        baseUrl: _endpointUrl(_resolve(_configKeys.customBaseUrl)),
        fallbackContextWindow: _resolve(_configKeys.customContextWindow),
      ),
      ProviderAccount(
        descriptor: openRouterDescriptor,
        apiKey: _resolve(_configKeys.openRouterApiKey),
      ),
      ProviderAccount(
        descriptor: fireworksDescriptor,
        apiKey: _resolve(_configKeys.fireworksApiKey),
      ),
    ],
    model: ProviderModelRef.parse(_resolve(_configKeys.model)),
    maxAgents: _resolve(_configKeys.maxAgents),
  );

  /// The sampling every turn runs under, as configured right now.
  SamplingOptions get sampling => SamplingOptions(
    seed: _config.resolve(_configKeys.sampling.seed.global),
    temperature: _config.resolve(_configKeys.sampling.temperature.global),
    topP: _config.resolve(_configKeys.sampling.topP.global),
    penaltyFreq: _config.resolve(_configKeys.sampling.frequencyPenalty.global),
    penaltyPresent: _config.resolve(
      _configKeys.sampling.presencePenalty.global,
    ),
  );

  ProviderStatus get status => _providers.status;

  Stream<ProviderStatus> get statusStream => _providers.statusStream;

  /// The most recent credits fetch, if any.
  CreditsResult? get lastCredits => _lastCredits;

  /// Every credits fetch as it lands.
  Stream<CreditsResult> get creditsStream => _creditsController.stream;

  Future<CreditsResult> refreshCredits() async {
    final result = await _providers.credits();
    _lastCredits = result;
    _creditsController.add(result);
    return result;
  }

  /// Books a completion's charge against the last fetched balance so the
  /// reading moves before the provider is asked again.
  void _charge(double cost) {
    if (_lastCredits case CreditsFetched(:final credits)) {
      final charged = CreditsFetched(credits.charged(cost));
      _lastCredits = charged;
      _creditsController.add(charged);
    }
  }

  Future<KeyInfoResult> keyInfo() => _providers.keyInfo();

  /// Every model across every provider, whether or not it can be used yet.
  Future<ModelList> models() => _providers.models();

  void reconnect() => _providers.reconnect();

  /// Persist [modelId] as the model to run; the session follows the change.
  void selectModel(String modelId) => _config.commit({
    _configKeys.model.global: ConfigEdit<String>.set(modelId),
  });

  Future<void> dispose() async {
    await _configSub.cancel();
    await _spendSub.cancel();
    await _creditsController.close();
  }

  T _resolve<T>(ConfigKey<T> key) => _config.resolve(key.global);

  /// An absolute URL, or null when the setting is blank or not one.
  static Uri? _endpointUrl(String setting) {
    final url = Uri.tryParse(setting.trim());
    return url != null && url.hasScheme && url.host.isNotEmpty ? url : null;
  }

  void _onConfigChange(ConfigChange change) {
    if (!change.keyIds.any(_sessionKeyIds.contains)) return;
    _providers.configure(settings);
  }

  // ── Palette commands ─────────────────────────────────────

  bool get _ready => status is ProviderStatusReady;

  bool get _configured => status is! ProviderStatusUnconfigured;

  Stream<Availability> _readyAvailability() => gatedAvailability(
    () => status,
    statusStream,
    (_) => _ready ? const Available() : const Unavailable(_notReady),
  );

  /// Reconfiguring the provider tears down the live session, so the commands
  /// that do it wait for the primary to finish its turn.
  Availability _idleGate() {
    if (!_configured) return const Unavailable(_noProvider);
    if (_agents.primary.conversationPhase != ConversationPhase.idle) {
      return const Unavailable(_turnInProgress);
    }
    return const Available();
  }

  Stream<Availability> _idleAvailability() => gatedAvailabilityOn([
    statusStream,
    _agents.primaryConversationStream,
  ], _idleGate);

  Future<CommandResult> _refreshCreditsInvoke(Answers answers) async {
    if (!_ready) return const CommandRejected(_notReady);
    return switch (await refreshCredits()) {
      CreditsFetched() => const CommandRan(),
      CreditsFailed(:final failure) => CommandRejected(failure.message),
      CreditsUnsupported() => const CommandRejected(_creditsUnsupportedReason),
    };
  }

  Param? _selectModelFlow(Answers soFar) => soFar.maybe(_modelKey) == null
      ? ChoiceParam<String>(
          key: _modelKey,
          label: 'Model',
          options: _modelOptions(),
        )
      : null;

  Stream<List<Option<String>>> _modelOptions() =>
      Stream<List<Option<String>>>.multi((controller) async {
        final list = await models();
        controller.add([
          for (final listed in list.models)
            Option(
              value: listed.ref.qualified,
              label: listed.model.name,
              detail: _modelDetail(listed),
              keywords: _modelKeywords(listed),
            ),
        ]);
        await controller.close();
      });

  static String _modelKeywords(ListedModel listed) =>
      '${listed.providerName} ${listed.model.name} ${listed.model.id}';

  static String _modelDetail(ListedModel listed) =>
      '${listed.providerName} · ${listed.model.id}'
      '${listed.hasAccess ? '' : ' (no key)'}';

  Future<CommandResult> _selectModelInvoke(Answers answers) async {
    if (_idleGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    selectModel(answers.get(_modelKey));
    return const CommandRan();
  }

  Future<CommandResult> _reconnectInvoke(Answers answers) async {
    if (_idleGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    reconnect();
    return const CommandRan();
  }
}
