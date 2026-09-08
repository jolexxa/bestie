import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider, DisposeProviderSucceeded;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

final class _MockProvider extends Mock implements Provider {}

final class _MockInferenceClient extends Mock implements InferenceClient {}

final class _MockAgentProvider extends Mock implements AgentProvider {}

final class _MockModelCatalog extends Mock implements ModelCatalog {}

final class _SpawnCall {
  const _SpawnCall({
    required this.client,
    required this.modelId,
    required this.contextWindow,
    required this.maxAgents,
  });

  final InferenceClient client;
  final String modelId;
  final int contextWindow;
  final int maxAgents;
}

const _openRouter = ProviderDescriptor(
  id: 'openrouter',
  displayName: 'OpenRouter',
  requiresApiKey: true,
  dialect: InferenceDialect.openRouter,
  catalogId: 'openrouter',
);

final _fireworks = ProviderDescriptor(
  id: 'fireworks',
  displayName: 'Fireworks AI',
  requiresApiKey: true,
  dialect: InferenceDialect.openAi,
  baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
  catalogId: 'fireworks-ai',
);

const _custom = ProviderDescriptor(
  id: 'custom',
  displayName: 'Custom endpoint',
  requiresApiKey: false,
  dialect: InferenceDialect.openAi,
  requiresBaseUrl: true,
);

const _openRouterAccount = ProviderAccount(
  descriptor: _openRouter,
  apiKey: 'sk-test',
);

final _fireworksAccount = ProviderAccount(descriptor: _fireworks, apiKey: '');

const _customAccount = ProviderAccount(descriptor: _custom, apiKey: '');

const _otherOpenRouterAccount = ProviderAccount(
  descriptor: _openRouter,
  apiKey: 'sk-other',
);

final _customReadyAccount = ProviderAccount(
  descriptor: _custom,
  apiKey: '',
  baseUrl: Uri.parse('http://localhost:8080/v1'),
  fallbackContextWindow: 32768,
);

const _modelRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'org/model',
);

const _plainRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'org/plain',
);

final _settings = ProviderSettings(
  accounts: [_openRouterAccount, _fireworksAccount, _customAccount],
  model: _modelRef,
  maxAgents: 3,
);

ProviderSettings _settingsFor({
  List<ProviderAccount>? accounts,
  ProviderModelRef? model = _modelRef,
  int maxAgents = 3,
}) => ProviderSettings(
  accounts: accounts ?? _settings.accounts,
  model: model,
  maxAgents: maxAgents,
);

final _endpoint = InferenceEndpoint(
  baseUrl: Uri.parse('https://example.test/v1'),
);

const _keyInfo = ProviderKeyInfo(
  label: 'key',
  usage: 1.5,
  isFreeTier: false,
);

const _reasoning = ProviderReasoningEfforts(
  efforts: ['low', 'medium', 'high'],
  canDisable: true,
  defaultEffort: 'medium',
);

const _model = ProviderModel(
  id: 'org/model',
  name: 'Model',
  contextLength: 8192,
  supportsTools: true,
  reasoning: _reasoning,
);

const _resolvedModel = ResolvedModel(
  ref: _modelRef,
  name: 'Model',
  contextWindow: 8192,
  supportsTools: true,
  reasoning: _reasoning,
);

const _plainModel = ProviderModel(
  id: 'org/plain',
  name: 'Plain',
  contextLength: 4096,
  supportsTools: false,
);

const _unsizedModel = ProviderModel(
  id: 'org/model',
  name: 'org/model',
  supportsTools: true,
);

const _fireworksModel = ProviderModel(
  id: 'accounts/fireworks/models/kimi',
  name: 'Kimi',
  contextLength: 131072,
  supportsTools: true,
);

const _failure = ProviderFailure(
  kind: InferenceFailureKind.auth,
  message: 'bad key',
);

const _offline = ProviderFailure(
  kind: InferenceFailureKind.network,
  message: 'offline',
);

final class _Harness {
  _Harness() {
    when(
      () => catalog.modelsFor(any()),
    ).thenAnswer((_) async => const CatalogListed([]));
    repository = ProviderRepository(
      factories: ProviderSessionFactories(
        providerFactory: (account) {
          accounts.add(account);
          return providers.removeAt(0);
        },
        inferenceClientFactory: (endpoint) {
          endpoints.add(endpoint);
          return client;
        },
        agentProviderSpawner:
            ({
              required client,
              required modelId,
              required contextWindow,
              required maxAgents,
            }) {
              spawns.add(
                _SpawnCall(
                  client: client,
                  modelId: modelId,
                  contextWindow: contextWindow,
                  maxAgents: maxAgents,
                ),
              );
              return handles.removeAt(0);
            },
      ),
      catalog: catalog,
    );
    repository.statusStream.listen(statuses.add);
    repository.reloadsStarting.listen((_) => reloads++);
  }

  late final ProviderRepository repository;
  final catalog = _MockModelCatalog();
  final client = _MockInferenceClient();
  final List<Provider> providers = [];
  final List<AgentProvider> handles = [];
  final List<ProviderAccount> accounts = [];
  final List<InferenceEndpoint> endpoints = [];
  final List<_SpawnCall> spawns = [];
  final List<ProviderStatus> statuses = [];
  int reloads = 0;

  List<Type> get statusTypes =>
      statuses.map((status) => status.runtimeType).toList();

  List<String> get accountIds =>
      accounts.map((account) => account.descriptor.id).toList();

  /// Queues a provider whose probe resolves the way the stubs say.
  _MockProvider stageProvider({
    String displayName = 'Example',
    Map<InferenceProtocolId, InferenceEndpoint>? endpoints,
    KeyInfoResult keyInfo = const KeyInfoFetched(_keyInfo),
    ProviderModelsResult models = const ProviderModelsListed([
      _model,
      _plainModel,
    ]),
    List<ProviderModelsResult>? modelsSequence,
    Completer<KeyInfoResult>? keyInfoGate,
  }) {
    final listings = [...?modelsSequence];
    final provider = _MockProvider();
    when(() => provider.displayName).thenReturn(displayName);
    when(() => provider.endpoints).thenReturn(
      endpoints ?? {InferenceProtocolId.openAiCompat: _endpoint},
    );
    when(
      provider.keyInfo,
    ).thenAnswer((_) => keyInfoGate?.future ?? Future.value(keyInfo));
    when(
      provider.models,
    ).thenAnswer((_) async => listings.isEmpty ? models : listings.removeAt(0));
    providers.add(provider);
    return provider;
  }

  _MockAgentProvider stageHandle() {
    final handle = _MockAgentProvider();
    when(
      handle.dispose,
    ).thenAnswer((_) async => const DisposeProviderSucceeded());
    handles.add(handle);
    return handle;
  }

  void stageCatalog(String catalogId, CatalogResult result) {
    when(() => catalog.modelsFor(catalogId)).thenAnswer((_) async => result);
  }
}

void main() {
  group('ProviderAccount', () {
    test('is usable once the descriptor has what it needs', () {
      expect(_openRouterAccount.isUsable, isTrue);
      expect(_fireworksAccount.isUsable, isFalse);
      expect(_customAccount.isUsable, isFalse);
      expect(_customReadyAccount.isUsable, isTrue);
      expect(
        const ProviderAccount(descriptor: _openRouter, apiKey: ' ').isUsable,
        isFalse,
      );
    });

    test('resolves the address from the descriptor before the user', () {
      expect(_openRouterAccount.resolvedBaseUrl, isNull);
      expect(_fireworksAccount.resolvedBaseUrl, _fireworks.baseUrl);
      expect(_customReadyAccount.resolvedBaseUrl, _customReadyAccount.baseUrl);
    });

    test('compares by value and hides the key when printed', () {
      const same = ProviderAccount(descriptor: _openRouter, apiKey: 'sk-test');

      expect(_openRouterAccount, same);
      expect(_openRouterAccount.hashCode, same.hashCode);
      expect(_openRouterAccount, isNot(_fireworksAccount));
      expect(
        _openRouterAccount.toString(),
        'ProviderAccount(openrouter, apiKey: set, baseUrl: null)',
      );
      expect(
        _customReadyAccount.toString(),
        'ProviderAccount(custom, apiKey: unset, '
        'baseUrl: http://localhost:8080/v1)',
      );
    });
  });

  group('ProviderSettings', () {
    test('is complete only with a usable account, a model, and room', () {
      expect(_settings.isComplete, isTrue);
      expect(
        _settingsFor(accounts: [_fireworksAccount, _customAccount]).isComplete,
        isFalse,
      );
      expect(_settingsFor(model: null).isComplete, isFalse);
      expect(_settingsFor(maxAgents: 0).isComplete, isFalse);
    });

    test('finds accounts by provider id', () {
      expect(_settings.accountFor('fireworks'), _fireworksAccount);
      expect(_settings.accountFor('nope'), isNull);
    });

    test('compares by value', () {
      expect(_settings, _settingsFor());
      expect(_settings.hashCode, _settingsFor().hashCode);
      expect(_settings, isNot(_settingsFor(model: _plainRef)));
      expect(_settings, isNot(_settingsFor(accounts: [_openRouterAccount])));
      expect(
        _settingsFor(accounts: [_openRouterAccount]).toString(),
        'ProviderSettings(model: openrouter:org/model, maxAgents: 3, '
        'accounts: [ProviderAccount(openrouter, apiKey: set, baseUrl: null)])',
      );
    });
  });

  group('ResolvedModel', () {
    test('compares by value', () {
      const same = ResolvedModel(
        ref: _modelRef,
        name: 'Model',
        contextWindow: 8192,
        supportsTools: true,
        reasoning: _reasoning,
      );

      expect(_resolvedModel, same);
      expect(_resolvedModel.hashCode, same.hashCode);
      expect(_resolvedModel.id, 'org/model');
      expect(
        _resolvedModel,
        isNot(
          const ResolvedModel(
            ref: _modelRef,
            name: 'Model',
            contextWindow: 4096,
            supportsTools: true,
            reasoning: _reasoning,
          ),
        ),
      );
      expect(_resolvedModel.toString(), startsWith('ResolvedModel('));
    });
  });

  group('ListedModel', () {
    test('compares by value', () {
      const listed = ListedModel(
        ref: _modelRef,
        model: _model,
        providerName: 'OpenRouter',
        hasAccess: true,
      );
      const locked = ListedModel(
        ref: _modelRef,
        model: _model,
        providerName: 'OpenRouter',
        hasAccess: false,
      );

      expect(
        listed,
        const ListedModel(
          ref: _modelRef,
          model: _model,
          providerName: 'OpenRouter',
          hasAccess: true,
        ),
      );
      expect(listed.hashCode, isNot(locked.hashCode));
      expect(listed, isNot(locked));
      expect(listed.toString(), startsWith('ListedModel('));
    });
  });

  group('ProviderStatusReady', () {
    ProviderStatusReady ready(ProviderReasoning? reasoning) =>
        ProviderStatusReady(
          model: ResolvedModel(
            ref: _modelRef,
            name: 'Model',
            contextWindow: 8192,
            supportsTools: true,
            reasoning: reasoning,
          ),
          handle: _MockAgentProvider(),
          keyInfo: _keyInfo,
          providerName: 'Example',
        );

    test('exposes the context window and the handle', () {
      final status = ready(null);

      expect(status.contextWindow, 8192);
      expect(status.provider, status.handle);
      expect(status.defaultReasoningMode, 'auto');
    });

    test('offers only auto when the model cannot think or always does', () {
      final plain = ready(null);
      final fixed = ready(const ProviderReasoningFixed());

      expect(plain.reasoningModes, ['auto']);
      expect(plain.defaultEffortLabel, isNull);
      expect(plain.compactionReasoningMode, 'auto');
      expect(fixed.reasoningModes, ['auto']);
      expect(fixed.compactionReasoningMode, 'auto');
    });

    test('offers the efforts a mandatory thinker accepts', () {
      final status = ready(
        const ProviderReasoningEfforts(
          efforts: ['low', 'medium', 'high'],
          canDisable: false,
          defaultEffort: 'medium',
        ),
      );

      expect(status.reasoningModes, ['auto', 'low', 'medium', 'high']);
      expect(status.defaultEffortLabel, 'medium');
      expect(status.compactionReasoningMode, 'low');
    });

    test('adds off when the model may stop thinking', () {
      final status = ready(
        const ProviderReasoningEfforts(
          efforts: ['low', 'high'],
          canDisable: true,
        ),
      );

      expect(status.reasoningModes, ['auto', 'off', 'low', 'high']);
      expect(status.defaultEffortLabel, isNull);
      expect(status.compactionReasoningMode, 'low');
    });

    test('offers a toggle when the provider names no efforts', () {
      final status = ready(
        const ProviderReasoningToggle(enabledByDefault: true),
      );

      expect(status.reasoningModes, ['auto', 'off', 'on']);
      expect(status.compactionReasoningMode, 'off');
    });
  });

  group('ProviderRepository', () {
    test('starts unconfigured and answers queries with a failure', () async {
      final harness = _Harness();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.repository.status.provider, isNull);
      expect(harness.repository.settings, isNull);
      final credits = await harness.repository.credits() as CreditsFailed;
      final keyInfo = await harness.repository.keyInfo() as KeyInfoFailed;
      final models = await harness.repository.models();
      expect(credits.failure.message, 'No provider is configured.');
      expect(keyInfo.failure.kind, InferenceFailureKind.badRequest);
      expect(models.models, isEmpty);
      expect(models.failures.single.message, 'No provider is configured.');
    });

    test('stays unconfigured without a usable account', () async {
      final settings = _settingsFor(
        accounts: [_fireworksAccount, _customAccount],
      );
      final harness = _Harness()..repository.configure(settings);
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.accounts, isEmpty);
      expect(harness.repository.settings, settings);
    });

    test('connects, spawns an agent provider, and reports ready', () async {
      final harness = _Harness();
      final provider = harness.stageProvider();
      final handle = harness.stageHandle();

      harness.repository.configure(_settings);
      expect(
        harness.repository.status,
        isA<ProviderStatusConnecting>().having(
          (status) => status.model,
          'model',
          _modelRef,
        ),
      );
      await pumpEventQueue();

      final ready = harness.repository.status as ProviderStatusReady;
      expect(ready.model, _resolvedModel);
      expect(ready.handle, handle);
      expect(ready.keyInfo, _keyInfo);
      expect(ready.providerName, 'Example');
      expect(ready.provider, handle);
      expect(harness.accounts, [_openRouterAccount]);
      expect(harness.endpoints, [_endpoint]);
      final spawn = harness.spawns.single;
      expect(spawn.client, harness.client);
      expect(spawn.modelId, 'org/model');
      expect(spawn.contextWindow, 8192);
      expect(spawn.maxAgents, 3);
      expect(harness.statusTypes, [
        ProviderStatusUnconfigured,
        ProviderStatusConnecting,
        ProviderStatusReady,
      ]);
      expect(harness.reloads, 0);
      verify(provider.keyInfo).called(1);
      verify(provider.models).called(1);
      verify(() => harness.catalog.modelsFor('openrouter')).called(1);
    });

    test('ignores identical settings', () async {
      final harness = _Harness()
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();

      harness.repository.configure(_settingsFor());
      await pumpEventQueue();

      expect(harness.accounts, hasLength(1));
      expect(harness.reloads, 0);
    });

    test(
      'fails when the chosen model needs a key the user has not set',
      () async {
        final harness = _Harness()
          ..stageProvider()
          ..repository.configure(
            _settingsFor(
              model: const ProviderModelRef(
                providerId: 'fireworks',
                modelId: 'accounts/fireworks/models/kimi',
              ),
            ),
          );
        await pumpEventQueue();

        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.failure.kind, InferenceFailureKind.auth);
        expect(failed.failure.message, 'No Fireworks AI API key configured.');
        expect(failed.model.providerId, 'fireworks');
        expect(harness.accounts, [_openRouterAccount]);
        expect(await harness.repository.credits(), isA<CreditsFailed>());
      },
    );

    test('fails when the custom endpoint has no address', () async {
      final harness = _Harness()
        ..stageProvider()
        ..repository.configure(
          _settingsFor(
            model: const ProviderModelRef(providerId: 'custom', modelId: 'm'),
          ),
        );
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure.kind, InferenceFailureKind.badRequest);
      expect(failed.failure.message, 'Custom endpoint URL is not set.');
    });

    test('fails when the model names a provider nobody knows', () async {
      final harness = _Harness()
        ..stageProvider()
        ..repository.configure(
          _settingsFor(
            model: const ProviderModelRef(providerId: 'nope', modelId: 'm'),
          ),
        );
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure.message, 'No provider is called "nope".');
    });

    test('fails when the key is rejected', () async {
      final harness = _Harness()
        ..stageProvider(keyInfo: const KeyInfoFailed(_failure))
        ..repository.configure(_settings);
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure, _failure);
      expect(failed.model, _modelRef);
      expect(harness.spawns, isEmpty);
    });

    test('fails when the live listing cannot be fetched', () async {
      final harness = _Harness();
      final provider = harness.stageProvider(
        models: const ProviderModelsFailed(_failure),
      );
      harness.repository.configure(_settings);
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure, _failure);
      verify(provider.models).called(2);
    });

    test('retries a listing that failed while connecting', () async {
      final harness = _Harness();
      final gate = Completer<KeyInfoResult>();
      final provider = harness.stageProvider(
        keyInfoGate: gate,
        modelsSequence: const [
          ProviderModelsFailed(_failure),
          ProviderModelsListed([_model]),
        ],
      );
      harness
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();
      gate.complete(const KeyInfoFetched(_keyInfo));
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusReady>());
      final result = await harness.repository.models();
      expect(result.models.single.model, _model);
      verify(provider.models).called(2);
    });

    test('fails when the endpoint does not offer the model', () async {
      final harness = _Harness()
        ..stageCatalog('openrouter', const CatalogListed([_model]))
        ..stageProvider(models: const ProviderModelsListed([_plainModel]))
        ..repository.configure(_settings);
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure.kind, InferenceFailureKind.badRequest);
      expect(
        failed.failure.message,
        'Model "org/model" is not offered by Example.',
      );
    });

    test('fails when nothing knows the context window', () async {
      final harness = _Harness()
        ..stageProvider(models: const ProviderModelsListed([_unsizedModel]))
        ..repository.configure(_settings);
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(failed.failure.kind, InferenceFailureKind.malformedResponse);
      expect(
        failed.failure.message,
        'Example did not report a context window for "org/model".',
      );
    });

    test('fills what the endpoint left blank from the catalog', () async {
      final harness = _Harness()
        ..stageCatalog('openrouter', const CatalogListed([_model]))
        ..stageProvider(models: const ProviderModelsListed([_unsizedModel]))
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();

      final ready = harness.repository.status as ProviderStatusReady;
      expect(ready.model, _resolvedModel);
      expect(harness.spawns.single.contextWindow, 8192);
    });

    test(
      'assumes the account context window when the endpoint has none',
      () async {
        final harness = _Harness()
          ..stageProvider(
            displayName: 'Custom endpoint',
            keyInfo: const KeyInfoUnsupported(),
            models: const ProviderModelsListed([_unsizedModel]),
          )
          ..stageHandle()
          ..repository.configure(
            _settingsFor(
              accounts: [_customReadyAccount],
              model: const ProviderModelRef(
                providerId: 'custom',
                modelId: 'org/model',
              ),
            ),
          );
        await pumpEventQueue();

        final ready = harness.repository.status as ProviderStatusReady;
        expect(ready.model.contextWindow, 32768);
        expect(ready.model.name, 'org/model');
        expect(ready.keyInfo, isNull);
        expect(harness.accounts, [_customReadyAccount]);
        verifyNever(() => harness.catalog.modelsFor(any()));
      },
    );

    test('connects without the catalog', () async {
      final harness = _Harness()
        ..stageCatalog('openrouter', const CatalogUnavailable(_offline))
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusReady>());
    });

    test('fails when the provider has no OpenAI-compatible endpoint', () async {
      final harness = _Harness();
      final provider = harness.stageProvider(endpoints: const {});
      harness.repository.configure(_settings);
      await pumpEventQueue();

      final failed = harness.repository.status as ProviderStatusFailed;
      expect(
        failed.failure.message,
        'Example offers no OpenAI-compatible endpoint.',
      );
      verifyNever(provider.keyInfo);
    });

    test(
      'announces a reload and disposes the old handle on reconfigure',
      () async {
        final harness = _Harness()..stageProvider();
        final first = harness.stageHandle();
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.stageProvider();
        final second = harness.stageHandle();

        harness.repository.configure(
          _settingsFor(
            accounts: [
              const ProviderAccount(
                descriptor: _openRouter,
                apiKey: 'sk-other',
              ),
            ],
            model: _plainRef,
            maxAgents: 1,
          ),
        );
        expect(harness.reloads, 1);
        expect(harness.repository.status, isA<ProviderStatusConnecting>());
        await pumpEventQueue();

        verify(first.dispose).called(1);
        final ready = harness.repository.status as ProviderStatusReady;
        expect(ready.handle, second);
        expect(ready.model.ref, _plainRef);
        expect(ready.model.name, 'Plain');
        expect(harness.accounts.map((account) => account.apiKey), [
          'sk-test',
          'sk-other',
        ]);
        expect(harness.spawns.last.contextWindow, 4096);
        expect(harness.spawns.last.maxAgents, 1);
      },
    );

    test('drops to unconfigured when the last key is cleared', () async {
      final harness = _Harness()..stageProvider();
      final handle = harness.stageHandle();
      harness.repository.configure(_settings);
      await pumpEventQueue();

      harness.repository.configure(
        _settingsFor(accounts: [_fireworksAccount, _customAccount]),
      );
      await pumpEventQueue();

      expect(harness.reloads, 1);
      verify(handle.dispose).called(1);
      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.accounts, hasLength(1));
    });

    test('ignores a probe that started under older settings', () async {
      final harness = _Harness();
      final gate = Completer<KeyInfoResult>();
      harness
        ..stageProvider(keyInfoGate: gate)
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();

      harness.repository.configure(
        _settingsFor(accounts: [_otherOpenRouterAccount], model: _plainRef),
      );
      expect(
        harness.repository.status,
        isA<ProviderStatusConnecting>().having(
          (status) => status.model,
          'model',
          _plainRef,
        ),
      );
      await pumpEventQueue();
      final ready = harness.repository.status as ProviderStatusReady;
      expect(ready.model.ref, _plainRef);

      gate.complete(const KeyInfoFetched(_keyInfo));
      await pumpEventQueue();

      expect(harness.repository.status, same(ready));
      expect(harness.spawns, hasLength(1));
      expect(harness.reloads, 0);
    });

    test('keeps the connection when only the model changes', () async {
      final harness = _Harness();
      final provider = harness.stageProvider();
      harness
        ..stageHandle()
        ..stageHandle()
        ..repository.configure(_settings);
      await pumpEventQueue();

      harness.repository.configure(_settingsFor(model: _plainRef));
      await pumpEventQueue();

      final ready = harness.repository.status as ProviderStatusReady;
      expect(ready.model.ref, _plainRef);
      expect(harness.accounts, [_openRouterAccount]);
      verify(provider.models).called(1);
    });

    test('rebuilds only the connection whose account changed', () async {
      final harness = _Harness()
        ..stageProvider()
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(
          _settingsFor(accounts: [_openRouterAccount, _customReadyAccount]),
        );
      await pumpEventQueue();
      expect(harness.accountIds, ['openrouter', 'custom']);

      harness
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(
          _settingsFor(
            accounts: [_otherOpenRouterAccount, _customReadyAccount],
          ),
        );
      await pumpEventQueue();

      expect(harness.accountIds, ['openrouter', 'custom', 'openrouter']);
      expect(harness.accounts.last, _otherOpenRouterAccount);
    });

    test('lists every usable account as soon as it is configured', () async {
      final harness = _Harness();
      final gate = Completer<KeyInfoResult>();
      final openRouter = harness.stageProvider(keyInfoGate: gate);
      final custom = harness.stageProvider(keyInfoGate: gate);
      harness.repository.configure(
        _settingsFor(accounts: [_openRouterAccount, _customReadyAccount]),
      );
      await pumpEventQueue();

      verify(openRouter.models).called(1);
      verify(custom.models).called(1);
      expect(harness.repository.status, isA<ProviderStatusConnecting>());
    });

    test('clearing settings mid-connection abandons the probe', () async {
      final harness = _Harness();
      final gate = Completer<KeyInfoResult>();
      harness
        ..stageProvider(keyInfoGate: gate)
        ..repository.configure(_settings)
        ..repository.configure(_settingsFor(model: null));
      gate.complete(const KeyInfoFetched(_keyInfo));
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.spawns, isEmpty);
    });

    test('ignores a failure from an abandoned probe', () async {
      final harness = _Harness();
      final gate = Completer<KeyInfoResult>();
      harness
        ..stageProvider(keyInfoGate: gate)
        ..stageProvider()
        ..stageHandle()
        ..repository.configure(_settings)
        ..repository.reconnect();
      await pumpEventQueue();
      expect(harness.repository.status, isA<ProviderStatusReady>());

      gate.complete(const KeyInfoFailed(_failure));
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusReady>());
      expect(harness.accounts, hasLength(2));
    });

    group('reconnect', () {
      test('retries after a failure', () async {
        final harness = _Harness()
          ..stageProvider(keyInfo: const KeyInfoFailed(_failure))
          ..repository.configure(_settings);
        await pumpEventQueue();
        harness
          ..stageProvider()
          ..stageHandle()
          ..repository.reconnect();

        expect(harness.reloads, 0);
        expect(harness.repository.status, isA<ProviderStatusConnecting>());
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusReady>());
      });

      test('tears down a ready provider before reconnecting', () async {
        final harness = _Harness()..stageProvider();
        final first = harness.stageHandle();
        harness.repository.configure(_settings);
        await pumpEventQueue();
        final second = (harness..stageProvider()).stageHandle();

        harness.repository.reconnect();
        await pumpEventQueue();

        expect(harness.reloads, 1);
        verify(first.dispose).called(1);
        expect(
          (harness.repository.status as ProviderStatusReady).handle,
          second,
        );
        expect(harness.accounts, [_openRouterAccount, _openRouterAccount]);
      });

      test('does nothing while unconfigured', () async {
        final harness = _Harness()..repository.reconnect();
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
        expect(harness.accounts, isEmpty);
        expect(harness.statusTypes, [ProviderStatusUnconfigured]);
      });
    });

    group('queries', () {
      test('forward credits and key info to the provider', () async {
        final harness = _Harness();
        final provider = harness.stageProvider(
          keyInfo: const KeyInfoFailed(_failure),
        );
        const credits = ProviderCredits(
          spent: 4,
          remaining: 6,
          window: SpendWindow.lifetime,
        );
        when(provider.credits).thenAnswer(
          (_) async => const CreditsFetched(credits),
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();

        expect(
          await harness.repository.credits(),
          isA<CreditsFetched>().having(
            (result) => result.credits,
            'credits',
            credits,
          ),
        );
        expect(await harness.repository.keyInfo(), isA<KeyInfoFailed>());
      });

      test('list live models for usable accounts and catalog models for '
          'the rest', () async {
        final harness = _Harness();
        final provider = harness.stageProvider(
          keyInfo: const KeyInfoFailed(_failure),
          models: const ProviderModelsListed([_unsizedModel, _plainModel]),
        );
        harness
          ..stageCatalog('openrouter', const CatalogListed([_model]))
          ..stageCatalog('fireworks-ai', const CatalogListed([_fireworksModel]))
          ..repository.configure(_settings);
        await pumpEventQueue();

        final result = await harness.repository.models();
        await harness.repository.models();

        expect(result.failures, isEmpty);
        expect(result.models, const [
          ListedModel(
            ref: _modelRef,
            model: _model,
            providerName: 'OpenRouter',
            hasAccess: true,
          ),
          ListedModel(
            ref: _plainRef,
            model: _plainModel,
            providerName: 'OpenRouter',
            hasAccess: true,
          ),
          ListedModel(
            ref: ProviderModelRef(
              providerId: 'fireworks',
              modelId: 'accounts/fireworks/models/kimi',
            ),
            model: _fireworksModel,
            providerName: 'Fireworks AI',
            hasAccess: false,
          ),
        ]);
        expect(harness.accounts, [_openRouterAccount]);
        verify(provider.models).called(1);
      });

      test('list live models before catalog models whatever the account '
          'order', () async {
        final harness = _Harness()
          ..stageProvider(
            keyInfo: const KeyInfoFailed(_failure),
            models: const ProviderModelsListed([_model]),
          )
          ..stageCatalog('fireworks-ai', const CatalogListed([_fireworksModel]))
          ..repository.configure(
            _settingsFor(accounts: [_fireworksAccount, _openRouterAccount]),
          );
        await pumpEventQueue();

        final result = await harness.repository.models();

        expect(result.models.map((listed) => listed.ref.providerId), [
          'openrouter',
          'fireworks',
        ]);
      });

      test('report the providers that could not be listed', () async {
        final harness = _Harness()
          ..stageProvider(
            keyInfo: const KeyInfoFailed(_failure),
            models: const ProviderModelsFailed(_failure),
          )
          ..stageCatalog('fireworks-ai', const CatalogUnavailable(_offline))
          ..repository.configure(_settings);
        await pumpEventQueue();

        final result = await harness.repository.models();

        expect(result.models, isEmpty);
        expect(result.failures, [_failure, _offline]);
      });
    });

    test('dispose tears down the live handle and closes streams', () async {
      final harness = _Harness()..stageProvider();
      final handle = harness.stageHandle();
      harness.repository.configure(_settings);
      await pumpEventQueue();

      await harness.repository.dispose();

      verify(handle.dispose).called(1);
      await expectLater(
        harness.repository.statusStream,
        emitsInOrder([isA<ProviderStatusReady>(), emitsDone]),
      );
      await expectLater(harness.repository.reloadsStarting, emitsDone);
    });

    test('dispose without a session only closes streams', () async {
      final harness = _Harness();

      await harness.repository.dispose();

      await expectLater(
        harness.repository.statusStream,
        emitsInOrder([isA<ProviderStatusUnconfigured>(), emitsDone]),
      );
    });
  });
}
