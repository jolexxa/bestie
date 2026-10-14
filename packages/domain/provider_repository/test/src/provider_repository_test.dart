import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime, DisposeRuntimeSucceeded;
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

final class _MockClient extends Mock implements ProviderClient {}

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

const _settings = ProviderSettings(model: _modelRef, maxAgents: 3);

ProviderSettings _settingsFor({
  ProviderModelRef? model = _modelRef,
  int maxAgents = 3,
}) => ProviderSettings(model: model, maxAgents: maxAgents);

const _failure = ProviderAuthFailed('bad key');

const _noKey = ProviderAuthFailed('No Fireworks AI API key configured.');

const _noUrl = ProviderRejected('Custom endpoint URL is not set.');

const _names = {
  'local': 'Built-in server',
  'custom': 'Custom endpoint',
  'openrouter': 'OpenRouter',
  'fireworks': 'Fireworks AI',
};

final class _Harness {
  _Harness({
    Map<String, ProviderAvailability> availability = const {
      'local': ProviderReady(),
      'custom': ProviderNotSetUp(_noUrl),
      'openrouter': ProviderReady(),
      'fireworks': ProviderNotSetUp(_noKey),
    },
  }) {
    repository = ProviderRepository(
      clients: [
        for (final MapEntry(key: id, value: name) in _names.entries)
          _client(id, name, availability[id]!),
      ],
    );
    repository.statusStream.listen(statuses.add);
    repository.reloadsStarting.listen((_) => reloads++);
  }

  late final ProviderRepository repository;
  final Map<String, _MockClient> clients = {};
  final Map<String, StreamController<ProviderAvailability>> reconfigurations =
      {};
  final Map<String, ProviderModelsResult> listings = {
    'openrouter': const ProviderModelsListed([_model, _plainModel]),
    'fireworks': const ProviderModelsListed([_fireworksModel]),
  };
  final List<ProviderModelLoadRequest> requests = [];
  final List<_MockModel> loaded = [];
  final List<ProviderStatus> statuses = [];
  int reloads = 0;

  /// Answers each load; by default with a model loaded at once that is
  /// never lost.
  ProviderModelLoad Function(ProviderModelLoadRequest request)? onLoad;

  /// Has [providerId]'s client report it was configured anew.
  void reconfigure(String providerId, ProviderAvailability availability) =>
      reconfigurations[providerId]!.add(availability);

  List<Type> get statusTypes =>
      statuses.map((status) => status.runtimeType).toList();

  /// A model that runs with [contextWindow] and [maxAgents], lost when
  /// [lost] completes.
  _MockModel stageModel({
    int contextWindow = 8192,
    int maxAgents = 3,
    int? deviceBytes,
    Future<ProviderFailure>? lost,
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
    when(
      () => model.lost,
    ).thenAnswer((_) => lost ?? Completer<ProviderFailure>().future);
    when(model.release).thenAnswer((_) async {});
    loaded.add(model);
    return model;
  }

  _MockClient _client(
    String id,
    String displayName,
    ProviderAvailability availability,
  ) {
    final client = clients[id] = _MockClient();
    final reconfigured = reconfigurations[id] =
        StreamController<ProviderAvailability>.broadcast();
    when(() => client.id).thenReturn(id);
    when(() => client.displayName).thenReturn(displayName);
    when(() => client.availability).thenReturn(availability);
    when(() => client.reconfigured).thenAnswer((_) => reconfigured.stream);
    when(client.models).thenAnswer(
      (_) async => listings[id] ?? const ProviderModelsListed([]),
    );
    when(client.credits).thenAnswer((_) async => const CreditsUnsupported());
    when(() => client.load(any())).thenAnswer((invocation) {
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
    return client;
  }
}

void main() {
  setUpAll(() {
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
      expect(_settingsFor(model: _plainRef), isNot(_settings));
    });

    test('names the model', () {
      expect(
        _settings.toString(),
        'ProviderSettings(model: openrouter:org/model, maxAgents: 3)',
      );
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
    test('starts unconfigured', () async {
      final harness = _Harness();

      expect(harness.repository.status, isA<ProviderStatusUnconfigured>());
      expect(harness.repository.status.runtime, isNull);
      expect(harness.repository.settings, isNull);
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

    group('clients', () {
      test('fail the session at once while theirs is not set up', () async {
        final harness = _Harness()
          ..repository.configure(_settingsFor(model: _fireworksRef));
        await pumpEventQueue();

        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.failure, _noKey);
        expect(failed.model, _fireworksRef);
        verifyNever(harness.clients['fireworks']!.models);
        expect(harness.statusTypes, [
          ProviderStatusUnconfigured,
          ProviderStatusConnecting,
          ProviderStatusFailed,
        ]);
      });

      test('start the session once theirs is set up', () async {
        final harness = _Harness()
          ..repository.configure(_settingsFor(model: _fireworksRef));
        await pumpEventQueue();

        harness.reconfigure('fireworks', const ProviderReady());
        await pumpEventQueue();

        final ready = harness.repository.status as ProviderStatusReady;
        expect(ready.model.ref, _fireworksRef);
        expect(ready.model.providerName, 'Fireworks AI');
        expect(harness.requests.single.modelId, _fireworksRef.modelId);
      });

      test('start the session over when theirs is configured anew', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();
        final old = harness.loaded.single;

        harness.reconfigure('openrouter', const ProviderReady());
        await pumpEventQueue();

        expect(harness.reloads, 1);
        verify(old.release).called(1);
        expect(harness.requests, hasLength(2));
        expect(
          harness.repository.status.runtime,
          same(harness.loaded.last.runtime),
        );
      });

      test('fail a running session when theirs is no longer set up', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        harness.reconfigure('openrouter', const ProviderNotSetUp(_failure));
        await pumpEventQueue();

        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.failure, _failure);
        expect(harness.requests, hasLength(1));
      });

      test('start a lookup over when theirs is configured mid-way', () async {
        final harness = _Harness();
        final stale = Completer<ProviderModelsResult>();
        final listings = [
          stale.future,
          Future.value(const ProviderModelsListed([_model])),
        ];
        when(
          harness.clients['openrouter']!.models,
        ).thenAnswer((_) => listings.removeAt(0));
        harness.repository.configure(_settings);

        harness.reconfigure('openrouter', const ProviderReady());
        await pumpEventQueue();
        stale.complete(const ProviderModelsListed([_model]));
        await pumpEventQueue();

        expect(harness.requests, hasLength(1));
        expect(harness.repository.status, isA<ProviderStatusReady>());
      });

      test('leave a session on another provider be', () async {
        final harness = _Harness()..repository.configure(_settings);
        await pumpEventQueue();

        harness.reconfigure('fireworks', const ProviderReady());
        await pumpEventQueue();

        expect(harness.reloads, 0);
        expect(harness.requests, hasLength(1));
      });

      test('leave an unconfigured session be', () async {
        final harness = _Harness()
          ..reconfigure('openrouter', const ProviderReady());
        await pumpEventQueue();

        expect(harness.statusTypes, [ProviderStatusUnconfigured]);
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
            _fireworksRef,
          ]);
          expect(listed.models.first.providerName, 'Built-in server');
          expect(listed.models.first.model, _plainModel);
          expect(listed.failures, isEmpty);
        },
      );

      test('have access while their provider is set up', () async {
        final harness = _Harness();

        final listed = await harness.repository.models();

        expect(listed.models.map((model) => model.ref.providerId), [
          'openrouter',
          'openrouter',
          'fireworks',
        ]);
        expect(listed.models.map((model) => model.hasAccess), [
          true,
          true,
          false,
        ]);
      });

      test('follow access as their provider is configured', () async {
        final harness = _Harness()
          ..reconfigure('fireworks', const ProviderReady())
          ..reconfigure('openrouter', const ProviderNotSetUp(_failure));
        await pumpEventQueue();

        final listed = await harness.repository.models();

        expect(listed.models.map((model) => model.hasAccess), [
          false,
          false,
          true,
        ]);
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
      when(harness.clients['openrouter']!.credits).thenAnswer(
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
            harness.clients['openrouter']!.models,
          ).thenAnswer((_) => listings.removeAt(0));
          harness.repository.configure(_settings);

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
        when(harness.clients['openrouter']!.models).thenAnswer(
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
        when(harness.clients['openrouter']!.models).thenAnswer(
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
        final client = harness.clients['openrouter']!;

        harness.repository.configure(_settingsFor(model: _plainRef));
        await pumpEventQueue();

        verifyInOrder([
          oldRuntime.dispose,
          () => client.load(any()),
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
      const crashed = ProviderServerFailed('Built-in server crashed.');

      test('fails with the reason its provider gives', () async {
        final harness = _Harness();
        final lost = Completer<ProviderFailure>();
        harness.onLoad = (_) => ProviderModelLoad.settled(
          ProviderModelLoaded(harness.stageModel(lost: lost.future)),
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        final runtime = harness.repository.status.runtime!;

        lost.complete(crashed);
        await pumpEventQueue();

        final failed = harness.repository.status as ProviderStatusFailed;
        expect(failed.failure.message, crashed.message);
        verify(harness.loaded.single.release).called(1);
        verify(runtime.dispose).called(1);
        expect(harness.requests, hasLength(1));
      });

      test('loads it again on a reconnect', () async {
        final harness = _Harness();
        final lost = Completer<ProviderFailure>();
        final models = [
          harness.stageModel(lost: lost.future),
          harness.stageModel(contextWindow: 2048),
        ];
        harness.onLoad = (_) => ProviderModelLoad.settled(
          ProviderModelLoaded(models.removeAt(0)),
        );
        harness.repository.configure(_settings);
        await pumpEventQueue();
        final stale = harness.repository.status.runtime;
        lost.complete(crashed);
        await pumpEventQueue();

        harness.repository.reconnect();
        await pumpEventQueue();

        final ready = harness.repository.status as ProviderStatusReady;
        expect(harness.requests, hasLength(2));
        expect(ready.runtime, isNot(same(stale)));
        expect(ready.contextWindow, 2048);
      });

      test('is ignored when the loss belongs to an older load', () async {
        final harness = _Harness();
        final lost = Completer<ProviderFailure>();
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

        lost.complete(crashed);
        await pumpEventQueue();

        expect(harness.repository.status, isA<ProviderStatusReady>());
        expect(harness.requests, hasLength(2));
      });
    });

    test('dispose lets go of the model and stops following clients', () async {
      final harness = _Harness()..repository.configure(_settings);
      await pumpEventQueue();
      final model = harness.loaded.single;

      await harness.repository.dispose();
      harness.reconfigure('openrouter', const ProviderReady());
      await pumpEventQueue();

      final runtime = model.runtime;
      verify(runtime.dispose).called(1);
      verify(model.release).called(1);
      expect(harness.requests, hasLength(1));
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
