import 'package:inference_protocol/inference_protocol.dart'
    show InferenceDialect;
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderDescriptor;

const ProviderDescriptor openRouterDescriptor = ProviderDescriptor(
  id: 'openrouter',
  displayName: 'OpenRouter',
  requiresApiKey: true,
  dialect: InferenceDialect.openRouter,
  catalogId: 'openrouter',
);

final ProviderDescriptor fireworksDescriptor = ProviderDescriptor(
  id: 'fireworks',
  displayName: 'Fireworks AI',
  requiresApiKey: true,
  dialect: InferenceDialect.openAi,
  baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
  catalogId: 'fireworks-ai',
);

/// Any OpenAI-compatible server the user points us at, such as a local
/// llama.cpp server.
const ProviderDescriptor customDescriptor = ProviderDescriptor(
  id: 'custom',
  displayName: 'Custom endpoint',
  requiresApiKey: false,
  dialect: InferenceDialect.openAi,
  requiresBaseUrl: true,
);
