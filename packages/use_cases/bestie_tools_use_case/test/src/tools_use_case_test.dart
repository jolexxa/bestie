import 'dart:async';

import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockToolRequester extends Mock implements ToolRequester {}

const _search = ToolDefinition(
  name: 'search',
  description: 'Searches.',
  parameters: {},
  onProgress: 'Searching',
  onSuccess: 'Searched',
  onError: 'Search failed',
);

const _read = ToolDefinition(
  name: 'read',
  description: 'Reads.',
  parameters: {},
  onProgress: 'Reading',
  onSuccess: 'Read',
  onError: 'Read failed',
);

void main() {
  late StreamController<ToolCallRequest> requests;
  late _MockToolRequester agents;

  setUp(() {
    requests = StreamController<ToolCallRequest>();
    agents = _MockToolRequester();
    when(() => agents.toolRequests).thenAnswer((_) => requests.stream);
  });

  tearDown(() => requests.close());

  ToolsUseCase useCaseWith(List<ToolResponder> responders) {
    final useCase = ToolsUseCase(agents: agents, responders: responders);
    addTearDown(useCase.dispose);
    return useCase;
  }

  test('gives a call to the feature that offers that tool', () async {
    final searcher = _Responder(_search, (_) async => Job.done('found'));
    final reader = _Responder(_read, (_) async => Job.done('read'));
    useCaseWith([searcher, reader]);

    final request = _request(_read);
    requests.add(request);
    await request.response;

    expect(reader.calls, 1);
    expect(searcher.calls, 0);
  });

  test('counts a job that outlives the call it came from', () async {
    final job = _BackgroundJob();
    final useCase = useCaseWith([_Responder(_search, (_) async => job)]);
    final counts = <int>[];
    final subscription = useCase.activeJobs.listen(counts.add);
    addTearDown(subscription.cancel);

    final request = _request(_search);
    requests.add(request);
    await request.response;

    expect(useCase.activeJobCount, 1);
    expect(counts, [1]);

    job.complete(const JobSucceeded('finished'));
    await _pump();
    await _pump();

    expect(useCase.activeJobCount, 0);
    expect(counts, [1, 0]);
  });

  test('stopJobs stops what is held and keeps serving the next call', () async {
    final held = _BackgroundJob();
    var served = 0;
    final useCase = useCaseWith([
      _Responder(
        _search,
        (_) async => served++ == 0 ? held : Job.done('found'),
      ),
    ]);

    final backgrounded = _request(_search);
    requests.add(backgrounded);
    await backgrounded.response;

    useCase.stopJobs();

    expect(held.stops, 1);

    // Unlike dispose, this ends the work and not the feature: whatever asked
    // for the stop is still there to make the next call.
    final next = _request(_search, id: 'call-2');
    requests.add(next);

    expect(await next.response, isA<ToolCallSucceeded>());
  });

  test('contributes a stop-jobs command gated on active jobs', () async {
    final job = _BackgroundJob();
    final useCase = useCaseWith([_Responder(_search, (_) async => job)]);
    final command = useCase.commands.single;
    expect(command.id, 'tools.stopJobs');
    expect(command.next(const Answers.empty()), isNull);

    final gates = <Availability>[];
    final subscription = command.availability.listen(gates.add);
    addTearDown(subscription.cancel);
    await _pump();
    expect(gates.single, isA<Unavailable>());
    expect((gates.single as Unavailable).reason, 'no active jobs');

    expect(await command.invoke(const Answers.empty()), isA<CommandRejected>());

    final request = _request(_search);
    requests.add(request);
    await request.response;
    await _pump();
    expect(gates.last, isA<Available>());

    // A listener arriving late is seeded with the current state.
    final lateGates = <Availability>[];
    final lateSubscription = command.availability.listen(lateGates.add);
    addTearDown(lateSubscription.cancel);
    await _pump();
    expect(lateGates.first, isA<Available>());

    expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
    expect(job.stops, 1);
  });

  test('dispose stops every job it still holds', () async {
    final job = _BackgroundJob();
    final useCase = ToolsUseCase(
      agents: agents,
      responders: [_Responder(_search, (_) async => job)],
    );

    final request = _request(_search);
    requests.add(request);
    await request.response;

    await useCase.dispose();

    expect(job.stops, 1);
  });
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

ToolCallRequest _request(ToolDefinition definition, {String id = 'call-1'}) =>
    ToolCallRequest(
      ToolCallDefault(id: id, name: definition.name, arguments: const {}),
      definition: definition,
      conversationId: 'conversation-1',
      agentId: 'agent-1',
      outputPath: 'outputs/conversation-1/agent-1/tools/$id',
      maxOutputChars: 4000,
    );

final class _Responder implements ToolResponder {
  _Responder(this._definition, this._respond);

  final ToolDefinition _definition;
  final Future<Job> Function(ToolCallInvocation) _respond;

  int calls = 0;

  @override
  ToolDefinitions get definitions => ToolDefinitions([_definition]);

  @override
  Future<Job> respond(ToolCallInvocation invocation) {
    calls++;
    return _respond(invocation);
  }
}

/// A job that goes to the background on creation and settles when told, so a
/// test can hold it across the call it came from.
final class _BackgroundJob implements Job {
  _BackgroundJob() {
    _background.complete('working');
  }

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

  void complete(JobOutcome outcome) {
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() => stops++;
}
