import 'dart:async';
import 'dart:convert';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

import '../helpers/scripted_backend.dart';

const _sampling = EngineSampling(temperature: 0.7);
const _system = PromptSystemMessage('You are terse.');
const _toolCallReply =
    'Let me look.\n<tool_call>\n'
    '{"name": "read", "arguments": {"path": "a.txt"}}\n'
    '</tool_call>';

final class _Stack {
  _Stack({
    required Map<SequenceId, List<String>> replies,
    int contextSize = 2048,
  }) : backend = ScriptedSequences(replies: replies) {
    final context = ScriptedContext(
      contextSize: contextSize,
      sequences: backend,
    );
    final allocator = LeaseAllocator(context: context);
    runtime = ScheduledCompletionRuntime(
      allocator: allocator,
      scheduler: BatchingSequenceScheduler(
        sequences: backend,
        allocator: allocator,
      ),
      tokenizer: const ByteTokenizer(),
      profile: ModelProfiles.qwen3,
      defaultSampling: _sampling,
      callIdMinter: CallIdMinter(now: () => DateTime.utc(2026, 2)),
    );
  }

  final ScriptedSequences backend;
  late final ScheduledCompletionRuntime runtime;

  Stream<CompletionEvent> start(
    List<PromptMessage> messages, {
    String? agentId,
    List<PromptTool> tools = const [],
    int? maxTokens,
    List<String> stopSequences = const [],
    EngineSampling sampling = _sampling,
    String reasoningMode = 'off',
  }) => Stream.fromFuture(
    runtime.complete(
      CompletionRequest(
        agentId: agentId,
        messages: messages,
        tools: tools,
        reasoningMode: reasoningMode,
        sampling: sampling,
        maxTokens: maxTokens,
        stopSequences: stopSequences,
      ),
    ),
  ).asyncExpand((started) => (started as CompletionStarted).events);

  String prompt(List<PromptMessage> messages) => ModelProfiles.qwen3.formatter
      .format(messages: messages, tools: const [], reasoningMode: 'off');
}

String _text(List<CompletionEvent> events) => [
  for (final event in events)
    if (event case CompletionTextDelta(:final text)) text,
].join();

CompletionFinished _finished(List<CompletionEvent> events) =>
    events.last as CompletionFinished;

int _commonPrefix(String first, String second) {
  final firstBytes = utf8.encode(first);
  final secondBytes = utf8.encode(second);
  var length = 0;
  while (length < firstBytes.length &&
      length < secondBytes.length &&
      firstBytes[length] == secondBytes[length]) {
    length += 1;
  }
  return length;
}

void main() {
  group('ScheduledCompletionRuntime over the batching scheduler', () {
    test('a follow-up turn reuses the prefix the first turn left', () async {
      final stack = _Stack(
        replies: {
          1: ['Hello there.', 'Fine.'],
        },
      );
      expect(
        await stack.runtime.openPrimary('primary:1'),
        isA<AgentLeaseOpened>().having(
          (opened) => opened.claimedTokens,
          'claimedTokens',
          0,
        ),
      );

      final firstTurn = [_system, const PromptUserMessage('hi')];
      final first = await stack.start(firstTurn, agentId: 'primary:1').toList();
      expect(_text(first), 'Hello there.');
      final firstPrompt = stack.prompt(firstTurn);
      expect(
        _finished(first).usage,
        isA<CompletionUsage>()
            .having((usage) => usage.promptTokens, 'prompt', firstPrompt.length)
            .having((usage) => usage.completionTokens, 'completion', 12)
            .having((usage) => usage.cachedTokens, 'cached', 0),
      );
      expect(_finished(first).reason, CompletionStopReason.stop);
      final stepsAfterFirst = stack.backend.steps.length;

      final secondTurn = [
        ...firstTurn,
        const PromptAssistantMessage(content: 'Hello there.'),
        const PromptUserMessage('how are you?'),
      ];
      final second = await stack
          .start(secondTurn, agentId: 'primary:1')
          .toList();
      final secondPrompt = stack.prompt(secondTurn);
      final reused = _commonPrefix(
        '$firstPrompt${'Hello there.'}',
        secondPrompt,
      );

      expect(_text(second), 'Fine.');
      expect(_finished(second).usage.cachedTokens, reused);
      expect(reused, greaterThan(firstPrompt.length ~/ 2));
      expect(
        stack.backend.prefilledInto(1, afterStep: stepsAfterFirst),
        secondPrompt.length - reused,
      );
      expect(stack.backend.log.whereType<ClearOperation>(), isEmpty);
    });

    test('parallel subagents decode in the same steps', () async {
      final stack = _Stack(
        replies: {
          1: ['one one one'],
          2: ['two two two'],
        },
      );
      await stack.runtime.openSubagent('sub:a');
      await stack.runtime.openSubagent('sub:b');

      final results = await Future.wait([
        stack.start([const PromptUserMessage('a')], agentId: 'sub:a').toList(),
        stack.start([const PromptUserMessage('b')], agentId: 'sub:b').toList(),
      ]);

      expect(_text(results[0]), 'one one one');
      expect(_text(results[1]), 'two two two');
      final shared = stack.backend.steps.where(
        (step) => step.sampledSequences.toSet().containsAll([1, 2]),
      );
      expect(shared.length, greaterThanOrEqualTo(10));
      expect(
        stack.backend.steps.where((step) => step.sequences.length > 1),
        isNotEmpty,
      );
    });

    test('subagents claim an equal share of the context', () async {
      final stack = _Stack(replies: {});

      expect(
        await stack.runtime.openSubagent('sub:a'),
        isA<AgentLeaseOpened>().having(
          (opened) => opened.claimedTokens,
          'claimedTokens',
          512,
        ),
      );
    });

    test('opening an agent twice answers with its existing lease', () async {
      final stack = _Stack(replies: {});
      await stack.runtime.openPrimary('primary:1');

      expect(
        await stack.runtime.openPrimary('primary:1'),
        isA<AgentLeaseOpened>(),
      );
      expect(stack.backend.log.whereType<AcquireOperation>(), hasLength(1));
    });

    test('a second primary is refused for capacity', () async {
      final stack = _Stack(replies: {});
      await stack.runtime.openPrimary('primary:1');

      expect(
        await stack.runtime.openPrimary('primary:2'),
        isA<AgentLeaseNoCapacity>(),
      );
    });

    test('agents past the sequence count are refused for capacity', () async {
      final stack = _Stack(replies: {});
      for (final id in ['primary:1', 'sub:a', 'sub:b', 'sub:c']) {
        expect(
          await (id.startsWith('sub')
              ? stack.runtime.openSubagent(id)
              : stack.runtime.openPrimary(id)),
          isA<AgentLeaseOpened>(),
        );
      }

      expect(
        await stack.runtime.openSubagent('sub:d'),
        isA<AgentLeaseNoCapacity>(),
      );
    });

    test(
      'a subagent cannot claim context the primary already holds',
      () async {
        final stack = _Stack(
          replies: {
            1: ['ok'],
          },
        );
        await stack.runtime.openPrimary('primary:1');
        await stack.start([
          PromptUserMessage('x' * 1700),
        ], agentId: 'primary:1').toList();

        expect(
          await stack.runtime.openSubagent('sub:a'),
          isA<AgentLeaseInsufficientClaim>(),
        );
      },
    );

    test('a prompt larger than the agent can hold is rejected', () async {
      final stack = _Stack(replies: {});
      await stack.runtime.openSubagent('sub:a');

      final started = await stack.runtime.complete(
        CompletionRequest(
          agentId: 'sub:a',
          messages: [PromptUserMessage('x' * 600)],
          reasoningMode: 'off',
          sampling: _sampling,
        ),
      );

      expect(
        started,
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.promptTooLarge,
        ),
      );
    });

    test('cancelling the stream stops decoding and frees the agent', () async {
      final stack = _Stack(
        replies: {
          1: ['x' * 500, 'done'],
        },
      );
      await stack.runtime.openPrimary('primary:1');

      final firstDelta = Completer<void>();
      final subscription = stack
          .start([const PromptUserMessage('go')], agentId: 'primary:1')
          .listen((event) {
            if (event is CompletionTextDelta && !firstDelta.isCompleted) {
              firstDelta.complete();
            }
          });
      await firstDelta.future;
      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final stepsAtCancel = stack.backend.steps.length;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(stack.backend.steps.length, stepsAtCancel);
      expect(stack.backend.residentTokens(1), lessThan(500));

      final next = await stack.start([
        const PromptUserMessage('again'),
      ], agentId: 'primary:1').toList();
      expect(_text(next), 'done');
    });

    test('closing an agent cancels its running completion', () async {
      final stack = _Stack(
        replies: {
          1: ['x' * 500],
        },
      );
      await stack.runtime.openPrimary('primary:1');
      final events = stack.start([
        const PromptUserMessage('go'),
      ], agentId: 'primary:1');
      final collected = events.toList();
      await Future<void>.delayed(Duration.zero);

      expect(await stack.runtime.close('primary:1'), isA<AgentLeaseClosed>());

      expect(
        (await collected).last,
        isA<CompletionFailed>().having(
          (failed) => failed.failure,
          'failure',
          CompletionFailure.cancelled,
        ),
      );
      expect(stack.backend.log.last, isA<ReleaseOperation>());
    });

    test('a request naming no agent borrows a sequence for itself', () async {
      final stack = _Stack(
        replies: {
          1: ['borrowed'],
        },
      );
      final snapshots = <PoolSnapshot>[];
      stack.runtime.poolChanges.listen(snapshots.add);

      final events = await stack.start([
        const PromptUserMessage('hi'),
      ]).toList();

      expect(_text(events), 'borrowed');
      expect(stack.backend.log.first, isA<AcquireOperation>());
      expect(stack.backend.log.last, isA<ReleaseOperation>());
      expect(stack.runtime.pool.agents, isEmpty);
      expect(snapshots.every((snapshot) => snapshot.agents.isEmpty), isTrue);
    });

    test('a tool call ends the completion with a tool-calls stop', () async {
      const tool = PromptTool(
        name: 'read',
        description: 'Reads a file.',
        parameters: {'type': 'object'},
      );
      final stack = _Stack(
        replies: {
          1: [_toolCallReply],
        },
      );
      await stack.runtime.openPrimary('primary:1');

      final events = await stack
          .start(
            [const PromptUserMessage('read a.txt')],
            agentId: 'primary:1',
            tools: [tool],
          )
          .toList();

      expect(
        events.whereType<CompletionToolCalled>().single,
        isA<CompletionToolCalled>()
            .having((call) => call.name, 'name', 'read')
            .having((call) => call.id, 'id', startsWith('call_'))
            .having(
              (call) => jsonDecode(call.argumentsJson),
              'arguments',
              {'path': 'a.txt'},
            ),
      );
      expect(_finished(events).reason, CompletionStopReason.toolCalls);
    });

    test('max tokens ends the completion with a length stop', () async {
      final stack = _Stack(
        replies: {
          1: ['a long answer'],
        },
      );
      await stack.runtime.openPrimary('primary:1');

      final events = await stack
          .start(
            [const PromptUserMessage('hi')],
            agentId: 'primary:1',
            maxTokens: 3,
          )
          .toList();

      expect(_text(events), 'a l');
      expect(_finished(events).reason, CompletionStopReason.length);
    });

    test('new sampling rebuilds the sequence before the next turn', () async {
      final stack = _Stack(
        replies: {
          1: ['one', 'two'],
        },
      );
      await stack.runtime.openPrimary('primary:1');
      await stack.start([
        const PromptUserMessage('a'),
      ], agentId: 'primary:1').toList();

      final events = await stack
          .start(
            [const PromptUserMessage('a')],
            agentId: 'primary:1',
            sampling: const EngineSampling(temperature: 0.1),
          )
          .toList();

      expect(_text(events), 'two');
      expect(stack.backend.log.whereType<SetSamplingOperation>(), hasLength(1));
      expect(stack.backend.log.whereType<ClearOperation>(), isEmpty);
      expect(
        _finished(events).usage.cachedTokens,
        stack.prompt([const PromptUserMessage('a')]).length - 1,
      );
    });

    test('a stop sequence ends the completion before it', () async {
      final stack = _Stack(
        replies: {
          1: ['keep this. STOP and not this'],
        },
      );
      await stack.runtime.openPrimary('primary:1');

      final events = await stack
          .start(
            [const PromptUserMessage('hi')],
            agentId: 'primary:1',
            stopSequences: const ['STOP'],
          )
          .toList();

      expect(_text(events), 'keep this. ');
      expect(_finished(events).reason, CompletionStopReason.stop);
    });

    test('a borrowed sequence counts its claim until it settles', () async {
      final stack = _Stack(
        replies: {
          1: ['lent'],
        },
      );
      final snapshots = <PoolSnapshot>[];
      stack.runtime.poolChanges.listen(snapshots.add);

      final events = stack.start([const PromptUserMessage('hi')]);

      expect(stack.runtime.pool.borrowedTokens, 512);
      await events.toList();
      expect(stack.runtime.pool.borrowedTokens, 0);
      expect(
        [for (final snapshot in snapshots) snapshot.borrowedTokens],
        [512, 0],
      );
    });

    test('the pool lists every leased agent and its resident tokens', () async {
      final stack = _Stack(
        replies: {
          1: ['hey'],
        },
      );
      final snapshots = <PoolSnapshot>[];
      stack.runtime.poolChanges.listen(snapshots.add);
      await stack.runtime.openPrimary('primary:1');
      await stack.runtime.openSubagent('sub:a');
      await stack.start([
        const PromptUserMessage('hi'),
      ], agentId: 'primary:1').toList();
      await Future<void>.delayed(Duration.zero);

      final pool = stack.runtime.pool;
      expect(pool.contextSize, 2048);
      expect(pool.maxAgents, 4);
      expect(
        [for (final agent in pool.agents) '${agent.id}=${agent.claimedTokens}'],
        ['primary:1=0', 'sub:a=512'],
      );
      expect(pool.agents.first, isA<PrimaryPoolLease>());
      expect(pool.agents.last, isA<SubagentPoolLease>());
      expect(pool.agents.first.usedTokens, stack.backend.residentTokens(1));
      expect(pool.agents.first.usedTokens, greaterThan(0));
      expect(snapshots, hasLength(3));
    });

    test('a request naming an agent without a lease is rejected', () async {
      final stack = _Stack(replies: {});

      expect(
        await stack.runtime.complete(
          const CompletionRequest(
            agentId: 'ghost',
            messages: [PromptUserMessage('hi')],
            reasoningMode: 'off',
            sampling: _sampling,
          ),
        ),
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.unknownAgent,
        ),
      );
    });

    test('an agent runs one completion at a time', () async {
      final stack = _Stack(
        replies: {
          1: ['first'],
        },
      );
      await stack.runtime.openPrimary('primary:1');
      final running = stack.start([
        const PromptUserMessage('hi'),
      ], agentId: 'primary:1').toList();

      expect(
        await stack.runtime.complete(
          const CompletionRequest(
            agentId: 'primary:1',
            messages: [PromptUserMessage('again')],
            reasoningMode: 'off',
            sampling: _sampling,
          ),
        ),
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.agentBusy,
        ),
      );
      expect(_text(await running), 'first');
    });

    test(
      'a request naming no agent is refused when no sequence is free',
      () async {
        final stack = _Stack(replies: {});
        for (final id in ['sub:a', 'sub:b', 'sub:c', 'sub:d']) {
          await stack.runtime.openSubagent(id);
        }

        expect(
          await stack.runtime.complete(
            const CompletionRequest(
              messages: [PromptUserMessage('hi')],
              reasoningMode: 'off',
              sampling: _sampling,
            ),
          ),
          isA<CompletionRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            CompletionRejection.noCapacity,
          ),
        );
      },
    );

    test('closing an agent without a lease answers unknown', () async {
      final stack = _Stack(replies: {});

      expect(await stack.runtime.close('ghost'), isA<AgentLeaseUnknown>());
    });

    test('reasoning streams apart from the answer', () async {
      final stack = _Stack(
        replies: {
          1: ['<think>\nhmm\n</think>\n\nanswer'],
        },
      );
      await stack.runtime.openPrimary('primary:1');

      final events = await stack
          .start(
            [const PromptUserMessage('hi')],
            agentId: 'primary:1',
            reasoningMode: 'on',
          )
          .toList();

      expect(
        [
          for (final event in events)
            if (event case CompletionReasoningDelta(:final text)) text,
        ].join().trim(),
        'hmm',
      );
      expect(_text(events).trim(), 'answer');
    });

    test('dispose cancels borrowed completions and refuses new ones', () async {
      final stack = _Stack(
        replies: {
          1: ['x' * 500],
        },
      );
      final collected = stack.start([const PromptUserMessage('go')]).toList();
      await Future<void>.delayed(Duration.zero);

      await stack.runtime.dispose();
      await stack.runtime.dispose();

      expect(
        (await collected).last,
        isA<CompletionFailed>().having(
          (failed) => failed.failure,
          'failure',
          CompletionFailure.cancelled,
        ),
      );
      expect(
        await stack.runtime.complete(
          const CompletionRequest(
            messages: [PromptUserMessage('hi')],
            reasoningMode: 'off',
            sampling: _sampling,
          ),
        ),
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.disposed,
        ),
      );
    });

    test('dispose releases subagents before the primary', () async {
      final stack = _Stack(replies: {});
      await stack.runtime.openPrimary('primary:1');
      await stack.runtime.openSubagent('sub:a');

      await stack.runtime.dispose();

      expect(
        [
          for (final operation
              in stack.backend.log.whereType<ReleaseOperation>())
            operation.sequenceId,
        ],
        [2, 1],
      );
      expect(
        await stack.runtime.openPrimary('primary:1'),
        isA<AgentLeaseFailed>(),
      );
    });
  });
}
