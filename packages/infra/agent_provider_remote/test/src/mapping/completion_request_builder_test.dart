import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/mapping/completion_request_builder.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  const builder = CompletionRequestBuilder();

  RemoteTurnData dataFor(
    List<TranscriptEntry> entries, {
    AgentConfig? agentConfig,
    int? maxOutputTokens,
  }) => RemoteTurnData(
    handle: primaryHandle,
    config: agentConfig ?? config(),
    goal: TurnGoal.respond,
    transcript: transcriptOf(entries),
    modelId: 'test/model',
    contextWindow: 1000,
    maxOutputTokens: maxOutputTokens,
    summaryMaxOutputTokens: 256,
  );

  test('step maps the window after the last checkpoint', () {
    final data = dataFor(
      [userEntry('old'), summaryEntry('Earlier.'), userEntry('new')],
      agentConfig: config(
        reasoningMode: 'high',
        tools: [tool('echo')],
        sampling: const SamplingOptions(seed: 3, temperature: 0.4),
      ),
      maxOutputTokens: 128,
    );

    final request = builder.step(data);

    expect(request.model, 'test/model');
    expect(request.messages, hasLength(3));
    expect(request.messages[0], isA<InferenceSystemMessage>());
    expect(
      (request.messages[1] as InferenceUserMessage).text,
      contains('Earlier.'),
    );
    expect((request.messages[2] as InferenceUserMessage).text, 'new');
    expect(request.tools.single.name, 'echo');
    expect(
      request.sampling,
      const InferenceSampling(temperature: 0.4, seed: 3, maxOutputTokens: 128),
    );
    expect(
      request.reasoning,
      const InferenceReasoningEffort(InferenceEffort.high),
    );
  });

  test('summary asks for a fold that opens with the prefill', () {
    final data =
        dataFor(
            [userEntry('hi'), assistantEntry(text: 'yo')],
            agentConfig: config(
              compactionReasoningMode: 'low',
              tools: [tool('echo')],
            ),
          )
          ..compaction = (CompactionFrame(tokensBefore: 900, priorSummary: null)
            ..content = compactionContent);

    final request = builder.summary(data);

    expect(request.tools, isEmpty);
    expect(request.messages, hasLength(2));
    expect(
      (request.messages[0] as InferenceSystemMessage).text,
      'You summarize.',
    );
    final prompt = (request.messages[1] as InferenceUserMessage).text;
    expect(
      prompt,
      startsWith('<conversation>\nuser: hi\nassistant: yo\n</conversation>'),
    );
    expect(
      prompt,
      endsWith(
        'Use bullets.\n'
        'Begin your reply with "Summary:" and nothing before it.',
      ),
    );
    expect(request.messages.last, isNot(isA<InferenceAssistantMessage>()));
    expect(request.sampling.maxOutputTokens, 256);
    expect(
      request.reasoning,
      const InferenceReasoningEffort(InferenceEffort.low),
    );
  });

  test('summary asks for no opening when there is no prefill', () {
    final data = dataFor([userEntry('hi')])
      ..compaction = (CompactionFrame(tokensBefore: 900, priorSummary: null)
        ..content = const CompactionPromptContent(
          instruction: 'i',
          prefill: '',
          format: 'f',
        ));

    final request = builder.summary(data);

    expect(request.messages, hasLength(2));
    expect((request.messages[1] as InferenceUserMessage).text, endsWith('f'));
  });
}
