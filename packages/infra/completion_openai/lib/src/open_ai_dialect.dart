import 'package:completion_protocol/completion_protocol.dart';
import 'package:meta/meta.dart';

/// Adds one server's extensions to the base chat-completions request.
// Providers implement it, so it stays an interface.
// ignore: one_member_abstracts
abstract interface class OpenAiDialect {
  OpenAiExtensions extensionsFor(CompletionRequest request);
}

/// The headers and body fields one request adds to the base protocol.
@immutable
final class OpenAiExtensions {
  const OpenAiExtensions({this.headers = const {}, this.body = const {}});

  final Map<String, String> headers;

  final Map<String, Object?> body;
}

/// The base OpenAI protocol: reasoning is controlled through
/// `reasoning_effort`.
final class StandardOpenAiDialect implements OpenAiDialect {
  const StandardOpenAiDialect();

  @override
  OpenAiExtensions extensionsFor(CompletionRequest request) =>
      switch (request.reasoning) {
        CompletionReasoningDefault() ||
        CompletionReasoningEnabled() => const OpenAiExtensions(),
        CompletionReasoningDisabled() => const OpenAiExtensions(
          body: {'reasoning_effort': 'none'},
        ),
        CompletionReasoningEffort(:final effort) => OpenAiExtensions(
          body: {'reasoning_effort': effort.name},
        ),
      };
}
