import 'package:meta/meta.dart';

/// How hard the model should think before answering.
enum CompletionEffort { minimal, low, medium, high, xhigh, max }

/// Whether and how much the model should reason before answering.
@immutable
sealed class CompletionReasoning {
  const CompletionReasoning();
}

/// Say nothing; the model thinks however the provider configures it.
final class CompletionReasoningDefault extends CompletionReasoning {
  const CompletionReasoningDefault();

  @override
  bool operator ==(Object other) => other is CompletionReasoningDefault;

  @override
  int get hashCode => (CompletionReasoningDefault).hashCode;
}

/// Ask the model not to think at all.
final class CompletionReasoningDisabled extends CompletionReasoning {
  const CompletionReasoningDisabled();

  @override
  bool operator ==(Object other) => other is CompletionReasoningDisabled;

  @override
  int get hashCode => (CompletionReasoningDisabled).hashCode;
}

/// Ask the model to think, without choosing how hard.
final class CompletionReasoningEnabled extends CompletionReasoning {
  const CompletionReasoningEnabled();

  @override
  bool operator ==(Object other) => other is CompletionReasoningEnabled;

  @override
  int get hashCode => (CompletionReasoningEnabled).hashCode;
}

/// Ask the model to think at a specific effort.
final class CompletionReasoningEffort extends CompletionReasoning {
  const CompletionReasoningEffort(this.effort);

  final CompletionEffort effort;

  @override
  bool operator ==(Object other) =>
      other is CompletionReasoningEffort && other.effort == effort;

  @override
  int get hashCode => effort.hashCode;
}
