import 'package:bestie_config_view/src/view/components/info_section.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

void main() {
  const model = ProviderModelRef(providerId: 'local', modelId: 'qwen3-8b');

  test('reads where the provider stands', () {
    expect(
      providerSummary(const ProviderStatusUnconfigured()),
      'Not configured',
    );
    expect(
      providerSummary(const ProviderStatusConnecting(model: model)),
      'Connecting to local:qwen3-8b…',
    );
    expect(
      providerSummary(
        const ProviderStatusConnecting(
          model: model,
          loading: LoadingModel(
            name: 'Qwen 3 8B',
            providerName: 'Local models',
            contextWindow: 40960,
            progress: 0.62,
          ),
        ),
      ),
      'Loading Local models · Qwen 3 8B 62%',
    );
  });
}
