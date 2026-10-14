import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// The local bestie server: the agent identity on every completion so each
/// agent keeps its own cached prefix, thinking toggled through the chat
/// template, effort through the base protocol, and prefill progress and
/// per-chunk timings streamed back.
@PartOf(BuiltInServerClient)
final class BestieServerDialect implements OpenAiDialect {
  const BestieServerDialect();

  static const _standard = StandardOpenAiDialect();

  static const Map<String, Object?> _streamed = {
    bestieReturnProgressField: true,
    bestieTimingsPerTokenField: true,
  };

  @override
  OpenAiExtensions extensionsFor(CompletionRequest request) => OpenAiExtensions(
    headers: {bestieAgentHeader: ?request.agent?.id},
    body: {..._streamed, ..._reasoning(request)},
  );

  static Map<String, Object?> _reasoning(CompletionRequest request) =>
      switch (request.reasoning) {
        CompletionReasoningDefault() => const {},
        CompletionReasoningDisabled() => _thinking(enabled: false),
        CompletionReasoningEnabled() => _thinking(enabled: true),
        CompletionReasoningEffort() => _standard.extensionsFor(request).body,
      };

  static Map<String, Object?> _thinking({required bool enabled}) => {
    bestieChatTemplateKwargsField: {bestieEnableThinkingKey: enabled},
  };
}
