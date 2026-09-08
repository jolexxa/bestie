import 'package:meta/meta.dart';

/// How hard the model should think before answering.
enum InferenceEffort { minimal, low, medium, high, xhigh, max }

/// Whether and how much the model should reason before answering.
@immutable
sealed class InferenceReasoning {
  const InferenceReasoning();
}

/// Say nothing; the model thinks however the provider configures it.
final class InferenceReasoningDefault extends InferenceReasoning {
  const InferenceReasoningDefault();

  @override
  bool operator ==(Object other) => other is InferenceReasoningDefault;

  @override
  int get hashCode => (InferenceReasoningDefault).hashCode;
}

/// Ask the model not to think at all.
final class InferenceReasoningDisabled extends InferenceReasoning {
  const InferenceReasoningDisabled();

  @override
  bool operator ==(Object other) => other is InferenceReasoningDisabled;

  @override
  int get hashCode => (InferenceReasoningDisabled).hashCode;
}

/// Ask the model to think, without choosing how hard.
final class InferenceReasoningEnabled extends InferenceReasoning {
  const InferenceReasoningEnabled();

  @override
  bool operator ==(Object other) => other is InferenceReasoningEnabled;

  @override
  int get hashCode => (InferenceReasoningEnabled).hashCode;
}

/// Ask the model to think at a specific effort.
final class InferenceReasoningEffort extends InferenceReasoning {
  const InferenceReasoningEffort(this.effort);

  final InferenceEffort effort;

  @override
  bool operator ==(Object other) =>
      other is InferenceReasoningEffort && other.effort == effort;

  @override
  int get hashCode => effort.hashCode;
}
