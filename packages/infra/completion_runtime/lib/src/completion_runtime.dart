import 'dart:async';
import 'dart:math' as math;

import 'package:completion_runtime/src/agent_sequence_session.dart';
import 'package:completion_runtime/src/completion_turn.dart';
import 'package:completion_runtime/src/models/agent_lease_models.dart';
import 'package:completion_runtime/src/models/completion_models.dart';
import 'package:completion_runtime/src/stop_matcher.dart';
import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Runs chat completions for leased agents on one loaded model.
abstract interface class CompletionRuntime {
  int get contextSize;

  int get maxAgents;

  /// Leases a sequence for the primary agent [agentId]. Opening an agent
  /// that already holds a lease answers with its existing lease.
  Future<AgentOpenOutcome> openPrimary(String agentId);

  /// Leases a sequence for the subagent [agentId], claiming an equal share
  /// of the context. Opening an agent that already holds a lease answers
  /// with its existing lease.
  Future<AgentOpenOutcome> openSubagent(String agentId);

  /// Gives [agentId]'s sequence back, cancelling its running completion.
  Future<AgentCloseOutcome> close(String agentId);

  /// Closes every agent's lease, subagents first.
  Future<void> closeAll();

  Future<CompletionStart> complete(CompletionRequest request);

  /// The pool now, or for a runtime running elsewhere, as of the last
  /// change it reported.
  PoolSnapshot get pool;

  /// A snapshot whenever a lease opens or closes, or a completion settles.
  Stream<PoolSnapshot> get poolChanges;

  /// Cancels every completion and releases every lease. The runtime refuses
  /// everything afterwards.
  Future<void> dispose();
}

/// A [CompletionRuntime] that batches every running completion into one
/// scheduler step per pump, yielding to the event loop between pumps.
final class ScheduledCompletionRuntime implements CompletionRuntime {
  ScheduledCompletionRuntime({
    required Allocator allocator,
    required SequenceScheduler scheduler,
    required Detokenizer tokenizer,
    required ModelProfile profile,
    required EngineSampling defaultSampling,
    CallIdMinter? callIdMinter,
  }) : _allocator = allocator,
       _scheduler = scheduler,
       _tokenizer = tokenizer,
       _profile = profile,
       _defaultSampling = defaultSampling,
       _callIdMinter = callIdMinter ?? CallIdMinter();

  final Allocator _allocator;
  final SequenceScheduler _scheduler;
  final Detokenizer _tokenizer;
  final ModelProfile _profile;
  final EngineSampling _defaultSampling;
  final CallIdMinter _callIdMinter;
  final _sessions = <String, AgentSequenceSession>{};
  final _turns = <CompletionTurn>[];
  final _borrowed = <AgentSequenceSession>{};
  final _poolChanges = StreamController<PoolSnapshot>.broadcast();
  Future<void>? _driving;
  var _disposed = false;

  @override
  int get contextSize => _allocator.contextSize;

  @override
  int get maxAgents => _allocator.maxSequences;

  /// Each subagent's equal share of the whole context.
  int get _claimSize => math.max(1, contextSize ~/ maxAgents);

  @override
  Stream<PoolSnapshot> get poolChanges => _poolChanges.stream;

  @override
  PoolSnapshot get pool => PoolSnapshot(
    contextSize: contextSize,
    maxAgents: maxAgents,
    agents: [
      for (final session in _sessions.values)
        session.poolLease(
          usedTokens: _scheduler.cachedTokenCountFor(session.lease) ?? 0,
        ),
    ],
    borrowedTokens: _borrowed.fold(
      0,
      (total, session) => total + session.claimedTokens,
    ),
  );

  @override
  Future<AgentOpenOutcome> openPrimary(String agentId) async =>
      _existing(agentId) ??
      switch (_allocator.reservePrimary(sampling: _defaultSampling)) {
        ReservePrimarySucceeded(:final lease) => _admit(agentId, lease),
        ReserveLeaseFailed(:final reason) => reason.toOpenOutcome(),
      };

  @override
  Future<AgentOpenOutcome> openSubagent(String agentId) async =>
      _existing(agentId) ??
      switch (_allocator.reserveSubagent(
        contextSize: _claimSize,
        sampling: _defaultSampling,
      )) {
        ReserveSubagentSucceeded(:final lease) => _admit(agentId, lease),
        ReserveLeaseFailed(:final reason) => reason.toOpenOutcome(),
      };

  /// The answer for an agent that needs no new lease, or null to lease one.
  AgentOpenOutcome? _existing(String agentId) {
    if (_disposed) {
      return const AgentLeaseFailed(message: 'The runtime is shut down.');
    }
    final existing = _sessions[agentId];
    return existing == null
        ? null
        : AgentLeaseOpened(claimedTokens: existing.claimedTokens);
  }

  AgentOpenOutcome _admit(String agentId, Lease lease) {
    final session = AgentSequenceSession(
      id: agentId,
      lease: lease,
      sampling: _defaultSampling,
    );
    _sessions[agentId] = session;
    _publishPool();
    return AgentLeaseOpened(claimedTokens: session.claimedTokens);
  }

  @override
  Future<AgentCloseOutcome> close(String agentId) async {
    final session = _sessions.remove(agentId);
    if (session == null) return const AgentLeaseUnknown();
    _release(session);
    _publishPool();
    return const AgentLeaseClosed();
  }

  @override
  Future<void> closeAll() async {
    final ordered = [
      ..._sessions.values.where((session) => session.isSubagent),
      ..._sessions.values.where((session) => !session.isSubagent),
    ];
    _sessions.clear();
    ordered.forEach(_release);
    _publishPool();
  }

  void _release(AgentSequenceSession session) {
    session.turn?.fail(
      CompletionFailure.cancelled,
      'The agent lease was closed.',
    );
    session.turn = null;
    _scheduler.release(session.lease);
  }

  @override
  Future<CompletionStart> complete(CompletionRequest request) async {
    if (_disposed) {
      return const CompletionRejected(
        reason: CompletionRejection.disposed,
        message: 'The runtime is shut down.',
      );
    }
    final agentId = request.agentId;
    final session = agentId == null ? null : _sessions[agentId];
    if (agentId != null && session == null) {
      return CompletionRejected(
        reason: CompletionRejection.unknownAgent,
        message: 'No lease is open for agent $agentId.',
      );
    }
    if (session?.turn != null) {
      return CompletionRejected(
        reason: CompletionRejection.agentBusy,
        message: 'Agent $agentId is already running a completion.',
      );
    }

    final formatter = _profile.formatter;
    final tokenized = _tokenizer.tokenize(
      TokenizeRequest(
        text: formatter.format(
          messages: request.messages,
          tools: request.tools,
          reasoningMode: request.reasoningMode,
        ),
        addSpecial: formatter.addBos,
      ),
    );
    final TokenizedString prompt;
    switch (tokenized) {
      case TokenizeSucceeded(:final tokens):
        prompt = tokens;
      case TokenizeFailed(:final message):
        return CompletionRejected(
          reason: CompletionRejection.promptUnreadable,
          message: message,
        );
    }

    final limit = session == null
        ? _claimSize
        : _scheduler.effectiveLimitFor(session.lease);
    if (prompt.length >= limit) {
      return CompletionRejected(
        reason: CompletionRejection.promptTooLarge,
        message:
            'The prompt is ${prompt.length} tokens; the agent can hold '
            '$limit.',
      );
    }

    final runner = session ?? _borrow(request.sampling);
    if (runner == null) {
      return const CompletionRejected(
        reason: CompletionRejection.noCapacity,
        message: 'No sequence is free to lend.',
      );
    }
    if (_applySampling(runner, request.sampling)
        case final SequenceSetSamplingFailed failed) {
      return CompletionRejected(
        reason: CompletionRejection.engineFailed,
        message: 'The sampler could not be rebuilt: ${failed.reason.name}.',
      );
    }

    final turn = CompletionTurn(
      session: runner,
      prompt: prompt,
      parser: _profile.streamParser.start(
        knownToolNames: {for (final tool in request.tools) tool.name},
        reasoningPrefilled: formatter.prefillsReasoning(request.reasoningMode),
      ),
      detokenizer: _tokenizer,
      callIdMinter: _callIdMinter,
      stops: StopMatcher([
        ...request.stopSequences,
        ...formatter.stopSequences,
      ]),
      maxTokens: request.maxTokens,
    );
    runner.turn = turn;
    _turns.add(turn);
    _wake();
    return CompletionStarted(turn.events);
  }

  AgentSequenceSession? _borrow(EngineSampling sampling) {
    final reserved = _allocator.reserveSubagent(
      contextSize: _claimSize,
      sampling: sampling,
    );
    if (reserved is! ReserveSubagentSucceeded) return null;
    final session = AgentSequenceSession(
      id: 'borrowed:${reserved.lease.sequence.id}',
      lease: reserved.lease,
      sampling: sampling,
    );
    _borrowed.add(session);
    _publishPool();
    return session;
  }

  /// Rebuilds [session]'s sampler for [sampling] when it differs from the
  /// last turn's, recording it only once the backend took it.
  SequenceSetSamplingResult _applySampling(
    AgentSequenceSession session,
    EngineSampling sampling,
  ) {
    if (session.sampling == sampling) {
      return const SequenceSetSamplingSucceeded();
    }
    final result = _scheduler.setSampling(session.lease, sampling);
    if (result is SequenceSetSamplingSucceeded) session.sampling = sampling;
    return result;
  }

  void _wake() {
    _driving ??= _drive();
  }

  Future<void> _drive() async {
    while (_turns.isNotEmpty) {
      _pump();
      // A timer, not a microtask, so request handlers and client disconnects
      // get the event loop between steps.
      await Future<void>.delayed(Duration.zero);
    }
    _driving = null;
  }

  void _pump() {
    try {
      _step();
    } on Object catch (error) {
      for (final turn in _turns) {
        turn.fail(CompletionFailure.engineFailed, '$error');
      }
    }
    _sweepSettled();
  }

  void _step() {
    _sweepSettled();
    if (_turns.isEmpty) return;
    final materializing = _turns.inPhase(CompletionTurnPhase.materializing);
    final decoding = _turns.inPhase(CompletionTurnPhase.decoding);
    final results = _scheduler.stepBatch(
      samples: [for (final turn in decoding) turn.sampleRequest],
      materializes: [for (final turn in materializing) turn.materializeRequest],
    );
    for (final turn in materializing) {
      turn.acceptMaterialize(
        results.materializes[turn.session.lease] ?? _missingMaterialize,
      );
    }
    for (final turn in decoding) {
      turn.acceptSample(results.samples[turn.session.lease] ?? _missingSample);
    }
  }

  void _sweepSettled() {
    final settled = _turns.inPhase(CompletionTurnPhase.settled);
    if (settled.isEmpty) return;
    for (final turn in settled) {
      _turns.remove(turn);
      _settle(turn.session);
    }
    _publishPool();
  }

  void _settle(AgentSequenceSession session) {
    session.turn = null;
    if (_borrowed.remove(session)) _scheduler.release(session.lease);
  }

  void _publishPool() {
    if (_poolChanges.isClosed) return;
    _poolChanges.add(pool);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await closeAll();
    for (final session in _borrowed) {
      session.turn?.fail(CompletionFailure.cancelled, 'The runtime shut down.');
    }
    await _driving;
    await _poolChanges.close();
  }
}

const _missingMaterialize = SequenceMaterializeFailed(
  reason: SequenceSchedulerFailureReason.missingBatchResult,
);

const _missingSample = SequenceSampleFailed(
  reason: SequenceSchedulerFailureReason.missingBatchResult,
);

extension on List<CompletionTurn> {
  List<CompletionTurn> inPhase(CompletionTurnPhase phase) => [
    for (final turn in this)
      if (turn.phase == phase) turn,
  ];
}

extension on ReserveLeaseFailureReason {
  AgentOpenOutcome toOpenOutcome() => switch (this) {
    ReserveLeaseFailureReason.primaryAlreadyReserved ||
    ReserveLeaseFailureReason.noSequenceCapacity =>
      const AgentLeaseNoCapacity(),
    ReserveLeaseFailureReason.invalidClaimSize ||
    ReserveLeaseFailureReason.insufficientClaimSpace =>
      const AgentLeaseInsufficientClaim(),
    ReserveLeaseFailureReason.schedulerFailure => AgentLeaseFailed(
      message: name,
    ),
  };
}
