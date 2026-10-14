import 'package:agent_runtime/src/mapping/completion_request_builder.dart';
import 'package:agent_runtime/src/mapping/tool_mapper.dart';
import 'package:agent_runtime/src/turn/agent_turn_data.dart';
import 'package:agent_runtime/src/turn/agent_turn_input.dart';
import 'package:agent_runtime/src/turn/agent_turn_output.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:clock/clock.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// One agent turn against a completion endpoint: stream a step, pause for tool
/// results or a compaction prompt, repeat until the model stops calling
/// tools.
final class AgentTurnLogic extends LogicBlock<AgentTurnState> {
  AgentTurnLogic({required AgentTurnData data}) {
    set(data);
    set(PreparingStepState());
    set(StreamingState());
    set(WaitingForToolResultsState());
    set(AwaitingCompactionPromptState());
    set(SummarizingState());
    set(CompletedState());
    set(CancelledState());
    set(FailedState());
  }

  @override
  Transition getInitialState() => to<PreparingStepState>();
}

sealed class AgentTurnState extends StateLogic<AgentTurnState> {
  AgentTurnData get data => get<AgentTurnData>();

  DateTime get stamp => clock.now();
}

/// A turn that can still be cancelled.
sealed class ActiveState extends AgentTurnState {
  ActiveState() {
    on<CancelRequested>(_cancel);
  }

  static const _requestBuilder = CompletionRequestBuilder();

  Transition _cancel(CancelRequested _) {
    final step = data.step;
    if (step != null && step.hasContent) data.append([step.toEntry()]);
    data
      ..step = null
      ..compaction = null;
    output(
      AgentCancelled(
        timestamp: stamp,
        agent: data.handle,
        transcript: data.transcript,
      ),
    );
    return to<CancelledState>();
  }

  Transition fail(AgentRunFailureReason reason, String message) {
    output(
      AgentFailed(
        timestamp: stamp,
        agent: data.handle,
        reason: reason,
        message: message,
      ),
    );
    return to<FailedState>();
  }

  /// The single gate every step passes through: fold first when the last
  /// completion reported the context is full, else stream the next step.
  Transition startStep() {
    if (data.needsCompaction) return to<AwaitingCompactionPromptState>();
    final frame = StepFrame(entryId: TranscriptEntryId.v7());
    data.step = frame;
    output(
      AgentStepStarted(
        timestamp: stamp,
        agent: data.handle,
        entryId: frame.entryId,
      ),
    );
    return to<StreamingState>();
  }

  Transition complete() {
    output(
      AgentCompleted(
        timestamp: stamp,
        agent: data.handle,
        transcript: data.transcript,
        report: data.report,
      ),
    );
    return to<CompletedState>();
  }

  void requestCompletion(CompletionRequest request) {
    output(
      CompletionRequested(
        completionId: ++data.completionId,
        request: request,
      ),
    );
  }

  CompletionRequest stepRequest() => _requestBuilder.step(data);

  CompletionRequest summaryRequest() => _requestBuilder.summary(data);
}

/// A state fed by a completion stream; events from an earlier stream are
/// ignored.
sealed class ReceivingState extends ActiveState {
  ReceivingState() {
    on<CompletionEventReceived>(
      (input) => input.completionId == data.completionId
          ? onEvent(input.event)
          : toSelf(),
    );
    on<CompletionStreamEnded>(
      (input) =>
          input.completionId == data.completionId ? onStreamEnded() : toSelf(),
    );
    on<CompletionStreamErrored>(
      (input) => input.completionId == data.completionId
          ? onStreamErrored(input.error)
          : toSelf(),
    );
  }

  Transition onEvent(CompletionEvent event);

  Transition onStreamEnded();

  Transition reportPrefill(CompletionPrefillProgressed event) {
    output(
      AgentPrefillProgress(
        timestamp: stamp,
        agent: data.handle,
        completed: event.processed,
        total: event.total,
      ),
    );
    return toSelf();
  }

  Transition onStreamErrored(Object error);

  Transition recordUsage(CompletionUsageReported event) {
    final usage = AgentUsage(
      promptTokens: event.promptTokens,
      completionTokens: event.completionTokens,
    );
    data
      ..usage = usage
      ..generatedTokensTotal += event.completionTokens;
    output(
      AgentTelemetryUpdated(
        timestamp: stamp,
        agent: data.handle,
        telemetry: data.telemetry(),
      ),
    );
    output(UsageChanged(usage));
    reportSpend(event);
    return toSelf();
  }

  void reportSpend(CompletionUsageReported event) {
    if (event.cost case final cost?) output(SpendReported(cost));
  }
}

final class PreparingStepState extends ActiveState {
  PreparingStepState() {
    on<StepRequested>((_) {
      output(
        AgentStarted(
          timestamp: stamp,
          agent: data.handle,
          transcript: data.transcript,
        ),
      );
      return switch (data.goal) {
        TurnGoal.respond => startStep(),
        TurnGoal.compact => to<AwaitingCompactionPromptState>(),
      };
    });
  }
}

final class StreamingState extends ReceivingState {
  StreamingState() {
    onEnter(() => requestCompletion(stepRequest()));
  }

  StepFrame get step => data.step!;

  @override
  Transition onEvent(CompletionEvent event) => switch (event) {
    CompletionPrefillProgressed() => reportPrefill(event),
    CompletionTextDelta(:final text, :final tokens) => _appendText(
      text,
      reasoning: false,
      tokens: tokens,
    ),
    CompletionReasoningDelta(:final text, :final tokens) => _appendText(
      text,
      reasoning: true,
      tokens: tokens,
    ),
    CompletionToolCallStarted(:final name) => _startToolCall(name),
    CompletionToolCallEmitted(:final call, :final tokens) => _addToolCall(
      call,
      tokens: tokens,
    ),
    CompletionUsageReported() => _recordStepUsage(event),
    CompletionFinished(:final reason) => _recordStop(reason),
    CompletionFailed(:final failure) => fail(
      AgentRunFailureReason.loopFailed,
      '${failure.kind.name}: ${failure.message}',
    ),
  };

  Transition _startToolCall(String name) {
    output(
      AgentToolCallStarted(timestamp: stamp, agent: data.handle, name: name),
    );
    return toSelf();
  }

  Transition _appendText(
    String text, {
    required bool reasoning,
    required int? tokens,
  }) {
    if (text.isEmpty) return toSelf();
    final at = stamp;
    final blockId = step.appendText(
      text,
      reasoning: reasoning,
      at: at,
      tokens: tokens,
    );
    output(
      reasoning
          ? AgentReasoningDelta(
              timestamp: at,
              agent: data.handle,
              entryId: step.entryId,
              blockId: blockId,
              text: text,
            )
          : AgentTextDelta(
              timestamp: at,
              agent: data.handle,
              entryId: step.entryId,
              blockId: blockId,
              text: text,
            ),
    );
    return toSelf();
  }

  Transition _addToolCall(CompletionToolCall call, {required int? tokens}) {
    final at = stamp;
    final toolCall = toToolCall(call, mint: data.callIdMinter.mint);
    final blockId = step.addToolCall(toolCall, at: at, tokens: tokens);
    output(
      AgentToolCallEmitted(
        timestamp: at,
        agent: data.handle,
        entryId: step.entryId,
        blockId: blockId,
        toolCall: toolCall,
      ),
    );
    return toSelf();
  }

  Transition _recordStepUsage(CompletionUsageReported event) {
    step.shareTokens(
      event.completionTokens,
      reasoningTokens: event.reasoningTokens,
    );
    return recordUsage(event);
  }

  Transition _recordStop(CompletionStopReason reason) {
    step.stop = reason;
    return toSelf();
  }

  @override
  Transition onStreamEnded() {
    final frame = step;
    if (frame.stop == null) {
      return fail(
        AgentRunFailureReason.loopFailed,
        'stream ended without a completion',
      );
    }
    final entry = frame.toEntry();
    data
      ..append([entry])
      ..step = null;
    if (frame.toolCalls.isNotEmpty) {
      output(
        AgentNeedsToolResults(
          timestamp: stamp,
          agent: data.handle,
          entry: entry,
          toolCalls: frame.toolCalls,
        ),
      );
      return to<WaitingForToolResultsState>();
    }
    data.report = frame.report;
    return complete();
  }

  @override
  Transition onStreamErrored(Object error) =>
      fail(AgentRunFailureReason.loopFailed, error.toString());
}

final class WaitingForToolResultsState extends ActiveState {
  WaitingForToolResultsState() {
    on<ToolResultsSubmitted>((input) {
      data.append(input.entries);
      output(
        AgentUpdated(
          timestamp: stamp,
          agent: data.handle,
          transcript: data.transcript,
        ),
      );
      return startStep();
    });
  }
}

final class AwaitingCompactionPromptState extends ActiveState {
  AwaitingCompactionPromptState() {
    onEnter(() {
      final tokensBefore = data.usage?.total ?? 0;
      data.compaction = CompactionFrame(
        tokensBefore: tokensBefore,
        priorSummary: data.transcript.priorSummary,
      );
      output(
        AgentCompactionStarted(
          timestamp: stamp,
          agent: data.handle,
          tokensBefore: tokensBefore,
          compactAt: data.compactAt,
          contextSize: data.contextWindow,
        ),
      );
      output(AgentNeedsCompactionPrompt(timestamp: stamp, agent: data.handle));
    });
    on<CompactionPromptSubmitted>((input) {
      final frame = data.compaction!..content = input.content;
      final prefill = input.content.prefill;
      if (prefill.isNotEmpty) {
        frame.summary.write(prefill);
        output(
          AgentSummaryDelta(
            timestamp: stamp,
            agent: data.handle,
            text: prefill,
          ),
        );
      }
      return to<SummarizingState>();
    });
  }
}

final class SummarizingState extends ReceivingState {
  SummarizingState() {
    onEnter(() => requestCompletion(summaryRequest()));
  }

  static const _noSummary = '[no summary produced]';

  CompactionFrame get frame => data.compaction!;

  @override
  Transition onEvent(CompletionEvent event) => switch (event) {
    CompletionPrefillProgressed() => reportPrefill(event),
    CompletionTextDelta(:final text) => _summaryDelta(text),
    CompletionReasoningDelta(:final text) => _summaryReasoningDelta(text),
    CompletionToolCallStarted() || CompletionToolCallEmitted() => toSelf(),
    CompletionUsageReported() => _recordSummaryUsage(event),
    CompletionFinished() => _recordFinished(),
    CompletionFailed(:final failure) => failCompaction(
      '${failure.kind.name}: ${failure.message}',
    ),
  };

  Transition _summaryDelta(String text) {
    if (text.isEmpty) return toSelf();
    frame.summary.write(text);
    output(AgentSummaryDelta(timestamp: stamp, agent: data.handle, text: text));
    return toSelf();
  }

  Transition _summaryReasoningDelta(String text) {
    if (text.isEmpty) return toSelf();
    output(
      AgentSummaryReasoningDelta(
        timestamp: stamp,
        agent: data.handle,
        text: text,
      ),
    );
    return toSelf();
  }

  Transition _recordSummaryUsage(CompletionUsageReported event) {
    frame.summaryUsage = AgentUsage(
      promptTokens: event.promptTokens,
      completionTokens: event.completionTokens,
    );
    reportSpend(event);
    return toSelf();
  }

  Transition _recordFinished() {
    frame.finished = true;
    return toSelf();
  }

  @override
  Transition onStreamEnded() {
    if (!frame.finished) {
      return failCompaction('summary stream ended without a completion');
    }
    return _fold();
  }

  @override
  Transition onStreamErrored(Object error) => failCompaction(error.toString());

  Transition _fold() {
    final summary = _finalSummary();
    final at = stamp;
    final tokensAfter = frame.summaryUsage?.completionTokens ?? 0;
    final usage = AgentUsage(promptTokens: tokensAfter, completionTokens: 0);
    data
      ..append([
        TranscriptEntry(
          id: TranscriptEntryId.v7(),
          role: Role.system,
          blocks: [
            TranscriptSummaryBlock(
              id: TranscriptBlockId.v7(),
              text: summary,
              stat: BlockStat(startedAt: at, endedAt: at),
            ),
          ],
        ),
      ])
      ..usage = usage
      ..compaction = null;
    output(
      AgentCompactionCompleted(
        timestamp: at,
        agent: data.handle,
        outcome: AgentCompactionSucceeded(
          summary: summary,
          tokensAfter: tokensAfter,
        ),
      ),
    );
    output(UsageChanged(usage));
    output(
      AgentUpdated(
        timestamp: at,
        agent: data.handle,
        transcript: data.transcript,
      ),
    );
    return switch (data.goal) {
      TurnGoal.respond => startStep(),
      TurnGoal.compact => complete(),
    };
  }

  /// The prefill seeds the buffer, so a model that echoes it back is
  /// de-duplicated and one that produced nothing falls back to the prior
  /// summary.
  String _finalSummary() {
    final prefill = frame.content!.prefill;
    var continuation = frame.summary.toString().substring(prefill.length);
    final trimmedPrefill = prefill.trim();
    if (trimmedPrefill.isNotEmpty &&
        continuation.trimLeft().startsWith(trimmedPrefill)) {
      continuation = continuation.trimLeft().substring(trimmedPrefill.length);
    }
    final produced = '$prefill$continuation'.trim();
    if (produced.isEmpty || produced == trimmedPrefill) {
      return frame.priorSummary ?? _noSummary;
    }
    return produced;
  }

  Transition failCompaction(String message) {
    output(
      AgentCompactionCompleted(
        timestamp: stamp,
        agent: data.handle,
        outcome: AgentCompactionFailed(
          reason: 'sampleFailed',
          message: message,
        ),
      ),
    );
    data.compaction = null;
    return fail(AgentRunFailureReason.compactionFailed, message);
  }
}

/// The turn is over; nothing more can happen to it.
sealed class TerminalState extends AgentTurnState {}

final class CompletedState extends TerminalState {}

final class CancelledState extends TerminalState {}

final class FailedState extends TerminalState {}
