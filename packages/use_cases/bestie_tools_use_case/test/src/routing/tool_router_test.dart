import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/job_manager.dart';
import 'package:bestie_tools_use_case/src/routing/tool_router.dart';
import 'package:clock/clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

const _definition = ToolDefinition(
  name: 'search',
  description: 'Searches.',
  parameters: {},
  onProgress: 'Searching',
  onSuccess: 'Searched',
  onError: 'Search failed',
);

final _frozen = Clock.fixed(DateTime.utc(2026, 1, 2));

void main() {
  setUpAll(
    () => registerFallbackValue(
      const JobReport(
        conversationId: 'conversation-1',
        agentId: 'agent-1',
        callId: 'call-1',
        toolName: 'search',
        arguments: <String, Object?>{},
        outcome: JobSucceeded('finished'),
        outstanding: 0,
      ),
    ),
  );

  test('settles a completed job as a terminal success response', () async {
    await withClock(_frozen, () async {
      final requests = StreamController<ToolCallRequest>();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [_Responder((_) async => Job.done('found'))],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });
      final request = _request();

      requests.add(request);

      expect(
        await request.response,
        const ToolCallSucceeded(
          callId: 'call-1',
          toolName: 'search',
          content: 'found',
          elapsedMs: 0,
        ),
      );
    });
  });

  test(
    'coerces arguments before giving the invocation to its responder',
    () async {
      final requests = StreamController<ToolCallRequest>();
      ToolCallInvocation? seen;
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [
          _Responder((invocation) async {
            seen = invocation;
            return Job.done('found');
          }),
        ],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });
      final request = ToolCallRequest(
        const ToolCallDefault(
          id: 'call-1',
          name: 'search',
          arguments: {'limit': '3'},
        ),
        definition: const ToolDefinition(
          name: 'search',
          description: 'Searches.',
          parameters: {
            'type': 'object',
            'properties': {
              'limit': {'type': 'integer'},
            },
          },
          onProgress: 'Searching',
          onSuccess: 'Searched',
          onError: 'Search failed',
        ),
        conversationId: 'conversation-1',
        agentId: 'agent-1',
        outputPath: 'outputs/conversation-1/agent-1/tools/call-1',
        maxOutputChars: defaultMaxToolCallCharacters,
      );

      requests.add(request);
      await request.response;

      expect(seen!.arguments, {'limit': 3});
      expect(seen!.callId, 'call-1');
    },
  );

  test('hands the responder the write path the request names', () async {
    final requests = StreamController<ToolCallRequest>();
    ToolCallInvocation? seen;
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [
        _Responder((invocation) async {
          seen = invocation;
          return Job.done('found');
        }),
      ],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });
    final request = _request();

    requests.add(request);
    await request.response;

    expect(seen!.outputPath, request.outputPath);
  });

  test('fails an unknown tool without invoking a responder', () async {
    await withClock(_frozen, () async {
      final requests = StreamController<ToolCallRequest>();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: const [],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });
      final request = _request();

      requests.add(request);

      expect(
        await request.response,
        const ToolCallFailed(
          callId: 'call-1',
          toolName: 'search',
          message: 'No such tool: search.',
          elapsedMs: 0,
        ),
      );
    });
  });

  test('turns a responder exception into a terminal failure', () async {
    final requests = StreamController<ToolCallRequest>();
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [_Responder((_) => throw StateError('search broke'))],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });
    final request = _request();

    requests.add(request);

    expect(
      (await request.response as ToolCallFailed).message,
      contains('search broke'),
    );
  });

  test('hands a background job back then reports it to its caller', () async {
    await withClock(_frozen, () async {
      final requests = StreamController<ToolCallRequest>();
      final requester = _requesterFor(requests);
      final job = _DeferredJob()..handoff('working');
      final router = ToolRouter(
        requester: requester,
        responders: [_Responder((_) async => job)],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });
      final request = _request();

      requests.add(request);

      expect(
        await request.response,
        const ToolCallInBackground(
          callId: 'call-1',
          toolName: 'search',
          content: 'working',
          elapsedMs: 0,
        ),
      );
      job.complete(const JobSucceeded('finished'));
      await _pump();

      final report =
          verify(() => requester.deliverReport(captureAny())).captured.single
              as JobReport;
      expect(report.callId, 'call-1');
      expect(report.outcome, isA<JobSucceeded>());
    });
  });

  test('stops the job of a call canceled from the other side', () async {
    final requests = StreamController<ToolCallRequest>();
    final job = _DeferredJob();
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [_Responder((_) async => job)],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });
    final request = _request();

    requests.add(request);
    await _pump();

    request.settle(
      const ToolCallCanceled(
        callId: 'call-1',
        toolName: 'search',
        message: 'The tool call was interrupted.',
      ),
    );
    await _pump();

    expect(job.stops, 1);
    job.complete(const JobCanceled('stopped'));
    expect(await request.response, isA<ToolCallCanceled>());
  });

  test('a job that settled before its handoff settles the call once', () async {
    final requests = StreamController<ToolCallRequest>();
    final job = _DeferredJob()
      ..complete(const JobSucceeded('finished'))
      ..handoff('too late');
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [_Responder((_) async => job)],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });
    final request = _request();

    requests.add(request);

    final response = await request.response;
    expect(response, isA<ToolCallSucceeded>());
    expect(response, isNot(isA<ToolCallInBackground>()));
  });

  test('publishes an unsettled job, then drops it once it settles', () async {
    final requests = StreamController<ToolCallRequest>();
    final job = _DeferredJob();
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [_Responder((_) async => job)],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });
    final held = <List<JobEntry>>[];
    final subscription = router.jobs.listen(held.add);
    addTearDown(subscription.cancel);

    requests.add(_request());
    await _pump();
    await _pump();

    expect(held.single.single.call.id, 'call-1');

    job.complete(const JobSucceeded('finished'));
    await _pump();
    await _pump();

    expect(held.last, isEmpty);
  });

  test('stopAllJobs stops held jobs and leaves the router serving', () async {
    final requests = StreamController<ToolCallRequest>();
    final background = _DeferredJob()..handoff('working');
    var served = 0;
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [
        _Responder((_) async => served++ == 0 ? background : Job.done('found')),
      ],
    );
    addTearDown(() async {
      await requests.close();
      await router.dispose();
    });

    final backgrounded = _request();
    requests.add(backgrounded);
    await backgrounded.response;

    router.stopAllJobs();

    expect(background.stops, 1);

    // Unlike dispose, this ends the work and not the router: whatever asked
    // for the stop is still there to make the next call.
    final next = _request(id: 'call-2');
    requests.add(next);

    expect(await next.response, isA<ToolCallSucceeded>());
  });

  test('dispose stops every held job', () async {
    final requests = StreamController<ToolCallRequest>();
    final pending = _DeferredJob();
    final background = _DeferredJob()..handoff('working');
    var served = 0;
    final router = ToolRouter(
      requester: _requesterFor(requests),
      responders: [
        _Responder((_) async => served++ == 0 ? background : pending),
      ],
    );
    addTearDown(requests.close);

    final backgrounded = _request();
    requests.add(backgrounded);
    await backgrounded.response;
    requests.add(_request(id: 'call-2'));
    await _pump();
    await _pump();

    await router.dispose();

    expect(background.stops, 1);
    expect(pending.stops, 1);
  });

  group('output bounds', () {
    test('tells the responder how much room the answer has', () async {
      final requests = StreamController<ToolCallRequest>();
      ToolCallInvocation? seen;
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [
          _Responder((invocation) async {
            seen = invocation;
            return Job.done('found');
          }),
        ],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 640);
      requests.add(request);
      await request.response;

      expect(seen?.maxOutputChars, 640);
    });

    test('refuses a call with no room without running the tool', () async {
      final requests = StreamController<ToolCallRequest>();
      var ran = false;
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [
          _Responder((_) async {
            ran = true;
            return Job.done('found');
          }),
        ],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 0);
      requests.add(request);
      final response = await request.response;

      expect(ran, isFalse);
      expect(response, isA<ToolCallFailed>());
      expect(
        (response as ToolCallFailed).message,
        contains('No context left'),
      );
    });

    test('refuses a call whose room has gone negative', () async {
      final requests = StreamController<ToolCallRequest>();
      var ran = false;
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [
          _Responder((_) async {
            ran = true;
            return Job.done('found');
          }),
        ],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: -120);
      requests.add(request);

      expect(await request.response, isA<ToolCallFailed>());
      expect(ran, isFalse);
    });

    test('fails an answer that outgrew the room it was given', () async {
      final requests = StreamController<ToolCallRequest>();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [_Responder((_) async => Job.done('x' * 41))],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 40);
      requests.add(request);
      final response = await request.response;

      expect(response, isA<ToolCallFailed>());
      expect((response as ToolCallFailed).message, contains('41 characters'));
      expect(response.message, contains('40 allowed'));
    });

    test('passes an answer that exactly fills the room', () async {
      final requests = StreamController<ToolCallRequest>();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [_Responder((_) async => Job.done('x' * 40))],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 40);
      requests.add(request);

      expect(await request.response, isA<ToolCallSucceeded>());
    });

    test('measures failure detail, not just successful content', () async {
      final requests = StreamController<ToolCallRequest>();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [
          _Responder((_) async => Job.failed('nope', content: 'x' * 200)),
        ],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 40);
      requests.add(request);
      final response = await request.response;

      expect(response, isA<ToolCallFailed>());
      expect((response as ToolCallFailed).message, contains('over the 40'));
    });

    test('fails a handoff that outgrew the room it was given', () async {
      final requests = StreamController<ToolCallRequest>();
      final job = _DeferredJob();
      final router = ToolRouter(
        requester: _requesterFor(requests),
        responders: [_Responder((_) async => job)],
      );
      addTearDown(() async {
        await requests.close();
        await router.dispose();
      });

      final request = _request(maxOutputChars: 40);
      requests.add(request);
      await _pump();
      job.handoff('x' * 41);

      expect(await request.response, isA<ToolCallFailed>());
    });
  });
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

class _MockToolRequester extends Mock implements ToolRequester {}

/// A requester whose calls arrive from [requests].
_MockToolRequester _requesterFor(
  StreamController<ToolCallRequest> requests,
) {
  final requester = _MockToolRequester();
  when(() => requester.toolRequests).thenAnswer((_) => requests.stream);
  return requester;
}

ToolCallRequest _request({
  String id = 'call-1',
  int maxOutputChars = defaultMaxToolCallCharacters,
}) => ToolCallRequest(
  ToolCallDefault(id: id, name: 'search', arguments: const {}),
  definition: _definition,
  conversationId: 'conversation-1',
  agentId: 'agent-1',
  outputPath: 'outputs/conversation-1/agent-1/tools/$id',
  maxOutputChars: maxOutputChars,
);

final class _Responder implements ToolResponder {
  _Responder(this._respond);

  final Future<Job> Function(ToolCallInvocation) _respond;

  @override
  ToolDefinitions get definitions => ToolDefinitions([_definition]);

  @override
  Future<Job> respond(ToolCallInvocation invocation) => _respond(invocation);
}

final class _DeferredJob implements Job {
  final _settled = Completer<JobOutcome>();
  final _background = Completer<String>();
  JobOutcome? _outcome;
  int stops = 0;

  @override
  JobOutcome? get outcome => _outcome;

  @override
  Future<String> get inBackground => _background.future;

  @override
  Future<JobOutcome> get settled => _settled.future;

  void handoff(String content) => _background.complete(content);

  void complete(JobOutcome outcome) {
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() => stops++;
}
