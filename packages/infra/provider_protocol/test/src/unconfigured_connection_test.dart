import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  const failure = ProviderAuthFailed('No key.');
  const connection = UnconfiguredConnection(failure);

  test('lists nothing', () async {
    final result = await connection.models();

    expect((result as ProviderModelsListed).models, isEmpty);
  });

  test('fails credits and loads with what is missing', () async {
    final credits = await connection.credits();
    final load = connection.load(
      const ProviderModelLoadRequest(
        modelId: 'm',
        contextWindow: 8192,
        maxAgents: 1,
      ),
    );

    expect((credits as CreditsFailed).failure, failure);
    expect(await load.progress.toList(), isEmpty);
    expect((await load.result as ProviderModelLoadFailed).failure, failure);
  });

  test('closes without holding anything', () async {
    await expectLater(connection.close(), completes);
  });
}
