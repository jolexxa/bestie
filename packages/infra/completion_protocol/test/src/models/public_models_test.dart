import 'package:completion_protocol/completion_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('CompletionToolCall', () {
    test('compares by id, name and raw arguments', () {
      const call = CompletionToolCall(
        id: 'call_1',
        name: 'echo',
        arguments: {'text': 'hi'},
        rawArguments: '{"text":"hi"}',
      );
      const same = CompletionToolCall(
        id: 'call_1',
        name: 'echo',
        arguments: {},
        rawArguments: '{"text":"hi"}',
      );
      const other = CompletionToolCall(
        id: 'call_2',
        name: 'echo',
        arguments: {},
        rawArguments: '{"text":"hi"}',
      );

      expect(call, same);
      expect(call.hashCode, same.hashCode);
      expect(call, isNot(other));
      expect(
        call.toString(),
        'CompletionToolCall(call_1, echo, {"text":"hi"})',
      );
    });
  });

  group('CompletionMessage', () {
    test('exposes every variant', () {
      const system = CompletionSystemMessage('be nice');
      const user = CompletionUserMessage('hello');
      const assistant = CompletionAssistantMessage(
        text: 'hi',
        reasoning: 'thinking',
        toolCalls: [
          CompletionToolCall(
            id: 'call_1',
            name: 'echo',
            arguments: {},
            rawArguments: '{}',
          ),
        ],
      );
      const toolResult = CompletionToolResultMessage(
        toolCallId: 'call_1',
        name: 'echo',
        content: 'done',
        isError: true,
      );
      const messages = <CompletionMessage>[system, user, assistant, toolResult];

      expect(system.text, 'be nice');
      expect(user.text, 'hello');
      expect(assistant.text, 'hi');
      expect(assistant.reasoning, 'thinking');
      expect(assistant.toolCalls, hasLength(1));
      expect(toolResult.toolCallId, 'call_1');
      expect(toolResult.name, 'echo');
      expect(toolResult.content, 'done');
      expect(toolResult.isError, isTrue);
      expect(messages, hasLength(4));
    });
  });

  group('CompletionRequest', () {
    test('defaults to no tools, default sampling and default reasoning', () {
      const request = CompletionRequest(
        model: 'openai/gpt-4o-mini',
        messages: [CompletionUserMessage('hi')],
      );

      expect(request.model, 'openai/gpt-4o-mini');
      expect(request.tools, isEmpty);
      expect(request.sampling, const CompletionSampling());
      expect(request.reasoning, const CompletionReasoningDefault());
      expect(request.stopSequences, isEmpty);
      expect(request.agent, isNull);
    });

    test('carries tools and sampling', () {
      const tool = CompletionTool(
        name: 'echo',
        description: 'Echoes text',
        parameters: {'type': 'object'},
      );
      const request = CompletionRequest(
        model: 'm',
        messages: [],
        tools: [tool],
        sampling: CompletionSampling(temperature: 0.5),
        reasoning: CompletionReasoningEffort(CompletionEffort.high),
        stopSequences: ['END'],
        agent: AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
      );

      expect(request.tools.single.name, 'echo');
      expect(request.tools.single.description, 'Echoes text');
      expect(request.tools.single.parameters, {'type': 'object'});
      expect(request.sampling.temperature, 0.5);
      expect(
        request.reasoning,
        const CompletionReasoningEffort(CompletionEffort.high),
      );
      expect(request.stopSequences, ['END']);
      expect(
        request.agent,
        const AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
      );
    });
  });

  group('CompletionSampling', () {
    test('compares by value and copies max output tokens', () {
      const sampling = CompletionSampling(
        temperature: 0.7,
        topP: 0.9,
        frequencyPenalty: 0.1,
        presencePenalty: 0.2,
        seed: 7,
        maxOutputTokens: 100,
      );
      final copied = sampling.copyWith(maxOutputTokens: 200);
      final unchanged = sampling.copyWith();

      expect(sampling, unchanged);
      expect(sampling.hashCode, unchanged.hashCode);
      expect(sampling, isNot(copied));
      expect(copied.maxOutputTokens, 200);
      expect(copied.temperature, 0.7);
      expect(copied.topP, 0.9);
      expect(copied.frequencyPenalty, 0.1);
      expect(copied.presencePenalty, 0.2);
      expect(copied.seed, 7);
    });
  });

  group('CompletionReasoning', () {
    test('parameterless variants compare by type', () {
      const variants = <CompletionReasoning>[
        CompletionReasoningDefault(),
        CompletionReasoningDisabled(),
        CompletionReasoningEnabled(),
      ];

      expect(const CompletionReasoningDefault(), variants[0]);
      expect(const CompletionReasoningDisabled(), variants[1]);
      expect(const CompletionReasoningEnabled(), variants[2]);
      expect(variants.map((variant) => variant.hashCode).toSet(), hasLength(3));
      expect(const CompletionReasoningDefault(), isNot(variants[1]));
      expect(const CompletionReasoningDisabled(), isNot(variants[2]));
      expect(
        const CompletionReasoningEnabled(),
        isNot(const CompletionReasoningEffort(CompletionEffort.low)),
      );
    });

    test('effort compares by level', () {
      const low = CompletionReasoningEffort(CompletionEffort.low);

      expect(low, const CompletionReasoningEffort(CompletionEffort.low));
      expect(low.hashCode, CompletionEffort.low.hashCode);
      expect(low, isNot(const CompletionReasoningEffort(CompletionEffort.max)));
      expect(CompletionEffort.values, [
        CompletionEffort.minimal,
        CompletionEffort.low,
        CompletionEffort.medium,
        CompletionEffort.high,
        CompletionEffort.xhigh,
        CompletionEffort.max,
      ]);
    });
  });

  group('CompletionFailure', () {
    test('compares by kind and message', () {
      const failure = CompletionFailure(
        kind: CompletionFailureKind.auth,
        message: 'nope',
      );

      expect(
        failure,
        const CompletionFailure(
          kind: CompletionFailureKind.auth,
          message: 'nope',
        ),
      );
      expect(
        failure.hashCode,
        const CompletionFailure(
          kind: CompletionFailureKind.auth,
          message: 'nope',
        ).hashCode,
      );
      expect(
        failure,
        isNot(
          const CompletionFailure(
            kind: CompletionFailureKind.server,
            message: 'nope',
          ),
        ),
      );
      expect(failure.toString(), 'CompletionFailure(auth): nope');
      expect(CompletionFailureKind.values, hasLength(7));
    });
  });

  group('CompletionEvent', () {
    const call = CompletionToolCall(
      id: 'call_1',
      name: 'echo',
      arguments: {},
      rawArguments: '{}',
    );
    const failure = CompletionFailure(
      kind: CompletionFailureKind.network,
      message: 'offline',
    );

    test('text delta compares by text', () {
      const delta = CompletionTextDelta('hi');

      expect(delta, const CompletionTextDelta('hi'));
      expect(delta.hashCode, const CompletionTextDelta('hi').hashCode);
      expect(delta, isNot(const CompletionTextDelta('ho')));
      expect(delta, isNot(const CompletionReasoningDelta('hi')));
      expect(delta.toString(), 'CompletionTextDelta(hi)');
    });

    test('reasoning delta compares by text', () {
      const delta = CompletionReasoningDelta('hmm');

      expect(delta, const CompletionReasoningDelta('hmm'));
      expect(delta.hashCode, const CompletionReasoningDelta('hmm').hashCode);
      expect(delta, isNot(const CompletionReasoningDelta('huh')));
      expect(delta.toString(), 'CompletionReasoningDelta(hmm)');
    });

    test('tool call started compares by name', () {
      const started = CompletionToolCallStarted(name: 'echo');

      expect(started, const CompletionToolCallStarted(name: 'echo'));
      expect(started, isNot(const CompletionToolCallStarted(name: 'sum')));
      expect(
        started.hashCode,
        const CompletionToolCallStarted(name: 'echo').hashCode,
      );
      expect(started.toString(), 'CompletionToolCallStarted(echo)');
    });

    test('tool call emitted compares by call', () {
      const emitted = CompletionToolCallEmitted(call);

      expect(emitted, const CompletionToolCallEmitted(call));
      expect(emitted.hashCode, call.hashCode);
      expect(emitted.toString(), 'CompletionToolCallEmitted($call)');
    });

    test('usage compares by counts and sums totals', () {
      const usage = CompletionUsageReported(
        promptTokens: 10,
        completionTokens: 5,
      );

      expect(usage.totalTokens, 15);
      expect(
        usage,
        const CompletionUsageReported(promptTokens: 10, completionTokens: 5),
      );
      expect(
        usage.hashCode,
        const CompletionUsageReported(
          promptTokens: 10,
          completionTokens: 5,
        ).hashCode,
      );
      expect(
        usage,
        isNot(
          const CompletionUsageReported(promptTokens: 10, completionTokens: 6),
        ),
      );
      expect(
        usage,
        isNot(
          const CompletionUsageReported(
            promptTokens: 10,
            completionTokens: 5,
            reasoningTokens: 3,
          ),
        ),
      );
      expect(
        usage.toString(),
        'CompletionUsageReported(prompt: 10, completion: 5, reasoning: null, '
        'cost: null)',
      );
    });

    test('finished compares by reason', () {
      const finished = CompletionFinished(CompletionStopReason.stop);

      expect(
        finished,
        const CompletionFinished(CompletionStopReason.stop),
      );
      expect(finished.hashCode, CompletionStopReason.stop.hashCode);
      expect(
        finished,
        isNot(const CompletionFinished(CompletionStopReason.length)),
      );
      expect(finished.toString(), 'CompletionFinished(stop)');
      expect(CompletionStopReason.values, hasLength(5));
    });

    test('failed compares by failure', () {
      const failed = CompletionFailed(failure);

      expect(failed, const CompletionFailed(failure));
      expect(failed.hashCode, failure.hashCode);
      expect(failed.toString(), 'CompletionFailed($failure)');
    });
  });
}
