import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:config_repository/testing.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:rxdart/rxdart.dart';

import 'fixtures.dart';

final class MockLocalModelsRepository extends Mock
    implements LocalModelsRepository {}

final class MockLocalServerRepository extends Mock
    implements LocalServerRepository {}

final class MockAgentRepository extends Mock implements AgentRepository {}

final class MockProviderRepository extends Mock implements ProviderRepository {}

final class MockAgentSession extends Mock implements AgentSession {}

final class MockOSPlatformRepository extends Mock
    implements OSPlatformRepository {}

final class MockAgentProvider extends Mock implements AgentProvider {}

const localProviderId = 'local';

final modelKey = ConfigKey<String>(
  id: 'provider.model',
  path: const ['provider', 'model'],
  codec: ConfigCodecs.strings,
  defaultValue: () => '',
);

/// Every repository the use case talks to, mocked or faked, with streams the
/// test can push through.
final class Repositories {
  Repositories() {
    when(() => library.library).thenAnswer((_) => libraryChanges.stream);
    when(() => library.current).thenReturn(readyLibrary);
    when(() => library.setFolders(any())).thenAnswer((_) async {});
    when(library.start).thenAnswer((_) async => const LedgerRestored());
    when(() => server.status).thenAnswer((_) => serverChanges.stream);
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
  final server = MockLocalServerRepository();
  final providers = MockProviderRepository();
  final config = FakeConfigRepository();
  final configKeys = LocalModelsConfigKeys.defaults();
  final agents = MockAgentRepository();
  final primary = MockAgentSession();
  final platform = MockOSPlatformRepository();
  final libraryChanges = StreamController<ModelLibrary>.broadcast();
  final serverChanges = StreamController<LocalServerStatus>.broadcast();
  final providerChanges = StreamController<ProviderStatus>.broadcast();
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
}

/// The app running [modelId] on [providerId].
ProviderStatusReady runningOn(
  String modelId, {
  String providerId = localProviderId,
}) => ProviderStatusReady(
  model: ResolvedModel(
    ref: ProviderModelRef(providerId: providerId, modelId: modelId),
    name: modelId,
    contextWindow: 32768,
    supportsTools: true,
  ),
  handle: MockAgentProvider(),
  keyInfo: null,
  providerName: providerId,
);

/// The app getting [modelId] on [providerId] ready.
ProviderStatusConnecting connectingTo(
  String modelId, {
  String providerId = localProviderId,
}) => ProviderStatusConnecting(
  model: ProviderModelRef(providerId: providerId, modelId: modelId),
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
