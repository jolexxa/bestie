import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_agent_sessions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/local_server_link.dart';
import 'package:local_inference_client/src/model_index_file.dart';
import 'package:local_inference_client/src/models/local_provider_options.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:meta/meta.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// The models in bestie's local index, served by the local inference
/// server. A model is loaded when it is activated, and agents lease the
/// loaded model's context through the owner session.
@PartOf(LocalInferenceClient)
final class LocalProvider implements Provider {
  LocalProvider({
    required LocalServerLink link,
    required ModelIndexFile index,
    required ProviderDescriptor descriptor,
    required LocalProviderOptionsReader options,
  }) : _link = link,
       _index = index,
       _descriptor = descriptor,
       _options = options;

  final LocalServerLink _link;
  final ModelIndexFile _index;
  final ProviderDescriptor _descriptor;
  final LocalProviderOptionsReader _options;

  @override
  String get id => _descriptor.id;

  @override
  String get displayName => _descriptor.displayName;

  @override
  Set<InferenceProtocolId> get protocols => const {
    InferenceProtocolId.openAiCompat,
  };

  /// Emits whenever a model is installed or removed.
  @override
  Stream<void> get modelsChanged => _index.changes;

  @override
  Future<CreditsResult> credits() async => const CreditsUnsupported();

  @override
  Future<KeyInfoResult> keyInfo() async => const KeyInfoUnsupported();

  /// The models in the index, read without starting the server.
  @override
  Future<ProviderModelsResult> models() async => switch (await _index.read()) {
    ModelIndexListed(:final entries) => ProviderModelsListed([
      for (final entry in entries) _toProviderModel(entry),
    ]),
    ModelIndexUnreadable(:final reason) => ProviderModelsFailed(
      ProviderFailure(
        kind: InferenceFailureKind.malformedResponse,
        message: reason,
      ),
    ),
  };

  /// Takes the owner session, then loads the model, reporting the load's
  /// progress as the session does. The model is lost once the session
  /// ends, since a server that comes back serves neither it nor its leases
  /// until it is activated again.
  @override
  ModelActivation activate(ModelActivationRequest request) {
    final progress = StreamController<double>();
    final lost = Completer<void>();
    return ModelActivation(
      progress: progress.stream,
      result: _activate(request, progress, lost),
      lost: lost.future,
    );
  }

  @override
  AgentSessions openSessions({required int contextWindow}) =>
      LocalAgentSessions(link: _link);

  /// Unloads the model and hands the server back, so another bestie can use
  /// it.
  @override
  Future<void> deactivate() => _link.release();

  Future<ModelActivationResult> _activate(
    ModelActivationRequest request,
    StreamController<double> progress,
    Completer<void> lost,
  ) async {
    final options = _options();
    final attached = await _link.attach();
    if (attached is! LocalServerAttached) {
      unawaited(progress.close());
      return ModelActivationFailed(failureFor(attached));
    }
    final loading = _link.modelStatusChanges.listen((status) {
      if (status case ModelLoading(
        :final localId,
        progress: final fraction,
      ) when localId == request.modelId) {
        progress.add(fraction);
      }
    });
    final loaded = await _link.load(
      ModelLoadRequest(
        localId: request.modelId,
        maxAgents: request.maxAgents,
        contextCap: options.contextCap,
      ),
    );
    await loading.cancel();
    unawaited(progress.close());
    return switch (loaded) {
      ModelLoaded(:final ready) => _activated(request, attached, ready, lost),
      ModelLoadFailed(:final reason) => ModelActivationFailed(
        ProviderFailure(kind: InferenceFailureKind.server, message: reason),
      ),
    };
  }

  ModelActivated _activated(
    ModelActivationRequest request,
    LocalServerAttached attached,
    ModelReady ready,
    Completer<void> lost,
  ) {
    lost.complete(_link.untilDetached());
    return ModelActivated(
      contextWindow: ready.contextSize,
      endpoint: switch (request.protocol) {
        InferenceProtocolId.openAiCompat => InferenceEndpoint(
          baseUrl: ServerApi.urlFor(attached.port, '/v1'),
          headers: {bestieOwnerHeader: attached.ownerToken},
          dialect: _descriptor.dialect,
        ),
      },
    );
  }

  /// Why activation cannot go on while the client stands at [connection].
  @visibleForTesting
  static ProviderFailure failureFor(LocalServerConnection connection) =>
      ProviderFailure(
        kind: InferenceFailureKind.server,
        message: switch (connection) {
          LocalServerBusy(:final ownerPid) => bestieServerBusyMessage(ownerPid),
          LocalServerVersionMismatch(:final protocolVersion) =>
            'The running local model server speaks protocol '
                '$protocolVersion; this bestie speaks $bestieProtocolVersion. '
                'It exits once its owner closes and it sits idle.',
          LocalServerSpawnFailed(:final reason) =>
            'Could not start the local model server: $reason',
          LocalServerDisconnected(:final reason) =>
            reason ?? 'The local model server is not connected.',
          LocalServerAttaching() ||
          LocalServerAttached() => 'The local model server is not connected.',
        },
      );

  static ProviderModel _toProviderModel(ModelIndexEntry entry) => ProviderModel(
    id: entry.localId,
    name: entry.displayName,
    contextLength: entry.trainedContextLength,
    supportsTools: true,
    reasoning: _reasoningOf(entry.reasoning),
  );

  /// How the server treats each kind: a toggle thinks unless declined, and
  /// declining an effort model picks its cheapest effort rather than none.
  static ProviderReasoning? _reasoningOf(ModelReasoning reasoning) =>
      switch (reasoning) {
        ModelReasoningNone() => null,
        ModelReasoningAlways() => const ProviderReasoningFixed(),
        ModelReasoningToggle() => const ProviderReasoningToggle(
          enabledByDefault: true,
        ),
        ModelReasoningEfforts(:final efforts) => ProviderReasoningEfforts(
          efforts: efforts,
          canDisable: false,
          defaultEffort: efforts.contains('medium') ? 'medium' : efforts.first,
        ),
      };
}
