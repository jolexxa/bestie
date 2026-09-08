import 'package:agent_provider_protocol/agent_provider_protocol.dart';

const primaryHandle = AgentHandle(id: 'primary:1', kind: AgentKind.primary);

const subagentHandle = AgentHandle(
  id: 'subagent:2',
  kind: AgentKind.subagent,
  label: 'helper',
);

ToolDefinition tool(String name) => ToolDefinition(
  name: name,
  description: 'The $name tool',
  parameters: const {
    'type': 'object',
    'properties': {
      'text': {'type': 'string'},
    },
  },
  onProgress: 'Running $name',
  onSuccess: 'Ran $name',
  onError: 'Failed $name',
);

AgentConfig config({
  String systemPrompt = 'Be brief.',
  String reasoningMode = 'auto',
  String compactionReasoningMode = 'auto',
  double compactionRatio = 0.5,
  List<ToolDefinition> tools = const [],
  SamplingOptions sampling = const SamplingOptions(seed: 0),
}) => AgentConfig(
  systemPrompt: systemPrompt,
  sampling: sampling,
  reasoningMode: reasoningMode,
  compactionReasoningMode: compactionReasoningMode,
  compactionRatio: compactionRatio,
  tools: tools,
);

Transcript transcriptOf(List<TranscriptEntry> entries, {int revision = 0}) =>
    Transcript(id: TranscriptId.v7(), revision: revision, entries: entries);

TranscriptEntry userEntry(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.user,
  blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
);

TranscriptEntry assistantEntry({
  String text = '',
  String reasoning = '',
  List<ToolCall> toolCalls = const [],
}) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.assistant,
  blocks: [
    if (reasoning.isNotEmpty)
      TranscriptReasoningBlock(id: TranscriptBlockId.v7(), text: reasoning),
    if (text.isNotEmpty)
      TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text),
    for (final call in toolCalls)
      TranscriptToolCallBlock(id: TranscriptBlockId.v7(), toolCall: call),
  ],
);

TranscriptEntry toolEntry(ToolCallResponse response) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.tool,
  name: response.toolName,
  blocks: [
    TranscriptToolCallResponseBlock(
      id: TranscriptBlockId.v7(),
      response: response,
    ),
  ],
);

TranscriptEntry summaryEntry(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.system,
  blocks: [TranscriptSummaryBlock(id: TranscriptBlockId.v7(), text: text)],
);

TranscriptEntry systemNoteEntry(String text, {String toolOutput = ''}) =>
    TranscriptEntry(
      id: TranscriptEntryId.v7(),
      role: Role.system,
      blocks: [
        TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text),
        if (toolOutput.isNotEmpty)
          TranscriptToolOutputBlock(
            id: TranscriptBlockId.v7(),
            text: toolOutput,
          ),
      ],
    );

const compactionContent = CompactionPromptContent(
  instruction: 'You summarize.',
  prefill: 'Summary:',
  format: 'Use bullets.',
);
