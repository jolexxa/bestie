import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('InferenceEndpoint', () {
    final baseUrl = Uri.parse('https://openrouter.ai/api/v1');

    test('compares by url, key and headers', () {
      final endpoint = InferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: 'sk',
        headers: const {'X-Title': 'bestie'},
      );
      final same = InferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: 'sk',
        headers: const {'X-Title': 'bestie'},
      );
      final differentHeaderValue = InferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: 'sk',
        headers: const {'X-Title': 'other'},
      );
      final differentHeaderCount = InferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: 'sk',
      );
      final differentDialect = InferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: 'sk',
        headers: const {'X-Title': 'bestie'},
        dialect: InferenceDialect.openRouter,
      );

      expect(endpoint, same);
      expect(endpoint.hashCode, same.hashCode);
      expect(endpoint.dialect, InferenceDialect.openAi);
      expect(endpoint, isNot(differentHeaderValue));
      expect(endpoint, isNot(differentHeaderCount));
      expect(endpoint, isNot(differentDialect));
      expect(endpoint.toString(), 'InferenceEndpoint($baseUrl)');
    });
  });

  group('InferenceToolCall', () {
    test('compares by id, name and raw arguments', () {
      const call = InferenceToolCall(
        id: 'call_1',
        name: 'echo',
        arguments: {'text': 'hi'},
        rawArguments: '{"text":"hi"}',
      );
      const same = InferenceToolCall(
        id: 'call_1',
        name: 'echo',
        arguments: {},
        rawArguments: '{"text":"hi"}',
      );
      const other = InferenceToolCall(
        id: 'call_2',
        name: 'echo',
        arguments: {},
        rawArguments: '{"text":"hi"}',
      );

      expect(call, same);
      expect(call.hashCode, same.hashCode);
      expect(call, isNot(other));
      expect(call.toString(), 'InferenceToolCall(call_1, echo, {"text":"hi"})');
    });
  });

  group('InferenceMessage', () {
    test('exposes every variant', () {
      const system = InferenceSystemMessage('be nice');
      const user = InferenceUserMessage('hello');
      const assistant = InferenceAssistantMessage(
        text: 'hi',
        reasoning: 'thinking',
        toolCalls: [
          InferenceToolCall(
            id: 'call_1',
            name: 'echo',
            arguments: {},
            rawArguments: '{}',
          ),
        ],
        providerReasoning: [
          {'type': 'reasoning.text', 'text': 'thinking'},
        ],
      );
      const toolResult = InferenceToolResultMessage(
        toolCallId: 'call_1',
        name: 'echo',
        content: 'done',
        isError: true,
      );
      const messages = <InferenceMessage>[system, user, assistant, toolResult];

      expect(system.text, 'be nice');
      expect(user.text, 'hello');
      expect(assistant.text, 'hi');
      expect(assistant.reasoning, 'thinking');
      expect(assistant.toolCalls, hasLength(1));
      expect(assistant.providerReasoning, hasLength(1));
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
        messages: [InferenceUserMessage('hi')],
      );

      expect(request.model, 'openai/gpt-4o-mini');
      expect(request.tools, isEmpty);
      expect(request.sampling, const InferenceSampling());
      expect(request.reasoning, const InferenceReasoningDefault());
      expect(request.stopSequences, isEmpty);
    });

    test('carries tools and sampling', () {
      const tool = InferenceTool(
        name: 'echo',
        description: 'Echoes text',
        parameters: {'type': 'object'},
      );
      const request = CompletionRequest(
        model: 'm',
        messages: [],
        tools: [tool],
        sampling: InferenceSampling(temperature: 0.5),
        reasoning: InferenceReasoningEffort(InferenceEffort.high),
        stopSequences: ['END'],
      );

      expect(request.tools.single.name, 'echo');
      expect(request.tools.single.description, 'Echoes text');
      expect(request.tools.single.parameters, {'type': 'object'});
      expect(request.sampling.temperature, 0.5);
      expect(
        request.reasoning,
        const InferenceReasoningEffort(InferenceEffort.high),
      );
      expect(request.stopSequences, ['END']);
    });
  });

  group('InferenceSampling', () {
    test('compares by value and copies max output tokens', () {
      const sampling = InferenceSampling(
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

  group('InferenceReasoning', () {
    test('parameterless variants compare by type', () {
      const variants = <InferenceReasoning>[
        InferenceReasoningDefault(),
        InferenceReasoningDisabled(),
        InferenceReasoningEnabled(),
      ];

      expect(const InferenceReasoningDefault(), variants[0]);
      expect(const InferenceReasoningDisabled(), variants[1]);
      expect(const InferenceReasoningEnabled(), variants[2]);
      expect(variants.map((variant) => variant.hashCode).toSet(), hasLength(3));
      expect(const InferenceReasoningDefault(), isNot(variants[1]));
      expect(const InferenceReasoningDisabled(), isNot(variants[2]));
      expect(
        const InferenceReasoningEnabled(),
        isNot(const InferenceReasoningEffort(InferenceEffort.low)),
      );
    });

    test('effort compares by level', () {
      const low = InferenceReasoningEffort(InferenceEffort.low);

      expect(low, const InferenceReasoningEffort(InferenceEffort.low));
      expect(low.hashCode, InferenceEffort.low.hashCode);
      expect(low, isNot(const InferenceReasoningEffort(InferenceEffort.max)));
      expect(InferenceEffort.values, [
        InferenceEffort.minimal,
        InferenceEffort.low,
        InferenceEffort.medium,
        InferenceEffort.high,
        InferenceEffort.xhigh,
        InferenceEffort.max,
      ]);
    });
  });

  group('InferenceFailure', () {
    test('compares by kind and message', () {
      const failure = InferenceFailure(
        kind: InferenceFailureKind.auth,
        message: 'nope',
      );

      expect(
        failure,
        const InferenceFailure(
          kind: InferenceFailureKind.auth,
          message: 'nope',
        ),
      );
      expect(
        failure.hashCode,
        const InferenceFailure(
          kind: InferenceFailureKind.auth,
          message: 'nope',
        ).hashCode,
      );
      expect(
        failure,
        isNot(
          const InferenceFailure(
            kind: InferenceFailureKind.server,
            message: 'nope',
          ),
        ),
      );
      expect(failure.toString(), 'InferenceFailure(auth): nope');
      expect(InferenceFailureKind.values, hasLength(7));
    });
  });

  group('InferenceEvent', () {
    const call = InferenceToolCall(
      id: 'call_1',
      name: 'echo',
      arguments: {},
      rawArguments: '{}',
    );
    const failure = InferenceFailure(
      kind: InferenceFailureKind.network,
      message: 'offline',
    );

    test('text delta compares by text', () {
      const delta = InferenceTextDelta('hi');

      expect(delta, const InferenceTextDelta('hi'));
      expect(delta.hashCode, const InferenceTextDelta('hi').hashCode);
      expect(delta, isNot(const InferenceTextDelta('ho')));
      expect(delta, isNot(const InferenceReasoningDelta('hi')));
      expect(delta.toString(), 'InferenceTextDelta(hi)');
    });

    test('reasoning delta compares by text', () {
      const delta = InferenceReasoningDelta('hmm');

      expect(delta, const InferenceReasoningDelta('hmm'));
      expect(delta.hashCode, const InferenceReasoningDelta('hmm').hashCode);
      expect(delta, isNot(const InferenceReasoningDelta('huh')));
      expect(delta.toString(), 'InferenceReasoningDelta(hmm)');
    });

    test('tool call started compares by name', () {
      const started = InferenceToolCallStarted(name: 'echo');

      expect(started, const InferenceToolCallStarted(name: 'echo'));
      expect(started, isNot(const InferenceToolCallStarted(name: 'sum')));
      expect(
        started.hashCode,
        const InferenceToolCallStarted(name: 'echo').hashCode,
      );
      expect(started.toString(), 'InferenceToolCallStarted(echo)');
    });

    test('tool call emitted compares by call', () {
      const emitted = InferenceToolCallEmitted(call);

      expect(emitted, const InferenceToolCallEmitted(call));
      expect(emitted.hashCode, call.hashCode);
      expect(emitted.toString(), 'InferenceToolCallEmitted($call)');
    });

    test('usage compares by counts and sums totals', () {
      const usage = InferenceUsageReported(
        promptTokens: 10,
        completionTokens: 5,
      );

      expect(usage.totalTokens, 15);
      expect(
        usage,
        const InferenceUsageReported(promptTokens: 10, completionTokens: 5),
      );
      expect(
        usage.hashCode,
        const InferenceUsageReported(
          promptTokens: 10,
          completionTokens: 5,
        ).hashCode,
      );
      expect(
        usage,
        isNot(
          const InferenceUsageReported(promptTokens: 10, completionTokens: 6),
        ),
      );
      expect(
        usage.toString(),
        'InferenceUsageReported(prompt: 10, completion: 5, cost: null)',
      );
    });

    test('finished compares by reason', () {
      const finished = InferenceCompletionFinished(InferenceStopReason.stop);

      expect(
        finished,
        const InferenceCompletionFinished(InferenceStopReason.stop),
      );
      expect(finished.hashCode, InferenceStopReason.stop.hashCode);
      expect(
        finished,
        isNot(const InferenceCompletionFinished(InferenceStopReason.length)),
      );
      expect(finished.toString(), 'InferenceCompletionFinished(stop)');
      expect(InferenceStopReason.values, hasLength(5));
    });

    test('failed compares by failure', () {
      const failed = InferenceCompletionFailed(failure);

      expect(failed, const InferenceCompletionFailed(failure));
      expect(failed.hashCode, failure.hashCode);
      expect(failed.toString(), 'InferenceCompletionFailed($failure)');
    });
  });

  group('ListModelsResult', () {
    test('exposes listed models and failures', () {
      final created = DateTime.utc(2024);
      final model = InferenceModel(
        id: 'openai/gpt-4o-mini',
        ownedBy: 'openai',
        created: created,
      );
      final listed = ModelsListed([model]);
      const failed = ModelsListFailed(
        InferenceFailure(kind: InferenceFailureKind.auth, message: 'nope'),
      );
      const results = <ListModelsResult>[failed];

      expect(listed.models.single, model);
      expect(
        model,
        InferenceModel(
          id: 'openai/gpt-4o-mini',
          ownedBy: 'openai',
          created: created,
        ),
      );
      expect(
        model.hashCode,
        InferenceModel(
          id: 'openai/gpt-4o-mini',
          ownedBy: 'openai',
          created: created,
        ).hashCode,
      );
      expect(model, isNot(const InferenceModel(id: 'other')));
      expect(model.toString(), 'InferenceModel(openai/gpt-4o-mini)');
      expect(failed.failure.kind, InferenceFailureKind.auth);
      expect(results, hasLength(1));
      expect(InferenceProtocolId.values, [InferenceProtocolId.openAiCompat]);
    });
  });
}
