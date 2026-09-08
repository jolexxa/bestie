import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_input.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_logic.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_output.dart';
import 'package:clock/clock.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

final _fixedNow = DateTime.utc(2026, 3, 4, 5, 6);

const _usageEvent = InferenceUsageReported(
  promptTokens: 40,
  completionTokens: 20,
);

final class _Harness {
  _Harness({
    List<TranscriptEntry>? entries,
    AgentConfig? agentConfig,
    RemoteUsage? usage,
    int contextWindow = 100,
    TurnGoal goal = TurnGoal.respond,
  }) : data = RemoteTurnData(
         handle: primaryHandle,
         config: agentConfig ?? config(),
         goal: goal,
         transcript: transcriptOf(entries ?? [userEntry('hi')]),
         modelId: 'test/model',
         contextWindow: contextWindow,
         summaryMaxOutputTokens: 256,
         usage: usage,
       ) {
    logic = RemoteTurnLogic(data: data);
    logic.bind().onOutput<Object>(outputs.add);
    logic.start();
  }

  final RemoteTurnData data;
  late final RemoteTurnLogic logic;
  final List<Object> outputs = [];

  List<Object> drain() {
    final drained = List<Object>.of(outputs);
    outputs.clear();
    return drained;
  }

  void event(InferenceEvent event, {int? completionId}) => logic.input(
    InferenceEventReceived(
      completionId: completionId ?? data.completionId,
      event: event,
    ),
  );

  void streamEnded({int? completionId}) => logic.input(
    CompletionStreamEnded(completionId: completionId ?? data.completionId),
  );

  void streamErrored(Object error, {int? completionId}) => logic.input(
    CompletionStreamErrored(
      completionId: completionId ?? data.completionId,
      error: error,
    ),
  );

  /// Runs a whole step: request, text deltas, usage, finish, end.
  void streamText(String text, {InferenceUsageReported usage = _usageEvent}) {
    event(InferenceTextDelta(text));
    event(usage);
    event(const InferenceCompletionFinished(InferenceStopReason.stop));
    streamEnded();
  }
}

void main() {
  group('RemoteTurnLogic', () {
    test('reports what a step cost when the provider says', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..event(_usageEvent);
      final unpriced = harness.drain();
      harness.event(
        const InferenceUsageReported(
          promptTokens: 40,
          completionTokens: 20,
          cost: 0.03,
        ),
      );
      final priced = harness.drain();

      expect(unpriced.whereType<SpendReported>(), isEmpty);
      expect(priced.whereType<SpendReported>().single.cost, 0.03);
    });

    test('streams a plain text step to completion', () {
      withClock(Clock.fixed(_fixedNow), () {
        final harness = _Harness()..logic.input(const StepRequested());

        final started = harness.drain();
        expect(started, hasLength(3));
        expect(
          started[0],
          isA<AgentStarted>()
              .having((event) => event.agent, 'agent', primaryHandle)
              .having((event) => event.timestamp, 'timestamp', _fixedNow)
              .having(
                (event) => event.transcript.entries,
                'entries',
                hasLength(1),
              ),
        );
        final stepStarted = started[1] as AgentStepStarted;
        final requested = started[2] as CompletionRequested;
        expect(requested.completionId, 1);
        expect(requested.request.model, 'test/model');
        expect(requested.request.messages, hasLength(2));
        expect(harness.logic.value, isA<StreamingState>());

        harness
          ..event(const InferenceTextDelta('Hel'))
          ..event(const InferenceTextDelta(''))
          ..event(const InferenceTextDelta('lo'));
        final deltas = harness.drain();
        expect(deltas, hasLength(2));
        final first = deltas[0] as AgentTextDelta;
        final second = deltas[1] as AgentTextDelta;
        expect(first.entryId, stepStarted.entryId);
        expect(first.text, 'Hel');
        expect(second.blockId, first.blockId);
        expect(second.text, 'lo');

        harness.event(_usageEvent);
        final usage = harness.drain();
        expect(usage, hasLength(2));
        expect(
          usage[0],
          isA<AgentTelemetryUpdated>()
              .having(
                (event) => event.telemetry.compactAtLimit,
                'compactAt',
                50,
              )
              .having(
                (event) => event.telemetry.generatedTokens,
                'generated',
                20,
              ),
        );
        expect(
          usage[1],
          isA<UsageChanged>().having(
            (work) => work.usage,
            'usage',
            const RemoteUsage(promptTokens: 40, completionTokens: 20),
          ),
        );

        harness.event(
          const InferenceCompletionFinished(InferenceStopReason.stop),
        );
        expect(harness.drain(), isEmpty);
        expect(harness.logic.value, isA<StreamingState>());

        harness.streamEnded();
        final completed = harness.drain();
        expect(completed, hasLength(1));
        final done = completed.single as AgentCompleted;
        expect(done.report, 'Hello');
        expect(done.transcript.revision, 1);
        expect(done.transcript.entries, hasLength(2));
        final entry = done.transcript.entries.last;
        expect(entry.id, stepStarted.entryId);
        expect(entry.role, Role.assistant);
        final block = entry.blocks.single as TranscriptParagraphBlock;
        expect(block.id, first.blockId);
        expect(block.text, 'Hello');
        expect(block.stat!.startedAt, _fixedNow);
        expect(harness.logic.value, isA<CompletedState>());
        expect(harness.data.report, 'Hello');
      });
    });

    test('announces a tool call before it lands', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..event(const InferenceToolCallStarted(name: 'echo'))
        ..event(
          const InferenceToolCallEmitted(
            InferenceToolCall(
              id: 'call_a',
              name: 'echo',
              arguments: {},
              rawArguments: '{}',
            ),
          ),
        );

      final outputs = harness.drain();
      expect(outputs, hasLength(2));
      final started = outputs[0] as AgentToolCallStarted;
      expect(started.name, 'echo');
      expect(started.agent, primaryHandle);
      expect(outputs[1], isA<AgentToolCallEmitted>());
      expect(harness.data.step!.blocks, hasLength(1));
    });

    test('opens a new block when the delta kind changes', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..event(const InferenceReasoningDelta('think'))
        ..event(const InferenceReasoningDelta(' more'))
        ..event(const InferenceReasoningDelta(''))
        ..event(const InferenceTextDelta('answer'))
        ..event(
          const InferenceToolCallEmitted(
            InferenceToolCall(
              id: 'call_a',
              name: 'echo',
              arguments: {'text': 'hi'},
              rawArguments: '{"text":"hi"}',
            ),
          ),
        )
        ..event(const InferenceTextDelta('after'))
        ..event(
          const InferenceCompletionFinished(InferenceStopReason.toolCalls),
        )
        ..streamEnded();

      final outputs = harness.drain();
      final reasoning = outputs[0] as AgentReasoningDelta;
      final reasoningAgain = outputs[1] as AgentReasoningDelta;
      final text = outputs[2] as AgentTextDelta;
      final toolCall = outputs[3] as AgentToolCallEmitted;
      final after = outputs[4] as AgentTextDelta;
      final needsTools = outputs[5] as AgentNeedsToolResults;
      expect(reasoningAgain.blockId, reasoning.blockId);
      expect(text.blockId, isNot(reasoning.blockId));
      expect(after.blockId, isNot(text.blockId));
      expect(toolCall.toolCall, isA<ToolCallDefault>());
      expect(toolCall.toolCall.id, 'call_a');
      expect(toolCall.toolCall.arguments, {'text': 'hi'});
      expect(needsTools.toolCalls, [toolCall.toolCall]);
      expect(needsTools.entry.blocks.map((block) => block.runtimeType), [
        TranscriptReasoningBlock,
        TranscriptParagraphBlock,
        TranscriptToolCallBlock,
        TranscriptParagraphBlock,
      ]);
      expect(
        (needsTools.entry.blocks[0] as TranscriptReasoningBlock).text,
        'think more',
      );
      expect(harness.logic.value, isA<WaitingForToolResultsState>());
    });

    test('mints an id for a tool call the provider left unnamed', () {
      final harness =
          _Harness(
              entries: [
                userEntry('hi'),
                assistantEntry(
                  toolCalls: const [
                    ToolCallDefault(id: '00zzzz', name: 'echo', arguments: {}),
                    ToolCallDefault(id: 'call_x', name: 'echo', arguments: {}),
                  ],
                ),
              ],
            )
            ..logic.input(const StepRequested())
            ..drain()
            ..event(
              const InferenceToolCallEmitted(
                InferenceToolCall(
                  id: '',
                  name: 'echo',
                  arguments: {},
                  rawArguments: '',
                ),
              ),
            );

      final delta = harness.drain().single as AgentToolCallEmitted;
      expect(delta.toolCall.id, matches(RegExp(r'^[0-9a-z]{6}$')));
      expect(delta.toolCall.id.compareTo('00zzzz'), greaterThan(0));
    });

    test('continues after tool results and ignores stale stream input', () {
      final harness = _Harness(agentConfig: config(tools: [tool('echo')]))
        ..logic.input(const StepRequested())
        ..drain()
        ..event(
          const InferenceToolCallEmitted(
            InferenceToolCall(
              id: 'call_a',
              name: 'echo',
              arguments: {},
              rawArguments: '{}',
            ),
          ),
        )
        ..event(
          const InferenceCompletionFinished(InferenceStopReason.toolCalls),
        )
        ..streamEnded()
        ..drain()
        ..event(const InferenceTextDelta('late'), completionId: 1)
        ..streamEnded(completionId: 1)
        ..streamErrored(StateError('late'), completionId: 1);
      expect(harness.drain(), isEmpty);
      expect(harness.logic.value, isA<WaitingForToolResultsState>());

      harness.logic.input(
        ToolResultsSubmitted(
          entries: [
            toolEntry(
              const ToolCallSucceeded(
                callId: 'call_a',
                toolName: 'echo',
                content: 'ok',
              ),
            ),
          ],
        ),
      );

      final outputs = harness.drain();
      expect(outputs, hasLength(3));
      final updated = outputs[0] as AgentUpdated;
      expect(updated.transcript.revision, 2);
      expect(updated.transcript.entries, hasLength(3));
      expect(outputs[1], isA<AgentStepStarted>());
      final requested = outputs[2] as CompletionRequested;
      expect(requested.completionId, 2);
      final messages = requested.request.messages;
      expect(messages, hasLength(4));
      expect(messages[2], isA<InferenceAssistantMessage>());
      expect(messages[3], isA<InferenceToolResultMessage>());
      expect(requested.request.tools.single.name, 'echo');

      harness
        ..event(const InferenceTextDelta('stale'), completionId: 1)
        ..streamEnded(completionId: 1)
        ..streamErrored(StateError('stale'), completionId: 1);
      expect(harness.drain(), isEmpty);
      expect(harness.logic.value, isA<StreamingState>());
    });

    test('completes on every non-tool stop reason', () {
      for (final reason in [
        InferenceStopReason.length,
        InferenceStopReason.contentFilter,
        InferenceStopReason.other,
      ]) {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..event(const InferenceTextDelta('partial'))
          ..drain()
          ..event(InferenceCompletionFinished(reason))
          ..streamEnded();

        final completed = harness.drain().single as AgentCompleted;
        expect(completed.report, 'partial', reason: reason.name);
        expect(harness.logic.value, isA<CompletedState>());
      }
    });

    test('fails when the stream ends without a completion', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..event(const InferenceTextDelta('partial'))
        ..drain()
        ..streamEnded();

      final failed = harness.drain().single as AgentFailed;
      expect(failed.reason, AgentRunFailureReason.loopFailed);
      expect(failed.message, 'stream ended without a completion');
      expect(harness.logic.value, isA<FailedState>());
      expect(harness.data.transcript.entries, hasLength(1));
    });

    test('fails when the client reports a failure', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..event(
          const InferenceCompletionFailed(
            InferenceFailure(
              kind: InferenceFailureKind.network,
              message: 'offline',
            ),
          ),
        )
        ..streamEnded();

      final failed = harness.drain().single as AgentFailed;
      expect(failed.message, 'network: offline');
      expect(harness.logic.value, isA<FailedState>());
    });

    test('fails when the stream errors', () {
      final harness = _Harness()
        ..logic.input(const StepRequested())
        ..drain()
        ..streamErrored(StateError('boom'));

      final failed = harness.drain().single as AgentFailed;
      expect(failed.message, 'Bad state: boom');
    });

    group('cancel', () {
      test('before the first step reports the original transcript', () {
        final harness = _Harness()..logic.input(const CancelRequested());

        final cancelled = harness.drain().single as AgentCancelled;
        expect(cancelled.transcript.entries, hasLength(1));
        expect(harness.logic.value, isA<CancelledState>());
      });

      test('mid-stream keeps partial content', () {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..event(const InferenceTextDelta('part'))
          ..drain()
          ..logic.input(const CancelRequested());

        final cancelled = harness.drain().single as AgentCancelled;
        expect(cancelled.transcript.entries, hasLength(2));
        expect(harness.data.step, isNull);
      });

      test('mid-stream without content adds nothing', () {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..logic.input(const CancelRequested());

        final cancelled = harness.drain().single as AgentCancelled;
        expect(cancelled.transcript.entries, hasLength(1));
      });

      test('while waiting for tools keeps the tool call entry', () {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..event(
            const InferenceToolCallEmitted(
              InferenceToolCall(
                id: 'a',
                name: 'echo',
                arguments: {},
                rawArguments: '{}',
              ),
            ),
          )
          ..event(
            const InferenceCompletionFinished(InferenceStopReason.toolCalls),
          )
          ..streamEnded()
          ..drain()
          ..logic.input(const CancelRequested());

        final cancelled = harness.drain().single as AgentCancelled;
        expect(cancelled.transcript.entries, hasLength(2));
      });

      test('while compacting drops the compaction', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..drain()
              ..logic.input(const CancelRequested());

        expect(harness.drain().single, isA<AgentCancelled>());
        expect(harness.data.compaction, isNull);
        expect(harness.logic.value, isA<CancelledState>());
      });

      test('in a terminal state does nothing', () {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..streamText('done')
          ..drain()
          ..logic.input(const CancelRequested());

        expect(harness.drain(), isEmpty);
        expect(harness.logic.value, isA<CompletedState>());
      });
    });

    group('compaction', () {
      test('folds the window into a summary checkpoint before stepping', () {
        withClock(Clock.fixed(_fixedNow), () {
          final harness = _Harness(
            entries: [
              userEntry('hi'),
              assistantEntry(text: 'yo'),
              userEntry('more'),
            ],
            agentConfig: config(compactionReasoningMode: 'low'),
            usage: const RemoteUsage(promptTokens: 40, completionTokens: 20),
          )..logic.input(const StepRequested());

          final gated = harness.drain();
          expect(gated, hasLength(3));
          expect(gated[0], isA<AgentStarted>());
          expect(
            gated[1],
            isA<AgentCompactionStarted>()
                .having((event) => event.tokensBefore, 'tokensBefore', 60)
                .having((event) => event.compactAt, 'compactAt', 50)
                .having((event) => event.contextSize, 'contextSize', 100),
          );
          expect(gated[2], isA<AgentNeedsCompactionPrompt>());
          expect(harness.logic.value, isA<AwaitingCompactionPromptState>());

          harness.logic.input(
            const CompactionPromptSubmitted(content: compactionContent),
          );
          final summarizing = harness.drain();
          expect(summarizing, hasLength(2));
          expect(
            summarizing[0],
            isA<AgentSummaryDelta>().having(
              (event) => event.text,
              'text',
              'Summary:',
            ),
          );
          final requested = summarizing[1] as CompletionRequested;
          expect(requested.completionId, 1);
          expect(requested.request.messages, hasLength(2));
          expect(
            requested.request.reasoning,
            const InferenceReasoningEffort(InferenceEffort.low),
          );
          expect(requested.request.sampling.maxOutputTokens, 256);
          expect(harness.logic.value, isA<SummarizingState>());

          harness
            ..event(const InferenceTextDelta(' user said hi'))
            ..event(const InferenceTextDelta(''))
            ..event(const InferenceReasoningDelta('thinking'))
            ..event(const InferenceReasoningDelta(''))
            ..event(
              const InferenceToolCallEmitted(
                InferenceToolCall(
                  id: 'x',
                  name: 'echo',
                  arguments: {},
                  rawArguments: '{}',
                ),
              ),
            )
            ..event(
              const InferenceUsageReported(
                promptTokens: 30,
                completionTokens: 12,
              ),
            )
            ..event(
              const InferenceCompletionFinished(InferenceStopReason.stop),
            );
          final streamed = harness.drain();
          expect(streamed, hasLength(2));
          expect(
            streamed[0],
            isA<AgentSummaryDelta>().having(
              (event) => event.text,
              'text',
              ' user said hi',
            ),
          );
          expect(
            streamed[1],
            isA<AgentSummaryReasoningDelta>().having(
              (event) => event.text,
              'text',
              'thinking',
            ),
          );

          harness.streamEnded();
          final folded = harness.drain();
          expect(folded, hasLength(5));
          final completed = folded[0] as AgentCompactionCompleted;
          final outcome = completed.outcome as AgentCompactionSucceeded;
          expect(outcome.summary, 'Summary: user said hi');
          expect(outcome.tokensAfter, 12);
          expect(
            folded[1],
            isA<UsageChanged>().having(
              (work) => work.usage,
              'usage',
              const RemoteUsage(promptTokens: 12, completionTokens: 0),
            ),
          );
          final updated = folded[2] as AgentUpdated;
          expect(updated.transcript.entries, hasLength(4));
          final checkpoint = updated.transcript.entries.last;
          expect(checkpoint.role, Role.system);
          expect(
            (checkpoint.blocks.single as TranscriptSummaryBlock).text,
            'Summary: user said hi',
          );
          expect(folded[3], isA<AgentStepStarted>());
          final step = folded[4] as CompletionRequested;
          expect(step.completionId, 2);
          expect(step.request.messages, hasLength(2));
          expect(
            (step.request.messages[1] as InferenceUserMessage).text,
            contains('Summary: user said hi'),
          );
          expect(harness.logic.value, isA<StreamingState>());
          expect(harness.data.compaction, isNull);
        });
      });

      test('is checked again after tool results', () {
        final harness = _Harness()
          ..logic.input(const StepRequested())
          ..drain()
          ..event(
            const InferenceToolCallEmitted(
              InferenceToolCall(
                id: 'a',
                name: 'echo',
                arguments: {},
                rawArguments: '{}',
              ),
            ),
          )
          ..event(
            const InferenceUsageReported(
              promptTokens: 45,
              completionTokens: 10,
            ),
          )
          ..event(
            const InferenceCompletionFinished(InferenceStopReason.toolCalls),
          )
          ..streamEnded()
          ..drain()
          ..logic.input(
            ToolResultsSubmitted(
              entries: [
                toolEntry(
                  const ToolCallSucceeded(
                    callId: 'a',
                    toolName: 'echo',
                    content: 'ok',
                  ),
                ),
              ],
            ),
          );

        final outputs = harness.drain();
        expect(outputs[0], isA<AgentUpdated>());
        expect(outputs[1], isA<AgentCompactionStarted>());
        expect(outputs[2], isA<AgentNeedsCompactionPrompt>());
        expect(harness.logic.value, isA<AwaitingCompactionPromptState>());
      });

      test('is skipped when nothing after the checkpoint can fold', () {
        final harness = _Harness(
          entries: [userEntry('old'), summaryEntry('Earlier.')],
          usage: const RemoteUsage(promptTokens: 90, completionTokens: 20),
        )..logic.input(const StepRequested());

        final outputs = harness.drain();
        expect(outputs[1], isA<AgentStepStarted>());
        expect(harness.logic.value, isA<StreamingState>());
      });

      test('strips a prefill the model echoed back', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..event(const InferenceTextDelta('Summary: echoed'))
              ..event(
                const InferenceCompletionFinished(InferenceStopReason.stop),
              )
              ..streamEnded();

        final completed = harness
            .drain()
            .whereType<AgentCompactionCompleted>()
            .single;
        expect(
          (completed.outcome as AgentCompactionSucceeded).summary,
          'Summary: echoed',
        );
      });

      test('falls back to the prior summary when nothing was produced', () {
        final harness =
            _Harness(
                entries: [
                  summaryEntry('Earlier.'),
                  userEntry('hi'),
                  assistantEntry(text: 'yo'),
                ],
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..event(const InferenceTextDelta('   '))
              ..event(
                const InferenceCompletionFinished(InferenceStopReason.stop),
              )
              ..streamEnded();

        final completed = harness
            .drain()
            .whereType<AgentCompactionCompleted>()
            .single;
        final outcome = completed.outcome as AgentCompactionSucceeded;
        expect(outcome.summary, 'Earlier.');
        expect(outcome.tokensAfter, 0);
        expect(harness.data.transcript.lastCheckpoint, 3);
      });

      test('falls back to a placeholder without a prior summary', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(
                  content: CompactionPromptContent(
                    instruction: 'i',
                    prefill: '',
                    format: 'f',
                  ),
                ),
              )
              ..drain()
              ..event(
                const InferenceCompletionFinished(InferenceStopReason.stop),
              )
              ..streamEnded();

        final completed = harness.drain().first as AgentCompactionCompleted;
        expect(
          (completed.outcome as AgentCompactionSucceeded).summary,
          '[no summary produced]',
        );
      });

      test('fails when the summarizer reports a failure', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..event(
                const InferenceCompletionFailed(
                  InferenceFailure(
                    kind: InferenceFailureKind.auth,
                    message: 'nope',
                  ),
                ),
              );

        final outputs = harness.drain();
        expect(outputs, hasLength(2));
        final completed = outputs[0] as AgentCompactionCompleted;
        final outcome = completed.outcome as AgentCompactionFailed;
        expect(outcome.reason, 'sampleFailed');
        expect(outcome.message, 'auth: nope');
        final failed = outputs[1] as AgentFailed;
        expect(failed.reason, AgentRunFailureReason.compactionFailed);
        expect(failed.message, 'auth: nope');
        expect(harness.data.compaction, isNull);
        expect(harness.logic.value, isA<FailedState>());
      });

      test('fails when the summary stream errors or ends early', () {
        final errored =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..streamErrored(StateError('boom'));
        expect(
          (errored.drain()[1] as AgentFailed).message,
          'Bad state: boom',
        );

        final early =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..streamEnded();
        expect(
          (early.drain()[1] as AgentFailed).message,
          'summary stream ended without a completion',
        );
      });

      test('ignores stale stream input while summarizing', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..event(const InferenceTextDelta('stale'), completionId: 9)
              ..streamEnded(completionId: 9)
              ..streamErrored(StateError('stale'), completionId: 9);

        expect(harness.drain(), isEmpty);
        expect(harness.logic.value, isA<SummarizingState>());
      });

      test('ignores a tool call the summarizer starts', () {
        final harness =
            _Harness(
                usage: const RemoteUsage(
                  promptTokens: 40,
                  completionTokens: 20,
                ),
              )
              ..logic.input(const StepRequested())
              ..logic.input(
                const CompactionPromptSubmitted(content: compactionContent),
              )
              ..drain()
              ..event(const InferenceToolCallStarted(name: 'echo'));

        expect(harness.drain(), isEmpty);
        expect(harness.logic.value, isA<SummarizingState>());
      });
    });
  });

  group('compact goal', () {
    test('folds straight away and completes without stepping', () {
      withClock(Clock.fixed(_fixedNow), () {
        final harness = _Harness(
          entries: [
            userEntry('hi'),
            assistantEntry(text: 'yo'),
            userEntry('more'),
          ],
          agentConfig: config(compactionReasoningMode: 'low'),
          usage: const RemoteUsage(promptTokens: 10, completionTokens: 5),
          goal: TurnGoal.compact,
        )..logic.input(const StepRequested());

        final gated = harness.drain();
        expect(gated, hasLength(3));
        expect(gated[0], isA<AgentStarted>());
        expect(
          gated[1],
          isA<AgentCompactionStarted>()
              .having((event) => event.tokensBefore, 'tokensBefore', 15)
              .having((event) => event.compactAt, 'compactAt', 50),
        );
        expect(gated[2], isA<AgentNeedsCompactionPrompt>());
        expect(harness.logic.value, isA<AwaitingCompactionPromptState>());

        harness.logic.input(
          const CompactionPromptSubmitted(content: compactionContent),
        );
        final summarizing = harness.drain();
        expect(summarizing, hasLength(2));
        expect(summarizing[0], isA<AgentSummaryDelta>());
        final requested = summarizing[1] as CompletionRequested;
        expect(requested.completionId, 1);
        expect(
          requested.request.reasoning,
          const InferenceReasoningEffort(InferenceEffort.low),
        );
        expect(harness.logic.value, isA<SummarizingState>());

        harness
          ..event(const InferenceTextDelta(' user said hi'))
          ..event(
            const InferenceUsageReported(
              promptTokens: 30,
              completionTokens: 12,
            ),
          )
          ..event(const InferenceCompletionFinished(InferenceStopReason.stop))
          ..drain()
          ..streamEnded();

        final folded = harness.drain();
        expect(folded, hasLength(4));
        final completed = folded[0] as AgentCompactionCompleted;
        final outcome = completed.outcome as AgentCompactionSucceeded;
        expect(outcome.summary, 'Summary: user said hi');
        expect(
          folded[1],
          isA<UsageChanged>().having(
            (work) => work.usage,
            'usage',
            const RemoteUsage(promptTokens: 12, completionTokens: 0),
          ),
        );
        final updated = folded[2] as AgentUpdated;
        expect(updated.transcript.entries, hasLength(4));
        expect(updated.transcript.priorSummary, 'Summary: user said hi');
        expect(
          folded[3],
          isA<AgentCompleted>()
              .having((event) => event.report, 'report', isNull)
              .having(
                (event) => event.transcript.entries,
                'entries',
                hasLength(4),
              ),
        );
        expect(harness.logic.value, isA<CompletedState>());
        expect(harness.data.compaction, isNull);
        expect(harness.data.step, isNull);
      });
    });

    test('folds without any recorded usage', () {
      final harness = _Harness(goal: TurnGoal.compact)
        ..logic.input(const StepRequested());

      final gated = harness.drain();
      expect(
        gated[1],
        isA<AgentCompactionStarted>().having(
          (event) => event.tokensBefore,
          'tokensBefore',
          0,
        ),
      );
      expect(harness.logic.value, isA<AwaitingCompactionPromptState>());
    });

    test('can be cancelled while waiting for the prompt', () {
      final harness = _Harness(goal: TurnGoal.compact)
        ..logic.input(const StepRequested())
        ..drain()
        ..logic.input(const CancelRequested());

      final outputs = harness.drain();
      expect(outputs.single, isA<AgentCancelled>());
      expect(harness.logic.value, isA<CancelledState>());
      expect(harness.data.compaction, isNull);
    });

    test('fails the turn when the summary stream errors', () {
      final harness = _Harness(goal: TurnGoal.compact)
        ..logic.input(const StepRequested())
        ..logic.input(
          const CompactionPromptSubmitted(content: compactionContent),
        )
        ..drain()
        ..streamErrored(StateError('boom'));

      final outputs = harness.drain();
      expect(outputs, hasLength(2));
      expect(
        (outputs[0] as AgentCompactionCompleted).outcome,
        isA<AgentCompactionFailed>(),
      );
      expect(
        outputs[1],
        isA<AgentFailed>().having(
          (event) => event.reason,
          'reason',
          AgentRunFailureReason.compactionFailed,
        ),
      );
      expect(harness.logic.value, isA<FailedState>());
    });
  });

  group('RemoteTurnData', () {
    test('needs compaction only when over the limit with foldable entries', () {
      final empty = RemoteTurnData(
        handle: primaryHandle,
        config: config(),
        goal: TurnGoal.respond,
        transcript: transcriptOf([]),
        modelId: 'm',
        contextWindow: 10,
        summaryMaxOutputTokens: 1,
        usage: const RemoteUsage(promptTokens: 5, completionTokens: 0),
      );
      expect(empty.needsCompaction, isFalse);

      final plain = RemoteTurnData(
        handle: primaryHandle,
        config: config(),
        goal: TurnGoal.respond,
        transcript: transcriptOf([userEntry('hi')]),
        modelId: 'm',
        contextWindow: 10,
        summaryMaxOutputTokens: 1,
        usage: const RemoteUsage(promptTokens: 5, completionTokens: 0),
      );
      expect(plain.needsCompaction, isTrue);
    });

    test('RemoteUsage compares by value', () {
      const usage = RemoteUsage(promptTokens: 1, completionTokens: 2);

      expect(usage.total, 3);
      expect(usage, const RemoteUsage(promptTokens: 1, completionTokens: 2));
      expect(
        usage.hashCode,
        const RemoteUsage(promptTokens: 1, completionTokens: 2).hashCode,
      );
      expect(
        usage,
        isNot(const RemoteUsage(promptTokens: 2, completionTokens: 1)),
      );
      expect(usage.toString(), 'RemoteUsage(prompt: 1, completion: 2)');
    });
  });
}
