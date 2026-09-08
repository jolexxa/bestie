import 'package:intentions/intentions.dart';

/// What an in-flight turn is doing right now, as far as the chat can tell.
@model
enum TurnActivity {
  /// Nothing answer-shaped has streamed yet: the prompt is prefilling or the
  /// model is reasoning.
  thinking,

  /// Answer text is streaming.
  responding,

  /// The model has opened a tool call and is still writing its arguments.
  draftingToolCall,

  /// Every tool call of the step has landed and is being executed.
  executingTools,

  /// A rolling-compaction pass is folding.
  compacting,
}
