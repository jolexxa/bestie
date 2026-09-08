import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/pool/remote_pool_snapshot.dart';
import 'package:agent_provider_remote/src/remote_agent.dart';
import 'package:agent_provider_remote/src/remote_provider_options.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_input.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_logic.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_output.dart';
import 'package:clock/clock.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// Hosts agents whose steps are chat completions against an
/// [InferenceClient].
final class RemoteAgentProvider implements AgentProvider, RemoteAgentHost {
  RemoteAgentProvider({
    required InferenceClient client,
    required RemoteProviderOptions options,
  }) : _client = client,
       _options = options;

  final InferenceClient _client;
  final RemoteProviderOptions _options;
  final Map<AgentHandle, _AgentRecord> _records = {};
  final _pool = StreamController<ContextPoolSnapshot>.broadcast();
  final _spend = StreamController<double>.broadcast();
  ContextPoolSnapshot? _lastSnapshot;
  var _nextAgentNumber = 1;
  var _disposed = false;

  int get contextWindow => _options.contextWindow;

  @override
  int get maxAgents => _options.maxAgents;

  @override
  Stream<ContextPoolSnapshot> get pool => _pool.stream;

  @override
  Stream<double> get spend => _spend.stream;

  AgentHandle? get _primary => _records.keys
      .where((handle) => handle.kind == AgentKind.primary)
      .firstOrNull;

  @override
  Future<StartPrimaryResult> startPrimary({required AgentConfig config}) async {
    final rejection = _startRejection(config, AgentKind.primary);
    if (rejection != null) {
      return StartPrimaryRejected(reason: rejection);
    }
    return StartPrimaryStarted(_register(AgentKind.primary, config, null));
  }

  @override
  Future<StartSubagentResult> startSubagent({
    required AgentConfig config,
    String? label,
  }) async {
    final rejection = _startRejection(config, AgentKind.subagent);
    if (rejection != null) {
      return StartSubagentRejected(reason: rejection);
    }
    return StartSubagentStarted(_register(AgentKind.subagent, config, label));
  }

  AgentRuntimeRejectionReason? _startRejection(
    AgentConfig config,
    AgentKind kind,
  ) {
    if (_disposed) return AgentRuntimeRejectionReason.disposed;
    if (!config.isValid) return AgentRuntimeRejectionReason.invalidConfig;
    final hasPrimary = _primary != null;
    if (kind == AgentKind.primary && hasPrimary) {
      return AgentRuntimeRejectionReason.primaryAgentAlreadyCreated;
    }
    if (kind == AgentKind.subagent && !hasPrimary) {
      return AgentRuntimeRejectionReason.primaryAgentRequired;
    }
    if (_records.length >= maxAgents) {
      return AgentRuntimeRejectionReason.agentCapacityReached;
    }
    return null;
  }

  RemoteAgent _register(AgentKind kind, AgentConfig config, String? label) {
    final handle = AgentHandle(
      id: '${kind.name}:${_nextAgentNumber++}',
      kind: kind,
      label: label,
    );
    final record = _AgentRecord(handle: handle, config: config);
    _records[handle] = record;
    _emitPool();
    return RemoteAgent(
      handle: handle,
      events: record.events.stream,
      host: this,
    );
  }

  @override
  Future<DisposeAgentResult> disposeAgent(Agent agent) async {
    if (_disposed) {
      return const DisposeAgentRejected(
        reason: AgentRuntimeRejectionReason.disposed,
      );
    }
    final record = _records[agent.handle];
    if (record == null) {
      return const DisposeAgentRejected(
        reason: AgentRuntimeRejectionReason.unknownAgent,
      );
    }
    if (record.isRunning) {
      return const DisposeAgentRejected(
        reason: AgentRuntimeRejectionReason.busy,
      );
    }
    _records.remove(agent.handle);
    await _closeRecord(record);
    _emitPool();
    return const DisposeAgentDisposed();
  }

  @override
  Future<DisposeProviderResult> dispose() async {
    if (_disposed) return const DisposeProviderSucceeded();
    _disposed = true;
    final records = _records.values.toList();
    _records.clear();
    for (final record in records) {
      if (record.isRunning) _cancelTurn(record);
      await _closeRecord(record);
    }
    await _pool.close();
    await _spend.close();
    await _client.close();
    return const DisposeProviderSucceeded();
  }

  @override
  Future<RunResult> run(
    AgentHandle handle,
    Transcript transcript,
    AgentConfig? config,
    TurnGoal goal,
  ) async {
    if (_disposed) {
      return const RunRejected(reason: AgentRuntimeRejectionReason.disposed);
    }
    final record = _records[handle];
    if (record == null) {
      return const RunRejected(
        reason: AgentRuntimeRejectionReason.unknownAgent,
      );
    }
    if (record.isRunning) {
      return const RunRejected(reason: AgentRuntimeRejectionReason.busy);
    }
    if (config != null) {
      if (!config.isValid) {
        return const RunRejected(
          reason: AgentRuntimeRejectionReason.invalidConfig,
        );
      }
      record.config = config;
    }
    if (goal == TurnGoal.compact && !transcript.hasFoldableEntries) {
      return const RunRejected(
        reason: AgentRuntimeRejectionReason.nothingToCompact,
      );
    }
    _startTurn(record, transcript, goal);
    return const RunAccepted();
  }

  @override
  Future<SubmitToolResultsResult> submitToolResults(
    AgentHandle handle,
    List<ToolCallResponse> responses,
  ) async {
    final rejection = _submitRejection<WaitingForToolResultsState>(handle);
    if (rejection != null) {
      return SubmitToolResultsRejected(reason: rejection);
    }
    final record = _records[handle]!;
    final entries = <TranscriptEntry>[];
    for (final response in responses) {
      final entryId = TranscriptEntryId.v7();
      final blockId = TranscriptBlockId.v7();
      record.events.add(
        AgentToolResponseApplied(
          timestamp: clock.now(),
          agent: handle,
          entryId: entryId,
          blockId: blockId,
          response: response,
        ),
      );
      entries.add(
        TranscriptEntry(
          id: entryId,
          role: Role.tool,
          name: response.toolName,
          blocks: [
            TranscriptToolCallResponseBlock(id: blockId, response: response),
          ],
        ),
      );
    }
    record.turn!.logic.input(ToolResultsSubmitted(entries: entries));
    return const SubmitToolResultsAccepted();
  }

  @override
  Future<SubmitCompactionPromptResult> submitCompactionPrompt(
    AgentHandle handle,
    CompactionPromptContent content,
  ) async {
    final rejection = _submitRejection<AwaitingCompactionPromptState>(handle);
    if (rejection != null) {
      return SubmitCompactionPromptRejected(reason: rejection);
    }
    _records[handle]!.turn!.logic.input(
      CompactionPromptSubmitted(content: content),
    );
    return const SubmitCompactionPromptAccepted();
  }

  @override
  Future<CancelResult> cancel(AgentHandle handle) async {
    if (_disposed) {
      return const CancelRejected(reason: AgentRuntimeRejectionReason.disposed);
    }
    final record = _records[handle];
    if (record == null) {
      return const CancelRejected(
        reason: AgentRuntimeRejectionReason.unknownAgent,
      );
    }
    if (!record.isRunning) {
      return const CancelRejected(
        reason: AgentRuntimeRejectionReason.agentNotRunning,
      );
    }
    _cancelTurn(record);
    return const CancelAccepted();
  }

  AgentRuntimeRejectionReason?
  _submitRejection<TExpected extends RemoteTurnState>(
    AgentHandle handle,
  ) {
    if (_disposed) return AgentRuntimeRejectionReason.disposed;
    final record = _records[handle];
    if (record == null) return AgentRuntimeRejectionReason.unknownAgent;
    if (!record.isRunning) return AgentRuntimeRejectionReason.agentNotRunning;
    if (record.turn!.logic.value is! TExpected) {
      return AgentRuntimeRejectionReason.busy;
    }
    return null;
  }

  void _startTurn(
    _AgentRecord record,
    Transcript transcript,
    TurnGoal goal,
  ) {
    final logic = RemoteTurnLogic(
      data: RemoteTurnData(
        handle: record.handle,
        config: record.config,
        goal: goal,
        transcript: transcript,
        modelId: _options.modelId,
        contextWindow: _options.contextWindow,
        maxOutputTokens: _options.maxOutputTokens,
        summaryMaxOutputTokens: _options.summaryMaxOutputTokens,
        usage: record.usage,
      ),
    );
    final turn = _Turn(logic: logic, binding: logic.bind());
    record.turn = turn;
    turn.binding
      ..onOutput<AgentRuntimeEvent>(record.events.add)
      ..onOutput<CompletionRequested>((work) => _startStream(turn, work))
      ..onOutput<UsageChanged>((work) {
        record.usage = work.usage;
        _emitPool();
      })
      ..onOutput<SpendReported>((work) => _spend.add(work.cost))
      ..onState<TerminalState>((_) => _scheduleTeardown(record, turn));
    logic
      ..start()
      ..input(const StepRequested());
  }

  void _startStream(_Turn turn, CompletionRequested work) {
    final abort = Completer<void>();
    turn
      ..abort = abort
      ..subscription = _client
          .complete(work.request, abortTrigger: abort.future)
          .listen(
            (event) => turn.logic.input(
              InferenceEventReceived(
                completionId: work.completionId,
                event: event,
              ),
            ),
            onError: (Object error) => turn.logic.input(
              CompletionStreamErrored(
                completionId: work.completionId,
                error: error,
              ),
            ),
            onDone: () => turn.logic.input(
              CompletionStreamEnded(completionId: work.completionId),
            ),
          );
  }

  void _cancelTurn(_AgentRecord record) {
    record.turn!
      ..abortStream()
      ..logic.input(const CancelRequested());
  }

  /// A terminal state is announced while the logic block is still
  /// processing the input that reached it, and `stop()` is a no-op then, so
  /// teardown waits for the current input to finish.
  void _scheduleTeardown(_AgentRecord record, _Turn turn) {
    scheduleMicrotask(() {
      turn.dispose();
      if (identical(record.turn, turn)) record.turn = null;
    });
  }

  Future<void> _closeRecord(_AgentRecord record) async {
    record.turn?.dispose();
    record.turn = null;
    record.events.add(AgentEnded(timestamp: clock.now(), agent: record.handle));
    await record.events.close();
  }

  void _emitPool() {
    final snapshot = synthesizePoolSnapshot(
      contextWindow: contextWindow,
      usageByAgent: {
        for (final record in _records.values) record.handle: record.usage,
      },
    );
    if (snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;
    _pool.add(snapshot);
  }
}

final class _AgentRecord {
  _AgentRecord({required this.handle, required this.config});

  final AgentHandle handle;
  final StreamController<AgentRuntimeEvent> events =
      StreamController.broadcast();
  AgentConfig config;
  RemoteUsage? usage;
  _Turn? turn;

  bool get isRunning {
    final current = turn;
    return current != null && current.logic.value is! TerminalState;
  }
}

final class _Turn {
  _Turn({required this.logic, required this.binding});

  final RemoteTurnLogic logic;
  final LogicBlockBinding<RemoteTurnState> binding;
  StreamSubscription<InferenceEvent>? subscription;
  Completer<void>? abort;
  var _disposed = false;

  void abortStream() {
    final pending = abort;
    if (pending != null && !pending.isCompleted) pending.complete();
    unawaited(subscription?.cancel());
    subscription = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    abortStream();
    binding.dispose();
    logic
      ..stop()
      ..dispose();
  }
}
