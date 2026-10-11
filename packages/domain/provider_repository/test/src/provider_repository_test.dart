import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime, DisposeRuntimeSucceeded;
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

final class _MockProvider extends Mock implements Provider {}

final class _MockConnection extends Mock implements ProviderConnection {}

final class _MockModel extends Mock implements ProviderModel {}

final class _MockAgentRuntime extends Mock implements AgentRuntime {}

const _modelRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'org/model',
);

const _plainRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'org/plain',
);

const _reasoning = ProviderReasoningEfforts(
  efforts: ['low', 'medium', 'high'],
  canDisable: true,
  defaultEffort: 'medium',
);

const _model = ProviderModelInfo(
  id: 'org/model',
  name: 'Model',
  contextLength: 8192,
  supportsTools: true,
  reasoning: _reasoning,
);

const _plainModel = ProviderModelInfo(
  id: 'org/plain',
  name: 'Plain',
  contextLength: 4096,
  supportsTools: false,
);

const _resolvedModel = ResolvedModel(
  ref: _modelRef,
  name: 'Model',
  providerName: 'OpenRouter',
  contextWindow: 8192,
  supportsTools: true,
  reasoning: _reasoning,
);

const _key = ApiKeyCredentials('sk-test');

const _settings = ProviderSettings(
  credentials: {'openrouter': _key},
  model: _modelRef,
  maxAgents: 3,
);

ProviderSettings _settingsFor({
  Map<String, ProviderCredentials> credentials = const {'openrouter': _key},
  ProviderModelRef? model = _modelRef,
  int maxAgents = 3,
  int? contextCap,
}) => ProviderSettings(
  credentials: credentials,
  model: model,
  maxAgents: maxAgents,
  contextCap: contextCap,
);

const _failure = ProviderAuthFailed('bad key');

final class _Harness {
  _Harness({Clock clock = const Clock()}) {
    repository = ProviderRepository(
      providers: [
        _provider('local', 'Bestie Server', ProviderCredentialsKind.none),
        _provider(
          'custom',
          'Custom endpoint',
          ProviderCredentialsKind.endpoint,
        ),
        _provider('openrouter', 'OpenRouter', ProviderCredentialsKind.apiKey),
        _provider('fireworks', 'Fireworks AI', ProviderCredentialsKind.apiKey),
      ],
      clock: clock,
    );
    repository.statusStream.listen(statuses.add);
    repository.reloadsStarting.listen((_) => reloads++);
  }

  late final ProviderRepository repository;
  final Map<String, List<_MockConnection>> connections = {};
  final Map<String, List<ProviderCredentials>> connectedWith = {};
  final Map<String, ProviderModelsResult> listings = {
    'openrouter': const ProviderModelsListed([_model, _plainModel]),
  };
  final List<ProviderModelLoadRequest> requests = [];
  final List<_MockModel> loaded = [];
  final List<ProviderStatus> statuses = [];
  int reloads = 0;

  /// Answers each load; by default with a model loaded at once that is
  /// never lost.
  ProviderModelLoad Function(ProviderModelLoadRequest request)? onLoad;

  _MockConnection connectionOf(String providerId) =>
      connections[providerId]!.last;

  List<Type> get statusTypes =>
      statuses.map((status) => status.runtimeType).toList();

  /// A model that runs with [contextWindow] and [maxAgents], lost when
  /// [lost] completes.
  _MockModel stageModel({
    int contextWindow = 8192,
    int maxAgents = 3,
    int? deviceBytes,
    Future<void>? lost,
  }) {
    final runtime = _MockAgentRuntime();
    when(
      runtime.dispose,
    ).thenAnswer((_) async => const DisposeRuntimeSucceeded());
    final model = _MockModel();
    when(() => model.contextWindow).thenReturn(contextWindow);
    when(() => model.maxAgents).thenReturn(maxAgents);
    when(() => model.deviceBytes).thenReturn(deviceBytes);
    when(() => model.runtime).thenReturn(runtime);
    when(() => model.lost).thenAnswer((_) => lost ?? Completer<void>().future);
    when(model.release).thenAnswer((_) async {});
    loaded.add(model);
    return model;
  }

  _MockProvider _provider(
    String id,
    String displayName,
    ProviderCredentialsKind kind,
  ) {
    final provider = _MockProvider();
    when(() => provider.id).thenReturn(id);
    when(() => provider.displayName).thenReturn(displayName);
    when(() => provider.credentialsKind).thenReturn(kind);
    when(() => provider.connect(any())).thenAnswer((invocation) {
      final credentials =
          invocation.positionalArguments.single as ProviderCredentials;
      connectedWith.putIfAbsent(id, () => []).add(credentials);
      final connection = _connection(id);
      connections.putIfAbsent(id, () => []).add(connection);
      return connection;
    });
    return provider;
  }

  _MockConnection _connection(String providerId) {
    final connection = _MockConnection();
    when(connection.models).thenAnswer(
      (_) async => listings[providerId] ?? const ProviderModelsListed([]),
    );
    when(
      connection.credits,
    ).thenAnswer((_) async => const CreditsUnsupported());
    when(() => connection.load(any())).thenAnswer((invocation) {
      final request =
          invocation.positionalArguments.single as ProviderModelLoadRequest;
      requests.add(request);
      return onLoad?.call(request) ??
          ProviderModelLoad.settled(
            ProviderModelLoaded(
              stageModel(
                contextWindow: request.contextWindow,
                maxAgents: request.maxAgents,
              ),
            ),
          );
    });
    when(connection.close).thenAnswer((_) async {});
    return connection;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NoCredentials());
    registerFallbackValue(
      const ProviderModelLoadRequest(
        modelId: 'fallback',
        contextWindow: 1,
        maxAgents: 1,
      ),
    );
  });

  group('ProviderSettings', () {
    test('is complete with a model and room for an agent', () {
      expect(_settings.isComplete, isTrue);
      expect(_settingsFor(model: null).isComplete, isFalse);
      expect(_settingsFor(maxAgents: 0).isComplete, isFalse);
    });

    test('compares by value', () {
      expect(_settingsFor(), _settings);
      expect(_settingsFor().hashCode, _settings.hashCode);
      expect(_settingsFor(maxAgents: 2), isNot(_settings));
      expect(_settingsFor(contextCap: 4096), isNot(_settings));
      expect(_settingsFor(credentials: const {}), isNot(_settings));
      expect(
        _settingsFor(
          credentials: const {'openrouter': ApiKeyCredentials('sk-other')},
        ),
        isNot(_settings),
      );
      expect(
        _settingsFor(credentials: const {'fireworks': _key}),
        isNot(_settings),
      );
    });

    test('runs the same session whatever the context cap', () {
      expect(
        _settings.runsSameSessionAs(_settingsFor(contextCap: 4096)),
        isTrue,
      );
      expect(
        _settings.runsSameSessionAs(_settingsFor(model: _plainRef)),
        isFalse,
      );
    });

    test('never prints a key', () {
      expect(_settings.toString(), isNot(contains('sk-test')));
      expect(_settings.toString(), contains('openrouter:org/model'));
    });
  });

  group('ProviderStatusReady', () {
    ProviderStatusReady ready(ProviderReasoning? reasoning) =>
        ProviderStatusReady(
          model: ResolvedModel(
            ref: _modelRef,
            name: 'Model',
            providerName: 'OpenRouter',
            contextWindow: 8192,
            supportsTools: true,
            reasoning: reasoning,
          ),
          runtime: _MockAgentRuntime(),
          maxAgents: 3,
          deviceBytes: null,
        );

    test('exposes the model, its provider and the runtime', () {
      final status = ready(null);
      final ProviderStatus projected = status;

      expect(status.contextWindow, 8192);
      expect(status.providerName, 'OpenRouter');
      expect(projected.runtime, isA<_MockAgentRuntime>());
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

  test(
    'LoadingModel reports nothing until the model and progress are known',
    () {
      expect(
        LoadingModel.of(null, progress: const ProviderModelMeasuring()),
        isNull,
      );
      expect(LoadingModel.of(_resolvedModel, progress: null), isNull);
      final loading = LoadingModel.of(
        _resolvedModel,
        progress: const ProviderModelLoading(0.5),
      )!;
      expect(loading.name, 'Model');
      expect(loading.providerName, 'OpenRouter');
      expect(loading.contextWindow, 8192);
      expect(loading.progress, const ProviderModelLoading(0.5));
    },
  );

  group('ProviderRepository', () {
    test('starts unconfigured with every provider connected without '
        'credentials', () async {
      final harness = _Harness();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.repository.status.runtime, isNull);
      expect(harness.repository.settings, isNull);
      expect(harness.connectedWith, {
        'local': [const NoCredentials()],
        'custom': [const NoCredentials()],
        'openrouter': [const NoCredentials()],
        'fireworks': [const NoCredentials()],
      });
      final credits = await harness.repository.credits() as CreditsFailed;
      expect(credits.failure.message, 'No model is chosen.');
    });

    test('loads the chosen model and runs agents on it', () async {
      final harness = _Harness();

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
      expect(ready.maxAgents, 3);
      expect(ready.deviceBytes, isNull);
      expect(ready.runtime, same(harness.loaded.single.runtime));
      expect(harness.requests, const [
        ProviderModelLoadRequest(
          modelId: 'org/model',
          contextWindow: 8192,
          maxAgents: 3,
        ),
      ]);
      expect(harness.connectedWith['openrouter'], [
        const NoCredentials(),
        _key,
      ]);
      expect(harness.connectedWith['fireworks'], [const NoCredentials()]);
      verify(harness.connections['openrouter']!.first.close).called(1);
      expect(harness.statusTypes, [
        ProviderStatusUnconfigured,
        ProviderStatusConnecting,
        ProviderStatusReady,
      ]);
      expect(harness.reloads, 0);
    });

    test(
      'runs with the context and agents the loaded model settled on',
      () async {
        final harness = _Harness();
        harness.onLoad = (request) => ProviderModelLoad.settled(
          ProviderModelLoaded(
            harness.stageModel(
              contextWindow: 4096,
              maxAgents: 2,
              deviceBytes: 7,
            ),
          ),
        );

        harness.repository.configure(_settings);
        await pumpEventQueue();

        final ready = harness.repository.status as ProviderStatusReady;
        expect(ready.contextWindow, 4096);
        expect(ready.maxAgents, 2);
        expect(ready.deviceBytes, 7);
        expect(ready.runtime, same(harness.loaded.single.runtime));
      },
    );

    test('ignores identical settings', () async {
      final harness = _Harness()..repository.configure(_settings);
      await pumpEventQueue();

      harness.repository.configure(_settingsFor());
      await pumpEventQueue();

      expect(harness.requests, hasLength(1));
      expect(harness.reloads, 0);
    });

    test('stays unconfigured until a model is chosen', () async {
      final settings = _settingsFor(model: null);
      final harness = _Harness()..repository.configure(settings);
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.repository.settings, settings);
      expect(harness.requests, isEmpty);
    });

    test('lets go of the model when none is chosen any more', () async {
      final harness = _Harness()..repository.configure(_settings);
      await pumpEventQueue();
      final model = harness.loaded.single;

      harness.repository.configure(_settingsFor(model: null));
      await pumpEventQueue();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.reloads, 1);
      final runtime = model.runtime;
      verify(runtime.dispose).called(1);
      verify(model.release).called(1);
    });

    group('connections', () {
      test('are kept while their credentials stay the same', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        harness.repository.configure(_settingsFor(model: _plainRef));
        await pumpEventQueue();

        expect(harness.connections['openrouter'], hasLength(2));
        expect(harness.requests.last.modelId, 'org/plain');
      });

      test('are replaced and closed when their credentials change', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();
        final keyed = harness.connectionOf('openrouter');

        harness.repository.configure(
          _settingsFor(
            credentials: const {
              'openrouter': ApiKeyCredentials('sk-other'),
              'fireworks': _key,
            },
          ),
        );
        await pumpEventQueue();

        verify(keyed.close).called(1);
        expect(
          harness.connectedWith['openrouter']!.last,
          const ApiKeyCredentials('sk-other'),
        );
        expect(harness.connectedWith['fireworks'], [
          const NoCredentials(),
          _key,
        ]);
        expect(harness.connectedWith['local'], [const NoCredentials()]);
        verify(() => harness.connectionOf('openrouter').load(any())).called(1);
      });

      test('go back to no credentials when theirs are cleared', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        harness.repository.configure(_settingsFor(credentials: const {}));
        await pumpEventQueue();

        expect(harness.connectedWith['openrouter'], [
          const NoCredentials(),
          _key,
          const NoCredentials(),
        ]);
      });
    });

    group('models', () {
      test(
        'are listed from every provider in order, before any settings',
        () async {
          final harness = _Harness();
          harness.listings['local'] = const ProviderModelsListed([_plainModel]);

          final listed = await harness.repository.models();

          expect(listed.models.map((model) => model.ref), const [
            ProviderModelRef(providerId: 'local', modelId: 'org/plain'),
            _modelRef,
            _plainRef,
          ]);
          expect(listed.models.first.providerName, 'Bestie Server');
          expect(listed.models.first.model, _plainModel);
          expect(listed.models.map((model) => model.hasAccess), [
            true,
            false,
            false,
          ]);
          expect(listed.failures, isEmpty);
        },
      );

      test('have access once their provider has credentials', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        final listed = await harness.repository.models();

        expect(listed.models.map((model) => model.hasAccess), [true, true]);
      });

      test('report the providers that could not list theirs', () async {
        final harness = _Harness();
        harness.listings['fireworks'] = const ProviderModelsFailed(_failure);

        final listed = await harness.repository.models();

        expect(listed.models, hasLength(2));
        expect(listed.failures, [_failure]);
      });
    });

    test("asks the chosen model's provider for credits", () async {
      final harness = _Harness()..repository.configure(_settings);
      await pumpEventQueue();
      when(harness.connectionOf('openrouter').credits).thenAnswer(
        (_) async => const CreditsFailed(_failure),
      );

      final credits = await harness.repository.credits() as CreditsFailed;

      expect(credits.failure, _failure);
    });

    group('fails', () {
      Future<ProviderFailure> failureFor(
        _Harness harness, [
        ProviderSettings settings = _settings,
      ]) async {
        harness.repository.configure(settings);
        await pumpEventQueue();
        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.model, settings.model);
        return failed.failure;
      }

      test('when the model names a provider nobody knows', () async {
        final failure = await failureFor(
          _Harness(),
          _settingsFor(
            model: const ProviderModelRef(providerId: 'nope', modelId: 'm'),
          ),
        );

        expect(failure, isA<ProviderRejected>());
        expect(failure.message, 'No provider is called "nope".');
      });

      test('when the provider cannot list its models', () async {
        final harness = _Harness();
        harness.listings['openrouter'] = const ProviderModelsFailed(_failure);

        expect(await failureFor(harness), _failure);
      });

      test('when the provider does not offer the model', () async {
        final harness = _Harness();
        harness.listings['openrouter'] = const ProviderModelsListed([
          _plainModel,
        ]);

        final failure = await failureFor(harness);

        expect(failure, isA<ProviderRejected>());
        expect(
          failure.message,
          'Model "org/model" is not offered by OpenRouter.',
        );
      });

      test('when the provider does not know the context window', () async {
        final harness = _Harness();
        harness.listings['openrouter'] = const ProviderModelsListed([
          ProviderModelInfo(
            id: 'org/model',
            name: 'Model',
            supportsTools: true,
          ),
        ]);

        final failure = await failureFor(harness);

        expect(failure, isA<ProviderResponseMalformed>());
        expect(
          failure.message,
          'OpenRouter did not report a context window for "org/model".',
        );
      });

      test('when the model does not load', () async {
        final harness = _Harness()
          ..onLoad = (_) => ProviderModelLoad.settled(
            const ProviderModelLoadFailed(_failure),
          );

        expect(await failureFor(harness), _failure);
        expect(harness.statusTypes.last, ProviderStatusFailed);
      });
    });

    group('loading', () {
      test('reports its progress while the model loads', () async {
        final harness = _Harness();
        final progress = StreamController<ProviderModelLoadProgress>();
        final result = Completer<ProviderModelLoadResult>();
        harness.onLoad = (_) =>
            ProviderModelLoad(progress: progress.stream, result: result.future);
        harness.repository.configure(_settings);
        await pumpEventQueue();
        expect(
          (harness.repository.status as ProviderStatusConnecting).loading,
          isNull,
        );

        progress.add(const ProviderModelMeasuring());
        await pumpEventQueue();
        expect(
          (harness.repository.status as ProviderStatusConnecting)
              .loading!
              .progress,
          const ProviderModelMeasuring(),
        );
        progress.add(const ProviderModelLoading(0.5));
        await pumpEventQueue();
        final loading =
            (harness.repository.status as ProviderStatusConnecting).loading!;
        expect(loading.progress, const ProviderModelLoading(0.5));
        expect(loading.name, 'Model');

        result.complete(ProviderModelLoaded(harness.stageModel()));
        await pumpEventQueue();
        expect(harness.repository.status, isA<ProviderStatusReady>());
        await progress.close();
      });

      test('ignores progress from a load the session moved on from', () async {
        final harness = _Harness();
        final first = StreamController<ProviderModelLoadProgress>.broadcast();
        final loads = [
          ProviderModelLoad(
            progress: first.stream,
            result: Completer<ProviderModelLoadResult>().future,
          ),
          ProviderModelLoad(
            progress: const Stream.empty(),
            result: Completer<ProviderModelLoadResult>().future,
          ),
        ];
        harness.onLoad = (_) => loads.removeAt(0);
        harness.repository.configure(_settings);
        await pumpEventQueue();

        harness.repository.configure(_settingsFor(maxAgents: 2));
        await pumpEventQueue();
        first.add(const ProviderModelLoading(0.9));
        await pumpEventQueue();

        expect(
          (harness.repository.status as ProviderStatusConnecting).loading,
          isNull,
        );
        await first.close();
      });

      test('releases a model that loads after the session moved on', () async {
        final harness = _Harness();
        final first = Completer<ProviderModelLoadResult>();
        final loads = [
          ProviderModelLoad(
            progress: const Stream.empty(),
            result: first.future,
          ),
        ];
        harness.onLoad = (request) => loads.isEmpty
            ? ProviderModelLoad.settled(
                ProviderModelLoaded(harness.stageModel()),
              )
            : loads.removeAt(0);
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.repository.configure(_settingsFor(maxAgents: 2));
        await pumpEventQueue();
        final late = harness.stageModel();

        first.complete(ProviderModelLoaded(late));
        await pumpEventQueue();

        verify(late.release).called(1);
        expect(harness.repository.status, isA<ProviderStatusReady>());
      });

      test('releases a model that loads once nothing is chosen', () async {
        final harness = _Harness();
        final result = Completer<ProviderModelLoadResult>();
        harness.onLoad = (_) => ProviderModelLoad(
          progress: const Stream.empty(),
          result: result.future,
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.repository.configure(_settingsFor(model: null));
        final late = harness.stageModel();

        result.complete(ProviderModelLoaded(late));
        await pumpEventQueue();

        verify(late.release).called(1);
        expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      });

      test(
        'ignores a lookup that finished after the session moved on',
        () async {
          final harness = _Harness();
          final stale = Completer<ProviderModelsResult>();
          final listings = [
            stale.future,
            Future.value(const ProviderModelsListed([_model])),
          ];
          when(
            harness.connectionOf('openrouter').models,
          ).thenAnswer((_) => listings.removeAt(0));
          harness.repository.configure(_settingsFor(credentials: const {}));

          harness.repository.reconnect();
          await pumpEventQueue();
          expect(harness.requests, hasLength(1));

          stale.complete(const ProviderModelsListed([_model]));
          await pumpEventQueue();
          expect(harness.requests, hasLength(1));
          expect(harness.repository.status, isA<ProviderStatusReady>());
        },
      );

      test('starts over when the settings change mid-way', () async {
        final harness = _Harness();
        final listing = Completer<ProviderModelsResult>();
        when(() => harness.connectionOf('openrouter').models()).thenAnswer(
          (_) => listing.future,
        );
        harness.repository.configure(_settings);

        harness.repository.configure(_settingsFor(model: _plainRef));
        await pumpEventQueue();
        listing.complete(const ProviderModelsListed([_model, _plainModel]));
        await pumpEventQueue();

        final ready = harness.repository.status as ProviderStatusReady;
        expect(ready.model.ref, _plainRef);
        expect(harness.requests.map((request) => request.modelId), [
          'org/plain',
        ]);
      });

      test('drops to unconfigured when the model is cleared mid-way', () async {
        final harness = _Harness();
        when(() => harness.connectionOf('openrouter').models()).thenAnswer(
          (_) => Completer<ProviderModelsResult>().future,
        );
        harness.repository.configure(_settings);

        harness.repository.configure(_settingsFor(model: null));
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      });
    });

    group('switching models', () {
      test('starts the new load before letting go of the old model', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();
        final old = harness.loaded.single;
        final oldRuntime = old.runtime;
        final connection = harness.connectionOf('openrouter');

        harness.repository.configure(_settingsFor(model: _plainRef));
        await pumpEventQueue();

        verifyInOrder([
          oldRuntime.dispose,
          () => connection.load(any()),
          old.release,
        ]);
        expect(harness.reloads, 1);
        expect(
          (harness.repository.status as ProviderStatusReady).model.ref,
          _plainRef,
        );
      });

      test(
        'lets go of the old model when the new one cannot be found',
        () async {
          final harness = _Harness()..repository.configure(_settings);
          await pumpEventQueue();
          final old = harness.loaded.single;

          harness.repository.configure(
            _settingsFor(
              model: const ProviderModelRef(
                providerId: 'openrouter',
                modelId: 'gone',
              ),
            ),
          );
          await pumpEventQueue();

          verify(old.release).called(1);
          expect(harness.repository.status, isA<ProviderStatusFailed>());
        },
      );
    });

    group('context cap', () {
      test('is asked for when the model is loaded', () async {
        final harness = _Harness()
          ..repository.configure(_settingsFor(contextCap: 4096));
        await pumpEventQueue();

        expect(harness.requests.single.contextCap, 4096);
      });

      test('is kept for the next load without a reload', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        harness.repository.configure(_settingsFor(contextCap: 4096));
        await pumpEventQueue();
        expect(harness.requests, hasLength(1));
        expect(harness.repository.settings!.contextCap, 4096);

        harness.repository.reconnect();
        await pumpEventQueue();
        expect(harness.requests.last.contextCap, 4096);
      });

      test('is taken up by a load not yet started', () async {
        final harness = _Harness();
        final listing = Completer<ProviderModelsResult>();
        when(() => harness.connectionOf('openrouter').models()).thenAnswer(
          (_) => listing.future,
        );
        harness.repository.configure(_settings);

        harness.repository.configure(_settingsFor(contextCap: 4096));
        listing.complete(const ProviderModelsListed([_model]));
        await pumpEventQueue();

        expect(harness.requests.single.contextCap, 4096);
      });

      test('gives a failed session another try', () async {
        final harness = _Harness()
          ..onLoad = (_) => ProviderModelLoad.settled(
            const ProviderModelLoadFailed(_failure),
          );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.onLoad = null;

        harness.repository.configure(_settingsFor(contextCap: 4096));
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusReady>());
      });
    });

    group('stop', () {
      test('lets the model go until a reconnect', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();
        final model = harness.loaded.single;

        harness.repository.stop();
        await pumpEventQueue();

        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.failure, isA<ProviderCancelled>());
        expect(
          failed.failure.message,
          'Stopped. Reconnect or pick a model to start again.',
        );
        verify(model.release).called(1);
        expect(harness.reloads, 1);

        harness.repository.reconnect();
        await pumpEventQueue();
        expect(harness.repository.status, isA<ProviderStatusReady>());
      });

      test('abandons a load under way', () async {
        final harness = _Harness();
        final result = Completer<ProviderModelLoadResult>();
        harness.onLoad = (_) => ProviderModelLoad(
          progress: const Stream.empty(),
          result: result.future,
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();

        harness.repository.stop();
        final late = harness.stageModel();
        result.complete(ProviderModelLoaded(late));
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusFailed>());
        verify(late.release).called(1);
      });

      test('does nothing while nothing runs', () async {
        final harness = _Harness()..repository.stop();
        await pumpEventQueue();

        expect(harness.statusTypes, [ProviderStatusUnconfigured]);
      });
    });

    group('reconnect', () {
      test('retries after a failure', () async {
        final harness = _Harness()
          ..onLoad = (_) => ProviderModelLoad.settled(
            const ProviderModelLoadFailed(_failure),
          );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.onLoad = null;

        harness.repository.reconnect();
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusReady>());
        expect(harness.connections['openrouter'], hasLength(2));
      });

      test('tears down a ready model before loading again', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();
        final old = harness.loaded.single;

        harness.repository.reconnect();
        await pumpEventQueue();

        expect(harness.reloads, 1);
        verify(old.release).called(1);
        expect(harness.loaded, hasLength(2));
        expect(harness.repository.status, isA<ProviderStatusReady>());
      });

      test('does nothing while unconfigured', () async {
        final harness = _Harness()..repository.reconnect();
        await pumpEventQueue();

        harness.repository
          ..configure(_settingsFor(model: null))
          ..reconnect();
        await pumpEventQueue();

        expect(harness.statusTypes, [ProviderStatusUnconfigured]);
        expect(harness.requests, isEmpty);
      });
    });

    group('when the model is lost', () {
      test('waits, then loads it again on a fresh agent runtime', () {
        fakeAsync((async) {
          final harness = _Harness(clock: async.getClock(DateTime(2026)));
          final lost = Completer<void>();
          final models = [
            harness.stageModel(contextWindow: 4096, lost: lost.future),
            harness.stageModel(contextWindow: 2048),
          ];
          harness.onLoad = (_) => ProviderModelLoad.settled(
            ProviderModelLoaded(models.removeAt(0)),
          );
          harness.repository.configure(_settings);
          async.flushMicrotasks();
          final stale = harness.repository.status.runtime;

          lost.complete();
          async.flushMicrotasks();

          expect(harness.reloads, 1);
          expect(harness.repository.status, isA<ProviderStatusConnecting>());
          verify(harness.loaded.first.release).called(1);
          expect(harness.requests, hasLength(1));

          async.elapse(const Duration(seconds: 1));

          final ready = harness.repository.status as ProviderStatusReady;
          expect(harness.requests, hasLength(2));
          expect(ready.runtime, isNot(same(stale)));
          expect(ready.contextWindow, 2048);
        });
      });

      test('doubles the wait with each loss in a row, then fails', () {
        fakeAsync((async) {
          final harness = _Harness(clock: async.getClock(DateTime(2026)));
          var served = Completer<void>();
          harness.onLoad = (_) => ProviderModelLoad.settled(
            ProviderModelLoaded(
              harness.stageModel(lost: (served = Completer<void>()).future),
            ),
          );
          harness.repository.configure(_settings);
          async.flushMicrotasks();

          for (final wait in const [1, 2, 4]) {
            served.complete();
            async
              ..flushMicrotasks()
              ..elapse(Duration(milliseconds: wait * 1000 - 1));
            expect(
              harness.repository.status,
              isA<ProviderStatusConnecting>(),
              reason: 'still waiting out ${wait}s',
            );
            async.elapse(const Duration(milliseconds: 1));
            expect(harness.repository.status, isA<ProviderStatusReady>());
          }
          served.complete();
          async.flushMicrotasks();

          final failed = harness.repository.status as ProviderStatusFailed;
          expect(failed.failure, isA<ProviderServerFailed>());
          expect(
            failed.failure.message,
            'Model stopped being served 4 times in a row. Reconnect to try '
            'again.',
          );
          expect(harness.requests, hasLength(4));
          for (final model in harness.loaded) {
            verify(model.release).called(1);
          }
          async.elapse(const Duration(minutes: 1));
          expect(harness.requests, hasLength(4));
        });
      });

      test('counts afresh once the model served for a while', () {
        fakeAsync((async) {
          final harness = _Harness(clock: async.getClock(DateTime(2026)));
          var served = Completer<void>();
          harness.onLoad = (_) => ProviderModelLoad.settled(
            ProviderModelLoaded(
              harness.stageModel(lost: (served = Completer<void>()).future),
            ),
          );
          harness.repository.configure(_settings);
          async.flushMicrotasks();

          for (final wait in const [1, 2, 4]) {
            served.complete();
            async
              ..flushMicrotasks()
              ..elapse(Duration(seconds: wait));
          }
          async.elapse(const Duration(minutes: 5));
          served.complete();
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 1));

          expect(harness.repository.status, isA<ProviderStatusReady>());
        });
      });

      test('stops waiting when the settings change', () {
        fakeAsync((async) {
          final harness = _Harness(clock: async.getClock(DateTime(2026)));
          final lost = Completer<void>();
          final models = [
            harness.stageModel(lost: lost.future),
            harness.stageModel(),
          ];
          harness.onLoad = (_) => ProviderModelLoad.settled(
            ProviderModelLoaded(models.removeAt(0)),
          );
          harness.repository.configure(_settings);
          async.flushMicrotasks();
          lost.complete();
          async.flushMicrotasks();

          harness.repository.configure(_settingsFor(maxAgents: 2));
          async.flushMicrotasks();
          expect(harness.requests, hasLength(2));
          async.elapse(const Duration(seconds: 1));

          expect(harness.requests, hasLength(2));
          expect(harness.repository.status, isA<ProviderStatusReady>());
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('is ignored when the loss belongs to an older load', () async {
        final harness = _Harness();
        final lost = Completer<void>();
        final models = [
          harness.stageModel(lost: lost.future),
          harness.stageModel(),
        ];
        harness.onLoad = (_) => ProviderModelLoad.settled(
          ProviderModelLoaded(models.removeAt(0)),
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        harness.repository.configure(_settingsFor(maxAgents: 2));
        await pumpEventQueue();

        lost.complete();
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusReady>());
        expect(harness.requests, hasLength(2));
      });
    });

    test('dispose lets go of the model and every connection', () async {
      final harness = _Harness()..repository.configure(_settings);
      await pumpEventQueue();
      final model = harness.loaded.single;

      await harness.repository.dispose();

      final runtime = model.runtime;
      verify(runtime.dispose).called(1);
      verify(model.release).called(1);
      for (final connection in [
        for (final id in const ['local', 'custom', 'openrouter', 'fireworks'])
          harness.connectionOf(id),
      ]) {
        verify(connection.close).called(1);
      }
    });

    test('dispose stops following a load under way', () async {
      final harness = _Harness();
      final progress = StreamController<ProviderModelLoadProgress>.broadcast();
      harness.onLoad = (_) => ProviderModelLoad(
        progress: progress.stream,
        result: Completer<ProviderModelLoadResult>().future,
      );
      harness.repository.configure(_settings);
      await pumpEventQueue();

      await harness.repository.dispose();

      expect(progress.hasListener, isFalse);
      await progress.close();
    });
  });
}
