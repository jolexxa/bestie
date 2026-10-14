import 'package:completion_protocol/src/models/completion_event.dart';
import 'package:completion_protocol/src/models/completion_request.dart';

/// Streams chat completions from one endpoint.
// Tests replace the client, so it stays an interface.
// ignore: one_member_abstracts
abstract interface class CompletionClient {
  /// Streams one chat completion. Never throws: failures arrive as an
  /// [CompletionFailed] event and then the stream closes.
  /// Completing [abortTrigger] cancels the request.
  Stream<CompletionEvent> complete(
    CompletionRequest request, {
    Future<void>? abortTrigger,
  });
}
