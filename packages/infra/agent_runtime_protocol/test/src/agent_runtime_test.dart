import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('AgentRuntime hands back an Agent with its own event stream', () async {
    final runtime = _FakeAgentRuntime();

    final started = await runtime.startPrimary(config: _config);
    expect(started, isA<StartPrimaryStarted>());
    final agent = (started as StartPrimaryStarted).agent;
    expect(agent.events, isA<Stream<AgentRuntimeEvent>>());
    expect(agent.kind, AgentKind.primary);

    expect(await agent.run(_transcript), isA<RunAccepted>());
    expect(await agent.cancel(), isA<CancelAccepted>());
    expect(await runtime.disposeAgent(agent), isA<DisposeAgentDisposed>());
    expect(await runtime.dispose(), isA<DisposeRuntimeSucceeded>());
  });

  test('public API supports command inputs and lifecycle outputs', () {
    const agent = AgentHandle(
      id: 'primary:1',
      kind: AgentKind.primary,
      label: 'main',
    );
    final timestamp = DateTime.utc(2025);
    final events = <AgentRuntimeEvent>[
      AgentStarted(timestamp: timestamp, agent: agent, transcript: _transcript),
      AgentStepStarted(
        timestamp: timestamp,
        agent: agent,
        entryId: TranscriptEntryId.v7(),
      ),
      AgentTextDelta(
        timestamp: timestamp,
        agent: agent,
        entryId: TranscriptEntryId.v7(),
        blockId: TranscriptBlockId.v7(),
        text: 'hi',
      ),
      AgentCompleted(
        timestamp: timestamp,
        agent: agent,
        transcript: _transcript,
        report: 'done',
      ),
      AgentNeedsCompactionPrompt(timestamp: timestamp, agent: agent),
    ];

    expect(_config.isValid, isTrue);
    expect(_transcript.entries.single.role, Role.user);
    expect(events, hasLength(5));
    expect(events.every((event) => event.agent == agent), isTrue);
    expect(
      const SubmitCompactionPromptRejected(
        reason: AgentRuntimeRejectionReason.unknownAgent,
      ).reason,
      AgentRuntimeRejectionReason.unknownAgent,
    );
    expect(
      const StartPrimaryRejected(
        reason: AgentRuntimeRejectionReason.primaryAgentAlreadyCreated,
      ).reason,
      AgentRuntimeRejectionReason.primaryAgentAlreadyCreated,
    );
  });
}

const _config = AgentConfig(
  systemPrompt: 'system',
  sampling: SamplingOptions(seed: 1),
  reasoningMode: 'reasoning',
  compactionReasoningMode: 'summary',
  compactionRatio: 0.85,
  tools: [
    ToolDefinition(
      onProgress: 'Running',
      onSuccess: 'Ran',
      onError: 'Failed',
      name: 'lookup',
      description: 'Looks something up.',
      parameters: {'type': 'object'},
    ),
  ],
);

final _transcript = Transcript(
  id: TranscriptId.v7(),
  revision: 1,
  entries: [
    TranscriptEntry(
      id: TranscriptEntryId.v7(),
      role: Role.user,
      blocks: [
        TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: 'hello'),
      ],
    ),
  ],
);

final class _FakeAgentRuntime implements AgentRuntime {
  @override
  int get maxAgents => 1;

  @override
  Stream<ContextPoolSnapshot> get pool => const Stream.empty();

  @override
  Stream<double> get spend => const Stream.empty();

  @override
  Future<StartPrimaryResult> startPrimary({required AgentConfig config}) async {
    return StartPrimaryStarted(
      _FakeAgent(const AgentHandle(id: 'primary:1', kind: AgentKind.primary)),
    );
  }

  @override
  Future<StartSubagentResult> startSubagent({
    required AgentConfig config,
    String? label,
  }) async {
    return StartSubagentStarted(
      _FakeAgent(
        AgentHandle(id: 'subagent:1', kind: AgentKind.subagent, label: label),
      ),
    );
  }

  @override
  Future<DisposeAgentResult> disposeAgent(Agent agent) async {
    return const DisposeAgentDisposed();
  }

  @override
  Future<DisposeRuntimeResult> dispose() async {
    return const DisposeRuntimeSucceeded();
  }
}

final class _FakeAgent implements Agent {
  _FakeAgent(this.handle);

  @override
  final AgentHandle handle;

  @override
  AgentKind get kind => handle.kind;

  @override
  String? get label => handle.label;

  @override
  Stream<AgentRuntimeEvent> get events => const Stream.empty();

  @override
  Future<RunResult> run(
    Transcript transcript, {
    AgentConfig? config,
    TurnGoal goal = TurnGoal.respond,
  }) async {
    return const RunAccepted();
  }

  @override
  Future<SubmitToolResultsResult> submitToolResults(
    List<ToolCallResponse> responses,
  ) async {
    return const SubmitToolResultsAccepted();
  }

  @override
  Future<SubmitCompactionPromptResult> submitCompactionPrompt(
    CompactionPromptContent content,
  ) async {
    return const SubmitCompactionPromptAccepted();
  }

  @override
  Future<CancelResult> cancel() async => const CancelAccepted();
}
