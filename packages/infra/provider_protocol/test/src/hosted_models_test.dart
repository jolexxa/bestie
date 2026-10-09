import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final _endpoint = InferenceEndpoint(baseUrl: Uri.parse('https://hosted/v1'));

final class _Hosted with HostedModels {
  _Hosted({Map<InferenceProtocolId, InferenceEndpoint>? endpoints})
    : endpoints = endpoints ?? {InferenceProtocolId.openAiCompat: _endpoint};

  @override
  final Map<InferenceProtocolId, InferenceEndpoint> endpoints;

  @override
  String get id => 'hosted';

  @override
  String get displayName => 'Hosted';

  @override
  Future<CreditsResult> credits() async => const CreditsUnsupported();

  @override
  Future<KeyInfoResult> keyInfo() async => const KeyInfoUnsupported();

  @override
  Future<ProviderModelsResult> models() async => const ProviderModelsListed([]);
}

void main() {
  group('HostedModels', () {
    test('speaks the protocols it has endpoints for', () {
      expect(_Hosted().protocols, {InferenceProtocolId.openAiCompat});
      expect(_Hosted(endpoints: const {}).protocols, isEmpty);
    });

    test('never reports its models changing', () async {
      expect(await _Hosted().modelsChanged.isEmpty, isTrue);
    });

    test('activates at once at its endpoint with the listed window', () async {
      final activation = _Hosted().activate(
        const ModelActivationRequest(
          modelId: 'model',
          contextWindow: 8192,
          maxAgents: 3,
        ),
      );

      expect(await activation.progress.toList(), isEmpty);
      expect(
        await activation.result,
        ModelActivated(contextWindow: 8192, endpoint: _endpoint),
      );
    });

    test('cannot activate for a protocol it has no endpoint for', () async {
      final activation = _Hosted(endpoints: const {}).activate(
        const ModelActivationRequest(
          modelId: 'model',
          contextWindow: 8192,
          maxAgents: 3,
        ),
      );

      expect(
        await activation.result,
        const ModelActivationFailed(
          ProviderFailure(
            kind: InferenceFailureKind.badRequest,
            message: 'Hosted offers no openAiCompat endpoint.',
          ),
        ),
      );
    });

    test('gives every agent a window of its own', () async {
      final sessions = _Hosted().openSessions(contextWindow: 4096);
      const subagent = AgentIdentity(
        id: 'subagent:2',
        kind: AgentIdentityKind.subagent,
      );

      expect(sessions, isA<PerAgentWindowSessions>());
      expect(
        await sessions.open(subagent),
        const AgentSessionOpened(claimedTokens: 4096),
      );
      await sessions.dispose();
    });

    test('holds nothing to let go of', () async {
      await expectLater(_Hosted().deactivate(), completes);
    });
  });
}
