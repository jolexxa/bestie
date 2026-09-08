import 'package:intentions/intentions.dart';
import 'package:prompt_builder/prompt_builder.dart';

const _instruction =
    'You are a context summarization assistant. Read the conversation between '
    'the user and the assistant and produce a structured summary following the '
    'format specified. Do NOT continue the conversation, do NOT answer any '
    'questions in it, and output ONLY the structured summary.';

/// The opening the summarizer is asked to begin its reply with.
const _prefill = '## Goal\n';

const _format =
    'The messages above represent a conversation to compress. Reduce it to the '
    'essential information another assistant needs to continue the work. '
    'Stop when the Critical Context section is complete.\n'
    '\n'
    'Use this format:\n'
    '## Goal\n'
    '[what the user is trying to accomplish]\n'
    '## Progress\n'
    '- [What has been done and any specific, interesting findings]\n'
    '## Key Decisions\n'
    '- **[decision]**: [brief rationale, or "none"]\n'
    '## Critical Context\n'
    'Include hard-won discovery details and specific, minimal snippets '
    'of key tool outputs rather than glossing over what happened. '
    "Persist relevant url's, file paths, code snippets, or other important "
    'bits of information which would allow you to rediscover any missing '
    'information, should you need to. Use only names and facts that appear '
    'in the conversation.\n'
    '\n';

/// Bestie's compaction summarizer prompt content.
@dataSource
final class BestieCompactionPromptContentBuilder
    implements CompactionPromptContentBuilder {
  const BestieCompactionPromptContentBuilder();

  @override
  CompactionPromptContent build() => const CompactionPromptContent(
    instruction: _instruction,
    prefill: _prefill,
    format: _format,
  );
}
