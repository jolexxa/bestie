import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prompt_builder/prompt_builder.dart';
import 'package:tool_protocol/tool_protocol.dart';

// ── Mocks ─────────────────────────────────────────────────

class MockProvider extends Mock implements AgentProvider {}

/// A [SubagentSystemPromptBuilder] that always returns [prompt].
final class FixedSubagentSystemPromptBuilder
    implements SubagentSystemPromptBuilder {
  const FixedSubagentSystemPromptBuilder(this.prompt);

  final String prompt;

  @override
  String build() => prompt;
}

/// A [CompactionPromptContentBuilder] that always returns [content].
final class FixedCompactionPromptContentBuilder
    implements CompactionPromptContentBuilder {
  const FixedCompactionPromptContentBuilder(this.content);

  final CompactionPromptContent content;

  @override
  CompactionPromptContent build() => content;
}

/// Shared compaction prompt content for session/repository tests.
const testCompactionPromptContent = CompactionPromptContent(
  instruction: 'summarize',
  prefill: '## Goal\n',
  format: 'use this format',
);

class MockAgent extends Mock implements Agent {}

class MockPendingToolCalls extends Mock implements PendingToolCalls {}

/// What an agent is offered.
ToolDefinitions offering([List<ToolDefinition> definitions = const []]) =>
    ToolDefinitions(definitions);

class MockConversationStore extends Mock implements ConversationStore {}

const agentHandle = AgentHandle(id: 'primary', kind: AgentKind.primary);
const subagentHandle = AgentHandle(id: 'subagent', kind: AgentKind.subagent);

void registerFallbacks() {
  registerFallbackValue(emptyTranscript());
  registerFallbackValue(agentHandle);
  registerFallbackValue(
    const AgentConfig(
      systemPrompt: '',
      sampling: SamplingOptions(seed: 0),
      reasoningMode: 'auto',
      compactionReasoningMode: 'auto',
      compactionRatio: 0.85,
      tools: [],
    ),
  );
  registerFallbackValue(TurnGoal.respond);
  registerFallbackValue(const TurnOptions.baseline(''));
  registerFallbackValue(<ToolCall>[]);
  registerFallbackValue(
    const ToolCallDefault(id: 'x', name: 'x', arguments: {}),
  );
  registerFallbackValue(<ToolCallResponse>[]);
  registerFallbackValue(
    const ToolCallSucceeded(callId: 'x', toolName: 'x', content: ''),
  );
  registerFallbackValue(fallbackData());
  registerFallbackValue(testCompactionPromptContent);
}

// ── Transcript builders ───────────────────────────────────

Transcript emptyTranscript() =>
    Transcript(id: TranscriptId.v7(), revision: 1, entries: const []);

Transcript ts(List<TranscriptEntry> entries) => Transcript(
  id: TranscriptId.v7(),
  revision: entries.length,
  entries: entries,
);

TranscriptEntry userTE(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.user,
  blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
);

TranscriptEntry asstTE(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.assistant,
  blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
);

TranscriptEntry toolCallTE(String callId, {String name = 'bash'}) =>
    TranscriptEntry(
      id: TranscriptEntryId.v7(),
      role: Role.assistant,
      blocks: [
        TranscriptToolCallBlock(
          id: TranscriptBlockId.v7(),
          toolCall: ToolCallDefault(
            id: callId,
            name: name,
            arguments: const {},
          ),
        ),
      ],
    );

TranscriptEntry toolResultTE(String callId, {String name = 'bash'}) =>
    TranscriptEntry(
      id: TranscriptEntryId.v7(),
      role: Role.tool,
      blocks: [
        TranscriptToolCallResponseBlock(
          id: TranscriptBlockId.v7(),
          response: ToolCallSucceeded(
            callId: callId,
            toolName: name,
            content: 'still running',
          ),
        ),
      ],
    );

TranscriptEntry summaryTE(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.system,
  blocks: [TranscriptSummaryBlock(id: TranscriptBlockId.v7(), text: text)],
);

// ── Persisted entry builders ──────────────────────────────

var _eid = 0;
String nextEid() => 'e${_eid++}';

MessageEntry msgUser(String text, {int responseId = 1}) => MessageEntry(
  id: nextEid(),
  timestamp: DateTime.utc(2025),
  responseId: responseId,
  entry: userTE(text),
);

MessageEntry msgAsst(String text, {int responseId = 1}) => MessageEntry(
  id: nextEid(),
  timestamp: DateTime.utc(2025),
  responseId: responseId,
  entry: asstTE(text),
);

AgentSessionData data(
  List<ConversationEntry> entries, {
  String id = 'c-1',
  String agentId = primaryAgentSessionId,
}) => AgentSessionData(
  conversationId: id,
  agentId: agentId,
  workingDirectory: '/elsewhere',
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
  entries: entries,
);

AgentSessionData fallbackData() => AgentSessionData(
  conversationId: 'x',
  agentId: primaryAgentSessionId,
  workingDirectory: '/work',
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
  entries: const [],
);

// ── View helpers ──────────────────────────────────────────

List<MessageTimelineItem> rowsOf(List<TimelineItem> items) => [
  for (final item in items)
    if (item is MessageTimelineItem) item,
];

/// The committed assistant transcript entry in [session]'s transcript.
TranscriptEntry committedAssistant(AgentSession session) => session
    .transcript
    .entries
    .whereType<MessageEntry>()
    .map((message) => message.entry)
    .firstWhere((entry) => entry.role == Role.assistant);

// ── Event builders ────────────────────────────────────────
//
// The runtime streams a growing assistant entry with stable entry/block
// ids; deltas sharing an id coalesce into one block in the mirror.

final asstEntryId = TranscriptEntryId.v7();
final textBlockId = TranscriptBlockId.v7();
final reasoningBlockId = TranscriptBlockId.v7();

/// The runtime announcing a turn over [transcript] — what it was handed to
/// run, which it mirrors back verbatim.
AgentStarted started({
  AgentHandle agent = agentHandle,
  Transcript? transcript,
}) => AgentStarted(
  timestamp: DateTime.utc(2025),
  agent: agent,
  transcript: transcript ?? emptyTranscript(),
);

AgentTextDelta text(String value, {AgentHandle agent = agentHandle}) =>
    AgentTextDelta(
      timestamp: DateTime.utc(2025),
      agent: agent,
      entryId: asstEntryId,
      blockId: textBlockId,
      text: value,
    );

AgentReasoningDelta reasoning(String value) => AgentReasoningDelta(
  timestamp: DateTime.utc(2025),
  agent: agentHandle,
  entryId: asstEntryId,
  blockId: reasoningBlockId,
  text: value,
);

AgentToolResponseApplied resultApplied(ToolCallResponse response) =>
    AgentToolResponseApplied(
      timestamp: DateTime.utc(2025),
      agent: agentHandle,
      entryId: TranscriptEntryId.v7(),
      blockId: TranscriptBlockId.v7(),
      response: response,
    );

AgentPrefillProgress prefill({required int completed, required int total}) =>
    AgentPrefillProgress(
      timestamp: DateTime.utc(2025),
      agent: agentHandle,
      completed: completed,
      total: total,
    );

AgentCompactionStarted compactionStarted({
  int tokensBefore = 1000,
  int compactAt = 800,
  int contextSize = 2048,
}) => AgentCompactionStarted(
  timestamp: DateTime.utc(2025),
  agent: agentHandle,
  tokensBefore: tokensBefore,
  compactAt: compactAt,
  contextSize: contextSize,
);

AgentCompactionSucceeded compaction(String summary) {
  return AgentCompactionSucceeded(summary: summary, tokensAfter: 1);
}

ModelSnapshot modelSnapshot({
  String modelId = 'model-a',
  int contextSize = 4096,
  ModelCardPhase phase = ModelCardPhase.loading,
}) => ModelSnapshot(
  modelId: modelId,
  displayName: 'Model A',
  contextSize: contextSize,
  provider: 'OpenRouter',
  phase: phase,
);

Future<void> pump([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// What the repository is started under in tests.
const double testCompactionRatio = 0.85;
const int testMaxToolCallCharacters = 4000;
const testAgentConfiguration = AgentConfiguration(
  compactionRatio: testCompactionRatio,
  maxToolCallCharacters: testMaxToolCallCharacters,
);
