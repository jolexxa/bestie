import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final _endpoint = InferenceEndpoint(baseUrl: Uri.parse('http://model/v1'));

void main() {
  group('ModelActivationRequest', () {
    test('compares by value', () {
      const request = ModelActivationRequest(
        modelId: 'model',
        contextWindow: 8192,
        maxAgents: 3,
      );

      expect(
        request,
        const ModelActivationRequest(
          modelId: 'model',
          contextWindow: 8192,
          maxAgents: 3,
        ),
      );
      expect(
        request.hashCode,
        const ModelActivationRequest(
          modelId: 'model',
          contextWindow: 8192,
          maxAgents: 3,
        ).hashCode,
      );
      expect(
        request,
        isNot(
          const ModelActivationRequest(
            modelId: 'model',
            contextWindow: 8192,
            maxAgents: 2,
          ),
        ),
      );
    });

    test('asks for OpenAI-compatible completions unless told otherwise', () {
      expect(
        const ModelActivationRequest(
          modelId: 'model',
          contextWindow: 8192,
          maxAgents: 3,
        ).protocol,
        InferenceProtocolId.openAiCompat,
      );
    });
  });

  group('ModelActivationResult', () {
    test('activated compares by context window and endpoint', () {
      expect(
        ModelActivated(contextWindow: 10, endpoint: _endpoint),
        ModelActivated(contextWindow: 10, endpoint: _endpoint),
      );
      expect(
        ModelActivated(contextWindow: 10, endpoint: _endpoint).hashCode,
        ModelActivated(contextWindow: 10, endpoint: _endpoint).hashCode,
      );
      expect(
        ModelActivated(contextWindow: 10, endpoint: _endpoint),
        isNot(ModelActivated(contextWindow: 11, endpoint: _endpoint)),
      );
      expect(
        ModelActivated(contextWindow: 10, endpoint: _endpoint),
        isNot(
          ModelActivated(
            contextWindow: 10,
            endpoint: InferenceEndpoint(baseUrl: Uri.parse('http://other')),
          ),
        ),
      );
    });

    test('failed compares by failure', () {
      const failure = ProviderFailure(
        kind: InferenceFailureKind.server,
        message: 'gone',
      );

      expect(
        const ModelActivationFailed(failure),
        const ModelActivationFailed(failure),
      );
      expect(
        const ModelActivationFailed(failure).hashCode,
        const ModelActivationFailed(failure).hashCode,
      );
      expect(
        const ModelActivationFailed(failure),
        isNot(
          const ModelActivationFailed(
            ProviderFailure(kind: InferenceFailureKind.network, message: 'x'),
          ),
        ),
      );
    });
  });

  test('ModelActivation carries its progress and result', () async {
    final activation = ModelActivation(
      progress: Stream.fromIterable([0.5, 1]),
      result: Future.value(
        ModelActivated(contextWindow: 1, endpoint: _endpoint),
      ),
    );

    expect(await activation.progress.toList(), [0.5, 1]);
    expect(
      await activation.result,
      ModelActivated(contextWindow: 1, endpoint: _endpoint),
    );
  });

  test('ModelActivation is never lost unless told how', () async {
    final lost = Completer<void>();
    final losable = ModelActivation(
      progress: const Stream.empty(),
      result: Future.value(
        ModelActivated(contextWindow: 1, endpoint: _endpoint),
      ),
      lost: lost.future,
    );
    final kept = ModelActivation(
      progress: const Stream.empty(),
      result: Future.value(
        ModelActivated(contextWindow: 1, endpoint: _endpoint),
      ),
    );
    var keptLost = false;
    unawaited(kept.lost.then((_) => keptLost = true));

    lost.complete();

    await expectLater(losable.lost, completes);
    await pumpEventQueue();
    expect(keptLost, isFalse);
  });
}
