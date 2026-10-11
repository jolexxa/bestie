import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime;
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

final class _MockProviderRepository extends Mock
    implements ProviderRepository {}

final class _MockAgentRuntime extends Mock implements AgentRuntime {}

final class _MockAgentRepository extends Mock implements AgentRepository {}

final class _MockAgentSession extends Mock implements AgentSession {}

final class _MockProvider extends Mock implements Provider {}

const _modelRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'org/model',
);

const _model = ProviderModelInfo(
  id: 'org/model',
  name: 'Model',
  contextLength: 8192,
  supportsTools: true,
);

const _fireworksRef = ProviderModelRef(
  providerId: 'fireworks',
  modelId: 'accounts/fireworks/models/kimi',
);

const _fireworksModel = ProviderModelInfo(
  id: 'accounts/fireworks/models/kimi',
  name: 'Kimi',
  contextLength: 131072,
  supportsTools: true,
);

const _emptyList = ModelList(models: [], failures: []);

Provider _provider(
  String id,
  String displayName,
  ProviderCredentialsKind credentialsKind,
) {
  final provider = _MockProvider();
  when(() => provider.id).thenReturn(id);
  when(() => provider.displayName).thenReturn(displayName);
  when(() => provider.credentialsKind).thenReturn(credentialsKind);
  return provider;
}

final Provider _local = _provider(
  'local',
  'Bestie Server',
  ProviderCredentialsKind.none,
);

final Provider _custom = _provider(
  'custom',
  'Custom endpoint',
  ProviderCredentialsKind.endpoint,
);

final Provider _openRouter = _provider(
  'openrouter',
  'OpenRouter',
  ProviderCredentialsKind.apiKey,
);

final Provider _fireworks = _provider(
  'fireworks',
  'Fireworks AI',
  ProviderCredentialsKind.apiKey,
);

final List<Provider> _providers = [_local, _custom, _openRouter, _fireworks];

const _failure = ProviderUnreachable('offline');

final class _Harness {
  _Harness({Map<String, Object?> values = const {}}) {
    config = FakeConfigRepository(values);
    registerFallbackValue(
      const ProviderSettings(credentials: {}, model: null, maxAgents: 1),
    );
    when(() => repository.status).thenAnswer((_) => status);
    when(
      () => repository.statusStream,
    ).thenAnswer((_) => statusController.stream);
    when(() => repository.configure(any())).thenReturn(null);
    when(repository.reconnect).thenReturn(null);
    when(() => agents.primary).thenReturn(primarySession);
    when(
      () => agents.primaryConversationStream,
    ).thenAnswer((_) => conversationController.stream);
    when(() => agents.spendStream).thenAnswer((_) => spendController.stream);
    when(() => primarySession.conversationPhase).thenAnswer((_) => phase);
    useCase = ProviderUseCase(
      config: config,
      configKeys: configKeys,
      providerRepository: repository,
      agentRepository: agents,
    );
  }

  final repository = _MockProviderRepository();
  final agents = _MockAgentRepository();
  final primarySession = _MockAgentSession();
  final configKeys = ProviderConfigKeys.forProviders(_providers);
  final statusController = StreamController<ProviderStatus>.broadcast();
  final conversationController =
      StreamController<ConversationState>.broadcast();
  final spendController = StreamController<double>.broadcast();
  late final FakeConfigRepository config;
  late final ProviderUseCase useCase;
  ProviderStatus status = const ProviderStatusUnconfigured();
  ConversationPhase phase = ConversationPhase.idle;

  void beginTurn() {
    phase = ConversationPhase.turnInFlight;
    conversationController.add(
      const TurnInProgress(
        timelineItems: [],
        conversationPhase: ConversationPhase.turnInFlight,
        activity: TurnActivity.thinking,
      ),
    );
  }

  void endTurn() {
    phase = ConversationPhase.idle;
    conversationController.add(
      const ConversationIdle(
        timelineItems: [],
        conversationPhase: ConversationPhase.idle,
      ),
    );
  }

  void becomeReady() {
    status = ProviderStatusReady(
      model: const ResolvedModel(
        ref: _modelRef,
        name: 'Model',
        providerName: 'Example',
        contextWindow: 8192,
        supportsTools: true,
      ),
      runtime: _MockAgentRuntime(),
      maxAgents: 3,
      deviceBytes: null,
    );
    statusController.add(status);
  }

  void becomeFailed() {
    status = const ProviderStatusFailed(failure: _failure, model: _modelRef);
    statusController.add(status);
  }

  Command command(String id) =>
      useCase.commands.singleWhere((command) => command.id == id);

  List<ProviderSettings> get configured => verify(
    () => repository.configure(captureAny()),
  ).captured.cast<ProviderSettings>();
}

extension on Command {
  CommandFlow get flow => body as CommandFlow;
}

void main() {
  group('ProviderConfigKeys', () {
    final keys = ProviderConfigKeys.forProviders(_providers);
    final local = keys.accounts[0];
    final custom = keys.accounts[1];
    final openRouter = keys.accounts[2];
    final fireworks = keys.accounts[3];

    test('keeps an account per provider, in the order given', () {
      expect(keys.accounts.map((account) => account.provider), _providers);
    });

    test('builds the settings from every account and session key', () {
      expect(keys.settingsKeys, [
        custom.baseUrl,
        custom.apiKey,
        custom.contextWindow,
        openRouter.apiKey,
        fireworks.apiKey,
        keys.model,
        keys.maxAgents,
        keys.contextCap,
      ]);
      expect(keys.model.defaultValue(), defaultProviderModel);
    });

    test('keeps every setting where it was stored', () {
      expect(openRouter.apiKey.id, 'provider.openrouter.api_key');
      expect(openRouter.apiKey.path, ['provider', 'openrouter', 'apiKey']);
      expect(fireworks.apiKey.path, ['provider', 'fireworks', 'apiKey']);
      expect(custom.apiKey.id, 'provider.custom.api_key');
      expect(custom.baseUrl.id, 'provider.custom.base_url');
      expect(custom.baseUrl.path, ['provider', 'custom', 'baseUrl']);
      expect(custom.contextWindow.id, 'provider.custom.context_window');
      expect(custom.contextWindow.path, [
        'provider',
        'custom',
        'contextWindow',
      ]);
      expect(custom.contextWindow.defaultValue(), defaultCustomContextWindow);
      expect(keys.contextCap.id, 'provider.local.context_cap');
      expect(keys.contextCap.path, ['provider', 'local', 'contextCap']);
      expect(keys.contextCap.defaultValue(), 0);
    });

    test('shows each provider only the settings it has', () {
      expect(local.keys, isEmpty);
      expect(local.addresses, isEmpty);
      expect(custom.keys, [
        custom.baseUrl,
        custom.apiKey,
        custom.contextWindow,
      ]);
      expect(openRouter.keys, [openRouter.apiKey]);
      expect(
        openRouter.addresses.map((address) => address.key),
        [openRouter.apiKey],
      );
    });

    test('words every field after its provider', () {
      expect(openRouter.apiKey.field.label, 'OpenRouter API key');
      expect(
        openRouter.apiKey.field.description,
        'Your OpenRouter key. Bestie reconnects when it changes.',
      );
      expect(custom.apiKey.field.label, 'Custom endpoint API key');
      expect(
        custom.apiKey.field.description,
        'Bearer token for the endpoint, if it wants one.',
      );
      expect(custom.baseUrl.field.label, 'Custom endpoint URL');
      expect(
        custom.contextWindow.field.label,
        'Custom endpoint context window',
      );
    });

    test('masks every API key and nothing else', () {
      final secret = [openRouter.apiKey, fireworks.apiKey, custom.apiKey];
      final shown = [
        custom.baseUrl,
        custom.contextWindow,
        keys.contextCap,
        keys.model,
        keys.maxAgents,
      ];

      expect(secret.map((key) => key.field.secret), everyElement(isTrue));
      expect(shown.map((key) => key.field.secret), everyElement(isFalse));
    });
  });

  group('ProviderUseCase', () {
    test('configures the repository from config at construction', () {
      final harness = _Harness(values: {'provider.openrouter.api_key': 'sk'});

      expect(harness.configured, [
        const ProviderSettings(
          credentials: {'openrouter': ApiKeyCredentials('sk')},
          model: ProviderModelRef(
            providerId: 'openrouter',
            modelId: 'openai/gpt-4o-mini',
          ),
          maxAgents: 3,
        ),
      ]);
    });

    test('trims the API key it is given', () {
      final harness = _Harness(
        values: {'provider.openrouter.api_key': ' sk\n'},
      );

      expect(
        harness.useCase.settings.credentials['openrouter'],
        const ApiKeyCredentials('sk'),
      );
    });

    test('gives no credentials for a key left blank', () {
      final harness = _Harness(values: {'provider.fireworks.api_key': '  '});

      expect(harness.useCase.settings.credentials, isEmpty);
    });

    test('reads the custom endpoint from config', () {
      final harness = _Harness(
        values: {
          'provider.custom.base_url': ' http://localhost:8080/v1 ',
          'provider.custom.api_key': 'tok',
          'provider.custom.context_window': 8192,
          'provider.model': 'custom:local',
        },
      );

      expect(
        harness.useCase.settings.credentials['custom'],
        EndpointCredentials(
          baseUrl: Uri.parse('http://localhost:8080/v1'),
          apiKey: 'tok',
          fallbackContextWindow: 8192,
        ),
      );
      expect(
        harness.useCase.settings.model,
        const ProviderModelRef(providerId: 'custom', modelId: 'local'),
      );
    });

    test('reaches an endpoint without a key when it wants none', () {
      final harness = _Harness(
        values: {'provider.custom.base_url': 'http://localhost:8080/v1'},
      );

      final credentials =
          harness.useCase.settings.credentials['custom']!
              as EndpointCredentials;
      expect(credentials.apiKey, isNull);
      expect(credentials.fallbackContextWindow, defaultCustomContextWindow);
    });

    test('ignores a custom endpoint that is not an absolute URL', () {
      final harness = _Harness(values: {'provider.custom.base_url': 'garbage'});

      expect(harness.useCase.settings.credentials, isEmpty);
    });

    test('caps the context at the configured cap', () {
      final harness = _Harness(values: {'provider.local.context_cap': 8192});

      expect(harness.useCase.settings.contextCap, 8192);
    });

    test('leaves the context uncapped when the cap is zero', () {
      expect(_Harness().useCase.settings.contextCap, isNull);
    });

    test('reconfigures when a settings key changes', () async {
      final harness = _Harness();
      harness.config['provider.model'] = 'openrouter:org/other';
      await pumpEventQueue();

      final configured = harness.configured;
      expect(configured, hasLength(2));
      expect(configured.last.model?.modelId, 'org/other');
    });

    test('ignores changes to keys the settings are not built from', () async {
      final harness = _Harness();
      harness.config['app.theme'] = 'dark';
      await pumpEventQueue();

      expect(harness.configured, hasLength(1));
    });

    test('forwards status, models, and reconnects', () async {
      final harness = _Harness();
      when(harness.repository.models).thenAnswer((_) async => _emptyList);

      expect(harness.useCase.status, isA<ProviderStatusUnconfigured>());
      expect(harness.useCase.statusStream, harness.statusController.stream);
      expect(await harness.useCase.models(), _emptyList);
      harness.useCase.reconnect();
      verify(harness.repository.reconnect).called(1);
    });

    test('selectModel commits the model key', () {
      final harness = _Harness()..useCase.selectModel('org/picked');

      expect(harness.config['provider.model'], 'org/picked');
    });

    group('refresh credits command', () {
      test('follows readiness', () async {
        final harness = _Harness();
        final command = harness.command('provider.refresh_credits');
        final availability = <Availability>[];
        expect(
          await command.flow.invoke(const Answers.empty()),
          isA<CommandRejected>(),
        );
        final subscription = command.availability.listen(availability.add);
        harness.becomeReady();
        await pumpEventQueue();
        await subscription.cancel();

        expect(availability, [
          isA<Unavailable>().having(
            (unavailable) => unavailable.reason,
            'reason',
            'provider is not connected',
          ),
          isA<Available>(),
        ]);
      });

      test('publishes the fetched credits', () async {
        final harness = _Harness();
        const credits = ProviderCredits(
          spent: 2,
          remaining: 8,
          window: SpendWindow.lifetime,
        );
        when(harness.repository.credits).thenAnswer(
          (_) async => const CreditsFetched(credits),
        );
        final published = <CreditsResult>[];
        harness.useCase.creditsStream.listen(published.add);
        harness.becomeReady();

        final result = await harness
            .command('provider.refresh_credits')
            .flow
            .invoke(const Answers.empty());
        await pumpEventQueue();

        expect(result, isA<CommandRan>());
        expect(published.single, isA<CreditsFetched>());
        expect(
          (harness.useCase.lastCredits! as CreditsFetched).credits,
          credits,
        );
      });

      test('rejects with the failure message', () async {
        final harness = _Harness();
        when(harness.repository.credits).thenAnswer(
          (_) async => const CreditsFailed(_failure),
        );
        harness.becomeReady();

        final result = await harness
            .command('provider.refresh_credits')
            .flow
            .invoke(const Answers.empty());

        expect(
          result,
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'offline',
          ),
        );
        expect(harness.useCase.lastCredits, isA<CreditsFailed>());
      });

      test('rejects when the provider has no credits to report', () async {
        final harness = _Harness();
        when(harness.repository.credits).thenAnswer(
          (_) async => const CreditsUnsupported(),
        );
        harness.becomeReady();

        final result = await harness
            .command('provider.refresh_credits')
            .flow
            .invoke(const Answers.empty());

        expect(
          result,
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'this provider does not report credits',
          ),
        );
        expect(harness.useCase.lastCredits, isA<CreditsUnsupported>());
      });
    });

    group('charges as completions report their cost', () {
      const fetched = CreditsFetched(
        ProviderCredits(spent: 4, remaining: 6, window: SpendWindow.lifetime),
      );

      test('books each charge against the fetched balance', () async {
        final harness = _Harness();
        when(harness.repository.credits).thenAnswer((_) async => fetched);
        final published = <CreditsResult>[];
        harness.useCase.creditsStream.listen(published.add);
        await harness.useCase.refreshCredits();

        harness.spendController.add(0.5);
        await Future<void>.delayed(Duration.zero);

        expect(
          (harness.useCase.lastCredits! as CreditsFetched).credits,
          const ProviderCredits(
            spent: 4.5,
            remaining: 5.5,
            window: SpendWindow.lifetime,
          ),
        );
        expect(published, hasLength(2));
        expect(published.last, harness.useCase.lastCredits);
      });

      test('leaves a balance the provider never gave alone', () async {
        final harness = _Harness();
        when(
          harness.repository.credits,
        ).thenAnswer((_) async => const CreditsUnsupported());
        await harness.useCase.refreshCredits();
        final published = <CreditsResult>[];
        harness.useCase.creditsStream.listen(published.add);

        harness.spendController.add(0.5);
        await Future<void>.delayed(Duration.zero);

        expect(harness.useCase.lastCredits, isA<CreditsUnsupported>());
        expect(published, isEmpty);
      });
    });

    group('select model command', () {
      test('waits for the primary turn to finish', () async {
        final harness = _Harness()..becomeReady();
        final command = harness.command('provider.select_model');
        final availability = <Availability>[];
        final subscription = command.availability.listen(availability.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        harness.beginTurn();
        await pumpEventQueue();

        expect(
          await command.flow.invoke(
            const Answers.empty().put(
              const ParamKey<String>('model'),
              'openrouter:other/model',
            ),
          ),
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'turn in progress',
          ),
        );
        expect(
          harness.config['provider.model'],
          isNot('openrouter:other/model'),
        );

        harness.endTurn();
        await pumpEventQueue();

        expect(availability.last, isA<Available>());
        expect(availability, contains(isA<Unavailable>()));
      });

      test('needs a configured provider', () async {
        final harness = _Harness();
        final command = harness.command('provider.select_model');
        final availability = <Availability>[];
        final subscription = command.availability.listen(availability.add);
        harness.becomeFailed();
        await pumpEventQueue();
        await subscription.cancel();

        expect(availability, [isA<Unavailable>(), isA<Available>()]);
        harness.status = const ProviderStatusUnconfigured();
        expect(
          await command.flow.invoke(
            const Answers.empty().put(
              const ParamKey<String>('model'),
              'x',
            ),
          ),
          isA<CommandRejected>(),
        );
      });

      test("offers every provider's models then commits the choice", () async {
        final harness = _Harness();
        when(harness.repository.models).thenAnswer(
          (_) async => const ModelList(
            models: [
              ListedModel(
                ref: _modelRef,
                model: _model,
                providerName: 'OpenRouter',
                hasAccess: true,
              ),
              ListedModel(
                ref: _fireworksRef,
                model: _fireworksModel,
                providerName: 'Fireworks AI',
                hasAccess: false,
              ),
            ],
            failures: [],
          ),
        );
        harness.becomeFailed();
        final command = harness.command('provider.select_model');

        final param =
            command.flow.next(const Answers.empty())! as ChoiceParam<String>;
        final options = (await param.options.toList()).single;
        expect(options.map((option) => option.value), [
          'openrouter:org/model',
          'fireworks:accounts/fireworks/models/kimi',
        ]);
        expect(options.map((option) => option.label), ['Model', 'Kimi']);
        expect(options.map((option) => option.detail), [
          'OpenRouter · org/model',
          'Fireworks AI · accounts/fireworks/models/kimi (not set up)',
        ]);
        expect(options.map((option) => option.keywords), [
          'OpenRouter Model org/model',
          'Fireworks AI Kimi accounts/fireworks/models/kimi',
        ]);

        final answers = const Answers.empty().put(
          param.key,
          'fireworks:accounts/fireworks/models/kimi',
        );
        expect(command.flow.next(answers), isNull);
        expect(await command.flow.invoke(answers), isA<CommandRan>());
        expect(
          harness.config['provider.model'],
          'fireworks:accounts/fireworks/models/kimi',
        );
      });

      test('offers nothing when no provider can be listed', () async {
        final harness = _Harness();
        when(harness.repository.models).thenAnswer(
          (_) async => const ModelList(models: [], failures: [_failure]),
        );
        final command = harness.command('provider.select_model');

        final param =
            command.flow.next(const Answers.empty())! as ChoiceParam<String>;
        final options = await param.options.toList();

        expect(options.single, isEmpty);
      });
    });

    group('reconnect command', () {
      test('will not reconnect underneath a running turn', () async {
        final harness = _Harness()
          ..becomeReady()
          ..beginTurn();
        final command = harness.command('provider.reconnect');

        expect(
          await command.flow.invoke(const Answers.empty()),
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'turn in progress',
          ),
        );
        verifyNever(harness.repository.reconnect);
      });

      test('reconnects a configured provider', () async {
        final harness = _Harness();
        final command = harness.command('provider.reconnect');

        expect(
          await command.flow.invoke(const Answers.empty()),
          isA<CommandRejected>(),
        );
        harness.becomeFailed();
        expect(
          await command.flow.invoke(const Answers.empty()),
          isA<CommandRan>(),
        );
        verify(harness.repository.reconnect).called(1);
      });
    });

    test('dispose stops following config and closes credits', () async {
      final harness = _Harness();

      await harness.useCase.dispose();
      harness.config['provider.model'] = 'openrouter:org/other';
      await pumpEventQueue();

      expect(harness.configured, hasLength(1));
      await expectLater(harness.useCase.creditsStream, emitsDone);
    });
  });
}
