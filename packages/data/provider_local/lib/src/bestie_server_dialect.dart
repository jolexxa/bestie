import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/local_connection.dart';

/// The local bestie server: the agent identity on every completion so each
/// agent keeps its own cached prefix, thinking toggled through the chat
/// template, and effort through the base protocol.
@PartOf(LocalConnection)
final class BestieServerDialect implements OpenAiDialect {
  const BestieServerDialect();

  static const _standard = StandardOpenAiDialect();

  @override
  OpenAiExtensions extensionsFor(CompletionRequest request) {
    final headers = {bestieAgentHeader: ?request.agent?.id};
    return switch (request.reasoning) {
      CompletionReasoningDefault() => OpenAiExtensions(headers: headers),
      CompletionReasoningDisabled() => OpenAiExtensions(
        headers: headers,
        body: _thinking(enabled: false),
      ),
      CompletionReasoningEnabled() => OpenAiExtensions(
        headers: headers,
        body: _thinking(enabled: true),
      ),
      CompletionReasoningEffort() => OpenAiExtensions(
        headers: headers,
        body: _standard.extensionsFor(request).body,
      ),
    };
  }

  static Map<String, Object?> _thinking({required bool enabled}) => {
    bestieChatTemplateKwargsField: {bestieEnableThinkingKey: enabled},
  };
}
