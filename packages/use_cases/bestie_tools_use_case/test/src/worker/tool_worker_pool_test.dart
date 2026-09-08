import 'dart:async';

import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// A worker whose calls settle only when the test says so.
final class _FakeWorker implements ToolWorker {
  _FakeWorker(this.label);

  final String label;
  final List<ToolCallInvocation> ran = [];
  final List<Completer<JobOutcome>> answers = [];
  bool terminated = false;

  @override
  Future<JobOutcome> run(ToolWorkRequest request) {
    ran.add(request.invocation);
    final answer = Completer<JobOutcome>();
    answers.add(answer);
    return answer.future;
  }

  /// Settles the oldest unanswered call.
  void answer(JobOutcome outcome) {
    answers.removeAt(0).complete(outcome);
  }

  @override
  Future<void> terminate() async {
    terminated = true;
  }
}

ToolWorkRequest _invocation(String callId) => ToolWorkRequest(
  ToolCallInvocation(
    conversationId: 'conversation',
    agentId: 'agent',
    callId: callId,
    toolName: 'web_search',
    outputPath: 'output/$callId',
    maxOutputChars: 4000,
    arguments: const {},
  ),
);

/// Lets the pool's own futures run before the test looks at what it did.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Starts a call whose job the test does not need — it is only there to take
/// up a slot or a place in the queue.
void occupy(ToolWorkerPool pool, String callId) =>
    pool.run(_invocation(callId));

void main() {
  late List<_FakeWorker> spawned;
  late int spawnCount;
  String? spawnFailure;

  setUp(() {
    spawned = [];
    spawnCount = 0;
    spawnFailure = null;
  });

  Future<ToolWorkerCreateResult> spawnWorker() async {
    spawnCount++;
    final failure = spawnFailure;
    if (failure != null) return ToolWorkerCreateFailed(failure);
    final worker = _FakeWorker('worker-$spawnCount');
    spawned.add(worker);
    return ToolWorkerCreated(worker);
  }

  ToolWorkerPool poolOf(int size) =>
      ToolWorkerPool(spawnWorker: spawnWorker, size: size);

  group('running a call', () {
    test('settles the job with what the worker answered', () async {
      final pool = poolOf(2);

      final job = pool.run(_invocation('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('found it'));

      expect((await job.settled as JobSucceeded).content, 'found it');
      expect(spawned.single.ran.single.callId, 'a');
    });

    test('reuses a warm worker rather than spawning another', () async {
      final pool = poolOf(2);

      final first = pool.run(_invocation('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('one'));
      await first.settled;

      final second = pool.run(_invocation('b'));
      await settle();
      spawned.single.answer(const JobSucceeded('two'));
      await second.settled;

      expect(spawnCount, 1);
      expect(spawned.single.ran.map((call) => call.callId), ['a', 'b']);
    });

    test('spawns a second worker rather than waiting on a busy one', () async {
      final pool = poolOf(2);

      occupy(pool, 'a');
      occupy(pool, 'b');
      await settle();

      expect(spawned, hasLength(2));
    });

    test('fails only the call that could not get a worker', () async {
      final pool = poolOf(1);
      spawnFailure = 'no isolates left';

      final job = pool.run(_invocation('a'));

      expect(
        (await job.settled as JobFailed).message,
        contains('no isolates left'),
      );
    });
  });

  group('queueing', () {
    test('holds calls beyond the size until a slot frees', () async {
      final pool = poolOf(1);

      final first = pool.run(_invocation('a'));
      final queued = pool.run(_invocation('b'));
      await settle();

      expect(spawnCount, 1);
      expect(spawned.single.ran, hasLength(1));

      spawned.single.answer(const JobSucceeded('one'));
      await first.settled;
      await settle();

      expect(spawned.single.ran.map((call) => call.callId), ['a', 'b']);

      spawned.single.answer(const JobSucceeded('two'));
      expect((await queued.settled as JobSucceeded).content, 'two');
    });

    test('serves waiting calls in the order they arrived', () async {
      final pool = poolOf(1);

      occupy(pool, 'a');
      occupy(pool, 'b');
      occupy(pool, 'c');
      await settle();

      final worker = spawned.single..answer(const JobSucceeded('one'));
      await settle();
      worker.answer(const JobSucceeded('two'));
      await settle();

      expect(worker.ran.map((call) => call.callId), ['a', 'b', 'c']);
    });
  });

  group('resizing', () {
    test('lets a waiting call run as soon as there is room', () async {
      final pool = poolOf(1);

      occupy(pool, 'a');
      occupy(pool, 'b');
      await settle();
      expect(spawnCount, 1);

      pool.size = 2;
      await settle();

      expect(spawned, hasLength(2));
      expect(spawned[1].ran.single.callId, 'b');
    });

    test('releases warm workers it is no longer allowed to hold', () async {
      final pool = poolOf(2);

      final first = pool.run(_invocation('a'));
      final second = pool.run(_invocation('b'));
      await settle();
      for (final worker in spawned) {
        worker.answer(const JobSucceeded('done'));
      }
      await first.settled;
      await second.settled;
      await settle();

      pool.size = 1;

      expect(spawned.where((worker) => worker.terminated), hasLength(1));
    });

    test('never interrupts work already running', () async {
      final pool = poolOf(2);

      final first = pool.run(_invocation('a'));
      occupy(pool, 'b');
      await settle();

      pool.size = 1;

      expect(spawned.every((worker) => !worker.terminated), isTrue);

      spawned[0].answer(const JobSucceeded('finished anyway'));
      expect(
        (await first.settled as JobSucceeded).content,
        'finished anyway',
      );
    });

    test('retires a worker returning into a pool that shrank', () async {
      final pool = poolOf(2);

      final first = pool.run(_invocation('a'));
      occupy(pool, 'b');
      await settle();
      pool.size = 1;

      spawned[0].answer(const JobSucceeded('done'));
      await first.settled;
      await settle();

      expect(spawned[0].terminated, isTrue);
    });

    test('ignores a resize to the size it already had', () async {
      final pool = poolOf(2)..size = 2;

      expect(pool.size, 2);
    });
  });

  group('stopping', () {
    test('cancels a queued call without ever running it', () async {
      final pool = poolOf(1);

      occupy(pool, 'a');
      final queued = pool.run(_invocation('b'));
      await settle();

      queued.stop();

      expect(await queued.settled, isA<JobCanceled>());
      spawned.single.answer(const JobSucceeded('one'));
      await settle();
      expect(spawned.single.ran.map((call) => call.callId), ['a']);
    });

    test('abandons the worker running a stopped call', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));
      await settle();

      job.stop();

      expect(await job.settled, isA<JobCanceled>());
      expect(spawned.single.terminated, isTrue);
    });

    test('keeps the answer it already gave when the worker replies', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));
      await settle();
      job.stop();
      spawned.single.answer(const JobSucceeded('too late'));
      await settle();

      expect(await job.settled, isA<JobCanceled>());
    });

    test('replaces the worker it abandoned', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));
      await settle();
      job.stop();
      occupy(pool, 'b');
      await settle();

      expect(spawnCount, 2);
      expect(spawned.last.ran.single.callId, 'b');
    });

    test('keeps a worker that was still arriving when it stopped', () async {
      final pool = poolOf(1);

      pool.run(_invocation('a')).stop();
      await settle();
      occupy(pool, 'b');
      await settle();

      expect(spawnCount, 1);
      expect(spawned.single.ran.single.callId, 'b');
    });

    test('does nothing the second time it is asked', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));
      await settle();
      job
        ..stop()
        ..stop();

      expect(spawned.single.terminated, isTrue);
    });

    test('leaves a job that already settled alone', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('done'));
      await job.settled;

      job.stop();

      expect((await job.settled as JobSucceeded).content, 'done');
    });

    test('never hands the call back to run on in the background', () async {
      final pool = poolOf(1);

      final job = pool.run(_invocation('a'));

      expect(
        job.inBackground.timeout(
          const Duration(milliseconds: 10),
          onTimeout: () => 'still waiting',
        ),
        completion('still waiting'),
      );
    });
  });

  group('closing', () {
    test('cancels everything queued and running', () async {
      final pool = poolOf(1);

      final running = pool.run(_invocation('a'));
      final queued = pool.run(_invocation('b'));
      await settle();

      await pool.close();

      expect(await running.settled, isA<JobCanceled>());
      expect(await queued.settled, isA<JobCanceled>());
    });

    test('terminates every worker it holds', () async {
      final pool = poolOf(2);

      occupy(pool, 'a');
      occupy(pool, 'b');
      await settle();

      await pool.close();

      expect(spawned.every((worker) => worker.terminated), isTrue);
    });

    test('refuses calls made after it', () async {
      final pool = poolOf(1);
      await pool.close();

      final job = pool.run(_invocation('a'));

      expect(
        (await job.settled as JobFailed).message,
        contains('shutting down'),
      );
      expect(spawnCount, 0);
    });

    test('is safe to ask twice', () async {
      final pool = poolOf(1);

      await pool.close();
      await pool.close();

      expect(spawnCount, 0);
    });

    test('retires a worker that arrives after it', () async {
      final pool = poolOf(1);

      occupy(pool, 'a');
      final closing = pool.close();
      await settle();
      await closing;

      expect(spawned.single.terminated, isTrue);
    });
  });
}
