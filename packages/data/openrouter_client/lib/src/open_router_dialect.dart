import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:openrouter_client/src/open_router_client.dart';

/// OpenRouter controls reasoning through its `reasoning` object.
@PartOf(OpenRouterClient)
final class OpenRouterDialect implements OpenAiDialect {
  const OpenRouterDialect();

  @override
  OpenAiExtensions extensionsFor(CompletionRequest request) =>
      switch (request.reasoning) {
        CompletionReasoningDefault() => const OpenAiExtensions(),
        CompletionReasoningDisabled() => const OpenAiExtensions(
          body: {
            'reasoning': {'enabled': false},
          },
        ),
        CompletionReasoningEnabled() => const OpenAiExtensions(
          body: {
            'reasoning': {'enabled': true},
          },
        ),
        CompletionReasoningEffort(:final effort) => OpenAiExtensions(
          body: {
            'reasoning': {'effort': effort.name},
          },
        ),
      };
}
