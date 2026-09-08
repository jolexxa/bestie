import 'package:inference_protocol/src/models/completion_request.dart';
import 'package:inference_protocol/src/models/inference_event.dart';
import 'package:inference_protocol/src/models/list_models_result.dart';

/// A connection to one remote inference endpoint.
abstract interface class InferenceClient {
  /// Lists the models the endpoint serves.
  Future<ListModelsResult> listModels();

  /// Streams one chat completion. Never throws: failures arrive as an
  /// [InferenceCompletionFailed] event and then the stream closes.
  /// Completing [abortTrigger] cancels the request.
  Stream<InferenceEvent> complete(
    CompletionRequest request, {
    Future<void>? abortTrigger,
  });

  /// Releases any underlying connections.
  Future<void> close();
}
