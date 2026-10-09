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

ToolWorkReady _readied(String callId) => ToolWorkReady(
  ToolWorkRequest(
    ToolCallInvocation(
      conversationId: 'conversation',
      agentId: 'agent',
      callId: callId,
      toolName: 'web_search',
      outputPath: 'output/$callId',
      maxOutputChars: 4000,
      arguments: const {},
    ),
  ),
);

/// A call that is ready to run as soon as it is queued.
Future<ToolWorkStart> _ready(String callId) => Future.value(_readied(callId));

/// Lets the pool's own futures run before the test looks at what it did.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Starts a call whose job the test does not need — it is only there to take
/// up a slot or a place in the queue.
void occupy(ToolWorkerPool pool, String callId, {String? lane}) =>
    pool.run(_ready(callId), lane: lane);

void main() {
  late List<_FakeWorker> spawned;
  late int spawnCount;
  String? spawnFailure;
  Completer<void>? spawnGate;

  setUp(() {
    spawned = [];
    spawnCount = 0;
    spawnFailure = null;
    spawnGate = null;
  });

  Future<ToolWorkerCreateResult> spawnWorker() async {
    spawnCount++;
    final failure = spawnFailure;
    await spawnGate?.future;
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

      final job = pool.run(_ready('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('found it'));

      expect((await job.settled as JobSucceeded).content, 'found it');
      expect(spawned.single.ran.single.callId, 'a');
    });

    test('reuses a warm worker rather than spawning another', () async {
      final pool = poolOf(2);

      final first = pool.run(_ready('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('one'));
      await first.settled;

      final second = pool.run(_ready('b'));
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

      final job = pool.run(_ready('a'));

      expect(
        (await job.settled as JobFailed).message,
        contains('no isolates left'),
      );
    });
  });

  group('queueing', () {
    test('holds calls beyond the size until a slot frees', () async {
      final pool = poolOf(1);

      final first = pool.run(_ready('a'));
      final queued = pool.run(_ready('b'));
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

      final first = pool.run(_ready('a'));
      final second = pool.run(_ready('b'));
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

      final first = pool.run(_ready('a'));
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

      final first = pool.run(_ready('a'));
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
      final queued = pool.run(_ready('b'));
      await settle();

      queued.stop();

      expect(await queued.settled, isA<JobCanceled>());
      spawned.single.answer(const JobSucceeded('one'));
      await settle();
      expect(spawned.single.ran.map((call) => call.callId), ['a']);
    });

    test('abandons the worker running a stopped call', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));
      await settle();

      job.stop();

      expect(await job.settled, isA<JobCanceled>());
      expect(spawned.single.terminated, isTrue);
    });

    test('keeps the answer it already gave when the worker replies', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));
      await settle();
      job.stop();
      spawned.single.answer(const JobSucceeded('too late'));
      await settle();

      expect(await job.settled, isA<JobCanceled>());
    });

    test('replaces the worker it abandoned', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));
      await settle();
      job.stop();
      occupy(pool, 'b');
      await settle();

      expect(spawnCount, 2);
      expect(spawned.last.ran.single.callId, 'b');
    });

    test('keeps a worker that was still arriving when it stopped', () async {
      final pool = poolOf(1);
      spawnGate = Completer<void>();

      final job = pool.run(_ready('a'));
      await settle();
      job.stop();
      spawnGate!.complete();
      await settle();
      occupy(pool, 'b');
      await settle();

      expect(spawnCount, 1);
      expect(spawned.single.ran.single.callId, 'b');
    });

    test('does nothing the second time it is asked', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));
      await settle();
      job
        ..stop()
        ..stop();

      expect(spawned.single.terminated, isTrue);
    });

    test('leaves a job that already settled alone', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));
      await settle();
      spawned.single.answer(const JobSucceeded('done'));
      await job.settled;

      job.stop();

      expect((await job.settled as JobSucceeded).content, 'done');
    });

    test('never hands the call back to run on in the background', () async {
      final pool = poolOf(1);

      final job = pool.run(_ready('a'));

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

      final running = pool.run(_ready('a'));
      final queued = pool.run(_ready('b'));
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

      final job = pool.run(_ready('a'));

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
      spawnGate = Completer<void>();

      occupy(pool, 'a');
      await settle();
      spawnGate!.complete();
      final closing = pool.close();
      await settle();
      await closing;

      expect(spawned.single.terminated, isTrue);
    });
  });

  group('lanes', () {
    /// Every call any worker has been handed, in the order each was handed
    /// one.
    List<String> ran() => [
      for (final worker in spawned) ...worker.ran.map((call) => call.callId),
    ];

    /// The worker whose latest call is [callId].
    _FakeWorker runnerOf(String callId) =>
        spawned.singleWhere((worker) => worker.ran.last.callId == callId);

    test('runs a call only once the one ahead in its lane answers', () async {
      final pool = poolOf(2);

      final first = pool.run(_ready('a'), lane: '/work/a.md');
      final second = pool.run(_ready('b'), lane: '/work/a.md');
      await settle();

      expect(ran(), ['a']);

      runnerOf('a').answer(const JobSucceeded('one'));
      await first.settled;
      await settle();

      expect(ran(), ['a', 'b']);
      runnerOf('b').answer(const JobSucceeded('two'));
      expect((await second.settled as JobSucceeded).content, 'two');
    });

    test('runs a lane strictly in the order its calls arrived', () async {
      final pool = poolOf(3);

      for (final callId in ['a', 'b', 'c']) {
        occupy(pool, callId, lane: '/work/a.md');
      }
      await settle();
      expect(ran(), ['a']);

      runnerOf('a').answer(const JobSucceeded('one'));
      await settle();
      expect(ran(), ['a', 'b']);

      runnerOf('b').answer(const JobSucceeded('two'));
      await settle();
      expect(ran(), ['a', 'b', 'c']);
    });

    test('runs calls in different lanes, or in none, side by side', () async {
      final pool = poolOf(3);

      occupy(pool, 'a', lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/b.md');
      occupy(pool, 'c');
      await settle();

      expect(ran(), unorderedEquals(['a', 'b', 'c']));
    });

    test('lets a later call in another lane past a held one', () async {
      final pool = poolOf(2);

      occupy(pool, 'a', lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/a.md');
      occupy(pool, 'c', lane: '/work/c.md');
      await settle();

      expect(ran(), unorderedEquals(['a', 'c']));
    });

    test('holds the lane for a call still being prepared', () async {
      final pool = poolOf(3);
      final preparing = Completer<ToolWorkStart>();

      final first = pool.run(preparing.future, lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/a.md');
      occupy(pool, 'c', lane: '/work/c.md');
      await settle();

      expect(ran(), ['c']);

      preparing.complete(_readied('a'));
      await settle();
      expect(ran(), unorderedEquals(['c', 'a']));

      runnerOf('a').answer(const JobSucceeded('one'));
      await first.settled;
      await settle();
      expect(ran(), contains('b'));
    });

    test('frees the lane when a call is refused before it runs', () async {
      final pool = poolOf(1);

      final refused = pool.run(
        Future.value(const ToolWorkRefused('no seatbelt')),
        lane: '/work/a.md',
      );
      occupy(pool, 'b', lane: '/work/a.md');

      expect((await refused.settled as JobFailed).message, 'no seatbelt');
      await settle();
      expect(ran(), ['b']);
      expect(spawnCount, 1);
    });

    test('fails a call whose preparation threw, freeing its lane', () async {
      final pool = poolOf(1);

      final broken = pool.run(
        Future.error(StateError('sandbox exploded')),
        lane: '/work/a.md',
      );
      occupy(pool, 'b', lane: '/work/a.md');

      expect(
        (await broken.settled as JobFailed).message,
        contains('sandbox exploded'),
      );
      await settle();
      expect(ran(), ['b']);
    });

    test('frees the lane when the running call ahead is stopped', () async {
      final pool = poolOf(2);

      final first = pool.run(_ready('a'), lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/a.md');
      await settle();

      first.stop();
      await settle();

      expect(ran(), ['a', 'b']);
    });

    test('lets the lane skip a queued call that was stopped', () async {
      final pool = poolOf(2);

      final first = pool.run(_ready('a'), lane: '/work/a.md');
      final skipped = pool.run(_ready('b'), lane: '/work/a.md');
      occupy(pool, 'c', lane: '/work/a.md');
      await settle();

      skipped.stop();
      runnerOf('a').answer(const JobSucceeded('one'));
      await first.settled;
      await settle();

      expect(ran(), ['a', 'c']);
    });

    test('holds the lane while a worker is on its way', () async {
      final pool = poolOf(2);
      spawnGate = Completer<void>();

      occupy(pool, 'a', lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/a.md');
      await settle();

      expect(spawnCount, 1);

      spawnGate!.complete();
      await settle();
      expect(ran(), ['a']);
    });

    test('frees the lane when no worker can be had for it', () async {
      final pool = poolOf(2);
      spawnGate = Completer<void>();
      spawnFailure = 'no isolates left';

      final first = pool.run(_ready('a'), lane: '/work/a.md');
      occupy(pool, 'b', lane: '/work/a.md');
      await settle();
      spawnFailure = null;
      spawnGate!.complete();

      expect(
        (await first.settled as JobFailed).message,
        contains('no isolates left'),
      );
      await settle();
      expect(ran(), ['b']);
    });

    test(
      'ignores a preparation that finishes after its call stopped',
      () async {
        final pool = poolOf(1);
        final preparing = Completer<ToolWorkStart>();

        pool.run(preparing.future, lane: '/work/a.md').stop();
        preparing.complete(_readied('a'));
        await settle();

        expect(spawnCount, 0);
      },
    );

    test('cancels a call still being prepared when it closes', () async {
      final pool = poolOf(1);
      final preparing = Completer<ToolWorkStart>();

      final job = pool.run(preparing.future, lane: '/work/a.md');
      await pool.close();
      preparing.complete(_readied('a'));
      await settle();

      expect(await job.settled, isA<JobCanceled>());
      expect(spawnCount, 0);
    });
  });
}
