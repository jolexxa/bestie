import 'package:prompt_builder/src/compaction_prompt_content.dart';

/// Supplies the compaction summarizer's prompt content.
abstract interface class CompactionPromptContentBuilder {
  CompactionPromptContent build();
}
