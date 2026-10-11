import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final class _MockProviderModel extends Mock implements ProviderModel {}

void main() {
  group('ProviderModelLoadRequest', () {
    test('compares by value', () {
      const request = ProviderModelLoadRequest(
        modelId: 'm',
        contextWindow: 8192,
        maxAgents: 3,
        contextCap: 4096,
      );

      expect(
        request,
        const ProviderModelLoadRequest(
          modelId: 'm',
          contextWindow: 8192,
          maxAgents: 3,
          contextCap: 4096,
        ),
      );
      expect(
        request.hashCode,
        const ProviderModelLoadRequest(
          modelId: 'm',
          contextWindow: 8192,
          maxAgents: 3,
          contextCap: 4096,
        ).hashCode,
      );
      expect(
        request,
        isNot(
          const ProviderModelLoadRequest(
            modelId: 'm',
            contextWindow: 8192,
            maxAgents: 3,
          ),
        ),
      );
    });
  });

  group('ProviderModelLoadProgress', () {
    test('compares by kind and fraction', () {
      expect(const ProviderModelMeasuring(), const ProviderModelMeasuring());
      expect(
        const ProviderModelMeasuring().hashCode,
        const ProviderModelMeasuring().hashCode,
      );
      expect(const ProviderModelLoading(0.5), const ProviderModelLoading(0.5));
      expect(
        const ProviderModelLoading(0.5).hashCode,
        const ProviderModelLoading(0.5).hashCode,
      );
      expect(
        const ProviderModelLoading(0.5),
        isNot(const ProviderModelLoading(0.6)),
      );
      expect(
        const ProviderModelLoading(0.5),
        isNot(const ProviderModelMeasuring()),
      );
    });
  });

  group('ProviderModelLoad', () {
    test('reports progress until it settles', () async {
      final model = _MockProviderModel();
      final load = ProviderModelLoad(
        progress: Stream.fromIterable(const [
          ProviderModelMeasuring(),
          ProviderModelLoading(0.5),
        ]),
        result: Future.value(ProviderModelLoaded(model)),
      );

      expect(await load.progress.toList(), const [
        ProviderModelMeasuring(),
        ProviderModelLoading(0.5),
      ]);
      expect(await load.result, isA<ProviderModelLoaded>());
    });
  });

  group('ProviderModelLoad.settled', () {
    test('reports no progress and the given result', () async {
      final model = _MockProviderModel();
      final load = ProviderModelLoad.settled(ProviderModelLoaded(model));

      expect(await load.progress.toList(), isEmpty);
      final result = await load.result;
      expect(result, isA<ProviderModelLoaded>());
      expect((result as ProviderModelLoaded).model, same(model));
    });

    test('carries a failure', () async {
      const failure = ProviderAuthFailed('No key.');
      final load = ProviderModelLoad.settled(
        const ProviderModelLoadFailed(failure),
      );

      final result = await load.result;
      expect((result as ProviderModelLoadFailed).failure, failure);
    });
  });
}
