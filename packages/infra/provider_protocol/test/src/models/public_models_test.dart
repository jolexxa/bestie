import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  const failure = ProviderFailure(
    kind: InferenceFailureKind.auth,
    message: 'nope',
  );

  group('ProviderFailure', () {
    test('compares by kind and message', () {
      expect(
        failure,
        const ProviderFailure(kind: InferenceFailureKind.auth, message: 'nope'),
      );
      expect(
        failure.hashCode,
        const ProviderFailure(
          kind: InferenceFailureKind.auth,
          message: 'nope',
        ).hashCode,
      );
      expect(
        failure,
        isNot(
          const ProviderFailure(
            kind: InferenceFailureKind.auth,
            message: 'other',
          ),
        ),
      );
      expect(failure.toString(), 'ProviderFailure(auth): nope');
    });
  });

  group('ProviderCredits', () {
    test('compares by value', () {
      const credits = ProviderCredits(
        spent: 2.5,
        remaining: 7.5,
        window: SpendWindow.lifetime,
      );

      expect(
        credits,
        const ProviderCredits(
          spent: 2.5,
          remaining: 7.5,
          window: SpendWindow.lifetime,
        ),
      );
      expect(
        credits.hashCode,
        const ProviderCredits(
          spent: 2.5,
          remaining: 7.5,
          window: SpendWindow.lifetime,
        ).hashCode,
      );
      expect(
        credits,
        isNot(const ProviderCredits(spent: 3, window: SpendWindow.lifetime)),
      );
      expect(
        credits,
        isNot(
          const ProviderCredits(
            spent: 2.5,
            remaining: 7.5,
            window: SpendWindow.monthToDate,
          ),
        ),
      );
      expect(
        credits.toString(),
        'ProviderCredits(spent: 2.5, window: lifetime, remaining: 7.5)',
      );
    });

    test('leaves the balance out when the provider reports spend alone', () {
      const credits = ProviderCredits(
        spent: 2.5,
        window: SpendWindow.monthToDate,
      );

      expect(credits.remaining, isNull);
      expect(
        credits.toString(),
        'ProviderCredits(spent: 2.5, window: monthToDate, remaining: null)',
      );
    });
  });

  group('ProviderCredits.charged', () {
    test('books the charge against spend and balance alike', () {
      const credits = ProviderCredits(
        spent: 2.5,
        window: SpendWindow.lifetime,
        remaining: 7.5,
      );

      expect(
        credits.charged(0.5),
        const ProviderCredits(
          spent: 3,
          window: SpendWindow.lifetime,
          remaining: 7,
        ),
      );
    });

    test('leaves a balance the provider never gave alone', () {
      const credits = ProviderCredits(
        spent: 2.5,
        window: SpendWindow.monthToDate,
      );

      expect(
        credits.charged(0.5),
        const ProviderCredits(spent: 3, window: SpendWindow.monthToDate),
      );
    });
  });

  group('ProviderKeyInfo', () {
    test('compares by value', () {
      const info = ProviderKeyInfo(
        label: 'sk-or-v1-abc',
        usage: 1.5,
        isFreeTier: false,
        limit: 20,
        limitRemaining: 18.5,
      );

      expect(
        info,
        const ProviderKeyInfo(
          label: 'sk-or-v1-abc',
          usage: 1.5,
          isFreeTier: false,
          limit: 20,
          limitRemaining: 18.5,
        ),
      );
      expect(
        info.hashCode,
        const ProviderKeyInfo(
          label: 'sk-or-v1-abc',
          usage: 1.5,
          isFreeTier: false,
          limit: 20,
          limitRemaining: 18.5,
        ).hashCode,
      );
      expect(
        info,
        isNot(
          const ProviderKeyInfo(
            label: 'sk-or-v1-abc',
            usage: 1.5,
            isFreeTier: true,
          ),
        ),
      );
      expect(info.toString(), 'ProviderKeyInfo(sk-or-v1-abc, used: 1.5)');
    });
  });

  group('ProviderModel', () {
    test('compares by value', () {
      const model = ProviderModel(
        id: 'openai/gpt-4o-mini',
        name: 'GPT-4o mini',
        contextLength: 128000,
        supportsTools: true,
        promptPricePerToken: 0.00000015,
        completionPricePerToken: 0.0000006,
      );

      expect(
        model,
        const ProviderModel(
          id: 'openai/gpt-4o-mini',
          name: 'GPT-4o mini',
          contextLength: 128000,
          supportsTools: true,
          promptPricePerToken: 0.00000015,
          completionPricePerToken: 0.0000006,
        ),
      );
      expect(
        model.hashCode,
        const ProviderModel(
          id: 'openai/gpt-4o-mini',
          name: 'GPT-4o mini',
          contextLength: 128000,
          supportsTools: true,
          promptPricePerToken: 0.00000015,
          completionPricePerToken: 0.0000006,
        ).hashCode,
      );
      expect(
        model,
        isNot(
          const ProviderModel(
            id: 'openai/gpt-4o-mini',
            name: 'GPT-4o mini',
            contextLength: 128000,
            supportsTools: true,
            reasoning: ProviderReasoningFixed(),
          ),
        ),
      );
      expect(model.contextLength, 128000);
      expect(model.reasoning, isNull);
      expect(model.toString(), startsWith('ProviderModel('));
    });
  });

  group('ProviderReasoning', () {
    test('fixed and toggle compare by type and default', () {
      expect(const ProviderReasoningFixed(), const ProviderReasoningFixed());
      expect(
        const ProviderReasoningFixed().hashCode,
        const ProviderReasoningFixed().hashCode,
      );
      expect(
        const ProviderReasoningFixed().toString(),
        startsWith('ProviderReasoningFixed('),
      );
      expect(
        const ProviderReasoningToggle(enabledByDefault: true),
        const ProviderReasoningToggle(enabledByDefault: true),
      );
      expect(
        const ProviderReasoningToggle(enabledByDefault: true).hashCode,
        const ProviderReasoningToggle(enabledByDefault: true).hashCode,
      );
      expect(
        const ProviderReasoningToggle(enabledByDefault: true),
        isNot(const ProviderReasoningToggle(enabledByDefault: false)),
      );
      expect(
        const ProviderReasoningToggle(),
        isNot(const ProviderReasoningFixed()),
      );
      expect(
        const ProviderReasoningToggle().toString(),
        startsWith('ProviderReasoningToggle('),
      );
    });

    test('efforts compare by value including order', () {
      const reasoning = ProviderReasoningEfforts(
        efforts: ['low', 'medium', 'high'],
        canDisable: false,
        defaultEffort: 'medium',
      );

      expect(
        reasoning,
        const ProviderReasoningEfforts(
          efforts: ['low', 'medium', 'high'],
          canDisable: false,
          defaultEffort: 'medium',
        ),
      );
      expect(
        reasoning.hashCode,
        const ProviderReasoningEfforts(
          efforts: ['low', 'medium', 'high'],
          canDisable: false,
          defaultEffort: 'medium',
        ).hashCode,
      );
      expect(
        reasoning,
        isNot(
          const ProviderReasoningEfforts(
            efforts: ['high', 'medium', 'low'],
            canDisable: false,
            defaultEffort: 'medium',
          ),
        ),
      );
      expect(
        reasoning,
        isNot(
          const ProviderReasoningEfforts(
            efforts: ['low', 'medium'],
            canDisable: false,
            defaultEffort: 'medium',
          ),
        ),
      );
      expect(
        reasoning,
        isNot(
          const ProviderReasoningEfforts(
            efforts: ['low', 'medium', 'high'],
            canDisable: true,
            defaultEffort: 'medium',
          ),
        ),
      );
      expect(reasoning, isNot(const ProviderReasoningFixed()));
      expect(reasoning.toString(), startsWith('ProviderReasoningEfforts('));
    });
  });

  group('results', () {
    test('expose fetched values and failures', () {
      const credits = ProviderCredits(
        spent: 0,
        remaining: 1,
        window: SpendWindow.lifetime,
      );
      const keyInfo = ProviderKeyInfo(
        label: 'key',
        usage: 0,
        isFreeTier: true,
      );
      const model = ProviderModel(
        id: 'm',
        name: 'M',
        contextLength: 1,
        supportsTools: false,
      );
      const creditsResults = <CreditsResult>[
        CreditsFetched(credits),
        CreditsFailed(failure),
        CreditsUnsupported(),
      ];
      const keyResults = <KeyInfoResult>[
        KeyInfoFetched(keyInfo),
        KeyInfoFailed(failure),
        KeyInfoUnsupported(),
      ];
      const modelResults = <ProviderModelsResult>[
        ProviderModelsListed([model]),
        ProviderModelsFailed(failure),
      ];

      expect((creditsResults[0] as CreditsFetched).credits, credits);
      expect((creditsResults[1] as CreditsFailed).failure, failure);
      expect((keyResults[0] as KeyInfoFetched).keyInfo, keyInfo);
      expect((keyResults[1] as KeyInfoFailed).failure, failure);
      expect(creditsResults[2], isA<CreditsUnsupported>());
      expect(keyResults[2], isA<KeyInfoUnsupported>());
      expect((modelResults[0] as ProviderModelsListed).models, [model]);
      expect((modelResults[1] as ProviderModelsFailed).failure, failure);
    });
  });

  group('ProviderDescriptor', () {
    test('compares by value', () {
      final descriptor = ProviderDescriptor(
        id: 'fireworks',
        displayName: 'Fireworks AI',
        requiresApiKey: true,
        dialect: InferenceDialect.openAi,
        baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
        catalogId: 'fireworks-ai',
      );

      expect(
        descriptor,
        ProviderDescriptor(
          id: 'fireworks',
          displayName: 'Fireworks AI',
          requiresApiKey: true,
          dialect: InferenceDialect.openAi,
          baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
          catalogId: 'fireworks-ai',
        ),
      );
      expect(
        descriptor.hashCode,
        ProviderDescriptor(
          id: 'fireworks',
          displayName: 'Fireworks AI',
          requiresApiKey: true,
          dialect: InferenceDialect.openAi,
          baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
          catalogId: 'fireworks-ai',
        ).hashCode,
      );
      expect(
        descriptor,
        isNot(
          const ProviderDescriptor(
            id: 'custom',
            displayName: 'Custom endpoint',
            requiresApiKey: false,
            dialect: InferenceDialect.openAi,
            requiresBaseUrl: true,
          ),
        ),
      );
      expect(descriptor.requiresBaseUrl, isFalse);
      expect(descriptor.toString(), startsWith('ProviderDescriptor('));
    });
  });

  group('ProviderModelRef', () {
    test('round-trips through the qualified form', () {
      const ref = ProviderModelRef(
        providerId: 'openrouter',
        modelId: 'openai/gpt-4o-mini',
      );

      expect(ref.qualified, 'openrouter:openai/gpt-4o-mini');
      expect(ProviderModelRef.parse(ref.qualified), ref);
      expect(ref.hashCode, ProviderModelRef.parse(ref.qualified).hashCode);
      expect(ref.toString(), startsWith('ProviderModelRef('));
      expect(
        ref,
        isNot(
          const ProviderModelRef(
            providerId: 'fireworks',
            modelId: 'openai/gpt-4o-mini',
          ),
        ),
      );
    });

    test('keeps colons inside the model id', () {
      expect(
        ProviderModelRef.parse('custom:model:tag'),
        const ProviderModelRef(providerId: 'custom', modelId: 'model:tag'),
      );
    });

    test('rejects text without a provider or a model', () {
      expect(ProviderModelRef.parse(''), isNull);
      expect(ProviderModelRef.parse('openai/gpt-4o-mini'), isNull);
      expect(ProviderModelRef.parse(':model'), isNull);
      expect(ProviderModelRef.parse('openrouter:'), isNull);
    });
  });

  group('CatalogResult', () {
    test('exposes listed models and failures', () {
      const model = ProviderModel(id: 'm', name: 'M', supportsTools: true);
      const results = <CatalogResult>[
        CatalogListed([model]),
        CatalogUnavailable(failure),
      ];

      expect((results[0] as CatalogListed).models, [model]);
      expect((results[1] as CatalogUnavailable).failure, failure);
    });
  });
}
