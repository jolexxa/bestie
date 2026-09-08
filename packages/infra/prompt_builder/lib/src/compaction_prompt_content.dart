/// The compaction summarizer's prompt content.
final class CompactionPromptContent {
  const CompactionPromptContent({
    required this.instruction,
    required this.prefill,
    required this.format,
  });

  /// The summarizer's own system-role instruction.
  final String instruction;

  /// The opening the summarizer is asked to begin with, so it continues from
  /// the first section header instead of narrating a preamble.
  final String prefill;

  /// Appended after the conversation body, describing the target format.
  final String format;
}
