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

const _failure = ProviderUnreachable('offline');

final class _Harness {
  _Harness({Map<String, Object?> values = const {}}) {
    config = FakeConfigRepository(values);
    registerFallbackValue(const ProviderSettings(model: null, maxAgents: 1));
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
  final configKeys = ProviderConfigKeys.defaults();
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
    final keys = ProviderConfigKeys.defaults();

    test('builds the settings from the model and the agents', () {
      expect(keys.settingsKeys, [keys.model, keys.maxAgents]);
    });

    test('keeps every setting where it was stored', () {
      expect(keys.model.id, 'provider.model');
      expect(keys.model.path, ['provider', 'model']);
      expect(keys.model.defaultValue(), defaultProviderModel);
      expect(keys.maxAgents.id, 'provider.max_agents');
      expect(keys.maxAgents.path, ['provider', 'maxAgents']);
      expect(keys.maxAgents.defaultValue(), defaultProviderMaxAgents);
    });

    test('masks nothing', () {
      expect(keys.model.field.secret, isFalse);
      expect(keys.maxAgents.field.secret, isFalse);
    });
  });

  group('ProviderUseCase', () {
    test('configures the repository from config at construction', () {
      final harness = _Harness(values: {'provider.max_agents': 2});

      expect(harness.configured, [
        const ProviderSettings(
          model: ProviderModelRef(
            providerId: 'openrouter',
            modelId: 'openai/gpt-4o-mini',
          ),
          maxAgents: 2,
        ),
      ]);
    });

    test('reads the chosen model from config', () {
      final harness = _Harness(values: {'provider.model': 'custom:local'});

      expect(
        harness.useCase.settings.model,
        const ProviderModelRef(providerId: 'custom', modelId: 'local'),
      );
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
