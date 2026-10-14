import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:config_repository/testing.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:rxdart/rxdart.dart';

import 'fixtures.dart';

final class MockLocalModelsRepository extends Mock
    implements LocalModelsRepository {}

final class MockAgentRepository extends Mock implements AgentRepository {}

final class MockProviderRepository extends Mock implements ProviderRepository {}

final class MockBuiltInServerRepository extends Mock
    implements BuiltInServerRepository {}

final class MockAgentSession extends Mock implements AgentSession {}

final class MockOSPlatformRepository extends Mock
    implements OSPlatformRepository {}

final class MockAgentRuntime extends Mock implements AgentRuntime {}

const localProviderId = 'local';

final modelKey = ConfigKey<String>(
  id: 'provider.model',
  path: const ['provider', 'model'],
  codec: ConfigCodecs.strings,
  defaultValue: () => '',
  field: const OpaqueField(label: 'Model', description: 'Which model.'),
);

/// Every repository the use case talks to, mocked or faked, with streams the
/// test can push through.
final class Repositories {
  Repositories() {
    when(() => library.library).thenAnswer((_) => libraryChanges.stream);
    when(() => library.current).thenReturn(readyLibrary);
    when(() => library.setFolders(any())).thenAnswer((_) async {});
    when(library.start).thenAnswer((_) async => const LedgerRestored());
    when(() => server.status).thenAnswer((_) => serverStatus);
    when(
      () => server.statusStream,
    ).thenAnswer((_) => serverChanges.stream.startWith(serverStatus));
    when(server.start).thenAnswer((_) async {});
    when(() => providers.status).thenAnswer((_) => providerStatus);
    when(
      () => providers.statusStream,
    ).thenAnswer((_) => providerChanges.stream.startWith(providerStatus));
    when(() => agents.primary).thenReturn(primary);
    when(() => primary.conversationPhase).thenAnswer((_) => phase);
    when(() => platform.platform).thenReturn(linuxPlatform);
    when(platform.readSystemInfo).thenReturn(
      const SystemInfoSnapshot(
        logicalCoreCount: 8,
        totalRamBytes: 24 * gigabyte,
        availableRamBytes: 18 * gigabyte,
        platformAlwaysUnified: true,
      ),
    );
  }

  final library = MockLocalModelsRepository();
  final server = MockBuiltInServerRepository();
  final providers = MockProviderRepository();
  final config = FakeConfigRepository();
  final configKeys = LocalModelsConfigKeys.defaults();
  final agents = MockAgentRepository();
  final primary = MockAgentSession();
  final platform = MockOSPlatformRepository();
  final libraryChanges = StreamController<ModelLibrary>.broadcast();
  final serverChanges = StreamController<BuiltInServerStatus>.broadcast();
  final providerChanges = StreamController<ProviderStatus>.broadcast();
  BuiltInServerStatus serverStatus = const ServerOffline();
  ProviderStatus providerStatus = const ProviderStatusUnconfigured();
  ConversationPhase phase = ConversationPhase.idle;

  void setFolders(List<String> folders) =>
      config[configKeys.paths.id] = folders;

  void select(String model) => config[modelKey.id] = model;

  /// Has the app report [status], as the provider repository would.
  void report(ProviderStatus status) {
    providerStatus = status;
    providerChanges.add(status);
  }

  /// Has the built-in server report [status].
  void reportServer(BuiltInServerStatus status) {
    serverStatus = status;
    serverChanges.add(status);
  }
}

/// The app running [modelId] on [providerId].
ProviderStatusReady runningOn(
  String modelId, {
  String providerId = localProviderId,
}) => ProviderStatusReady(
  model: ResolvedModel(
    ref: ProviderModelRef(providerId: providerId, modelId: modelId),
    name: modelId,
    providerName: providerId,
    contextWindow: 32768,
    supportsTools: true,
  ),
  runtime: MockAgentRuntime(),
  maxAgents: 3,
  deviceBytes: 5 * gigabyte,
);

/// The app getting [modelId] on [providerId] ready, [progress] along once
/// its provider says.
ProviderStatusConnecting connectingTo(
  String modelId, {
  String providerId = localProviderId,
  ProviderModelLoadProgress? progress,
}) => ProviderStatusConnecting(
  model: ProviderModelRef(providerId: providerId, modelId: modelId),
  loading: progress == null
      ? null
      : LoadingModel(
          name: modelId,
          providerName: providerId,
          contextWindow: 32768,
          progress: progress,
        ),
);

/// The app unable to run [modelId] on [providerId] for [failure].
ProviderStatusFailed failedOn(
  String modelId,
  ProviderFailure failure, {
  String providerId = localProviderId,
}) => ProviderStatusFailed(
  failure: failure,
  model: ProviderModelRef(providerId: providerId, modelId: modelId),
);
