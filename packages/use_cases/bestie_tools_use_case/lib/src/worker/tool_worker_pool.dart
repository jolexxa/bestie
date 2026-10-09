import 'dart:async';
import 'dart:collection';

import 'package:bestie_tools_use_case/src/utility_tools_use_case.dart';
import 'package:bestie_tools_use_case/src/worker/tool_work_request.dart';
import 'package:bestie_tools_use_case/src/worker/tool_worker.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// A bounded number of concurrency slots for tool calls, with a queue in front.
///
/// Calls that share a lane run one at a time, in the order they were queued;
/// calls in different lanes, or in none, run side by side.
@PartOf(UtilityToolsUseCase)
class ToolWorkerPool {
  ToolWorkerPool({
    required ToolWorkerFactory spawnWorker,
    required int size,
  }) : _spawnWorker = spawnWorker,
       _size = size;

  final ToolWorkerFactory _spawnWorker;
  final List<ToolWorker> _idle = [];
  final Set<ToolWorker> _busy = {};
  final Queue<_PendingCall> _waiting = Queue<_PendingCall>();
  final Set<_PendingCall> _running = {};

  int _size;
  int _spawning = 0;
  bool _closed = false;

  /// How many calls may run at once.
  int get size => _size;

  /// Resizes the pool. Growing lets waiting calls spawn into the new room;
  /// shrinking releases idle workers now and retires busy ones as they return,
  /// so work already running is never interrupted by a settings change.
  set size(int value) {
    if (value == _size) return;
    _size = value;
    while (_idle.isNotEmpty && _liveCount > _size) {
      unawaited(_idle.removeLast().terminate());
    }
    _pump();
  }

  /// Workers alive or on their way, which is what [size] bounds.
  int get _liveCount => _idle.length + _busy.length + _spawning;

  /// Queues a call in [lane] now, to run once [start] has prepared it, and
  /// hands back the job that will settle with it.
  Job run(Future<ToolWorkStart> start, {String? lane}) {
    if (_closed) {
      return Job.failed('The tool system is shutting down.');
    }
    final pending = _PendingCall(lane, _stop);
    _waiting.add(pending);
    unawaited(
      start.then(
        (started) => _started(pending, started),
        onError: (Object error) => _refuse(pending, '$error'),
      ),
    );
    return pending.job;
  }

  /// Stops every worker and answers everything still outstanding.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    const canceled = JobCanceled('The tool system shut down.');
    for (final pending in [..._waiting, ..._running]) {
      pending.job.complete(canceled);
    }
    _waiting.clear();
    _running.clear();

    final workers = [..._idle, ..._busy];
    _idle.clear();
    _busy.clear();
    await Future.wait(workers.map((worker) => worker.terminate()));
  }

  void _started(_PendingCall pending, ToolWorkStart start) {
    switch (start) {
      case ToolWorkReady(:final request):
        pending.request = request;
        _pump();
      case ToolWorkRefused(:final message):
        _refuse(pending, message);
    }
  }

  /// Answers a call that will never run, freeing its place in its lane.
  void _refuse(_PendingCall pending, String message) {
    if (pending.isSettled) return;
    _waiting.remove(pending);
    pending.job.complete(JobFailed(message));
    _pump();
  }

  /// Gives ready calls a worker for as long as there are both, skipping any
  /// whose lane an earlier call still holds.
  void _pump() {
    if (_closed) return;
    final heldLanes = {for (final call in _running) ?call.lane};
    for (final pending in [..._waiting]) {
      final lane = pending.lane;
      final blocked = lane != null && !heldLanes.add(lane);
      final request = pending.request;
      if (blocked || request == null) continue;
      if (_idle.isEmpty && _liveCount >= _size) return;

      _waiting.remove(pending);
      _running.add(pending);
      if (_idle.isNotEmpty) {
        _dispatch(_idle.removeLast(), pending, request);
      } else {
        unawaited(_spawnFor(pending, request));
      }
    }
  }

  Future<void> _spawnFor(_PendingCall pending, ToolWorkRequest request) async {
    _spawning++;
    final result = await _spawnWorker();
    _spawning--;

    switch (result) {
      case ToolWorkerCreated(:final worker):
        if (pending.isSettled || _closed) {
          _release(worker);
          return;
        }
        _dispatch(worker, pending, request);
      case ToolWorkerCreateFailed(:final message):
        _running.remove(pending);
        pending.job.complete(
          JobFailed('Could not start a tool worker: $message'),
        );
        _pump();
    }
  }

  /// Only ever reached with a call still waiting on an answer: a stopped one
  /// leaves the queue before it settles, and the spawn path checks first.
  void _dispatch(
    ToolWorker worker,
    _PendingCall pending,
    ToolWorkRequest request,
  ) {
    _busy.add(worker);
    pending.worker = worker;
    unawaited(
      worker.run(request).then((outcome) {
        _running.remove(pending);
        // A stopped call has already answered itself and dropped its worker.
        if (pending.isSettled) return;
        pending.job.complete(outcome);
        _release(worker);
      }),
    );
  }

  /// Returns [worker] to the idle set, or retires it when the pool has since
  /// been told to hold fewer.
  void _release(ToolWorker worker) {
    _busy.remove(worker);
    if (_closed || _liveCount >= _size) {
      unawaited(worker.terminate());
    } else {
      _idle.add(worker);
    }
    _pump();
  }

  /// Answers a stopped call at once and abandons whatever was running it.
  void _stop(_PendingCall pending) {
    if (pending.isSettled) return;
    _waiting.remove(pending);
    _running.remove(pending);
    pending.job.complete(const JobCanceled('Tool call stopped.'));

    final worker = pending.worker;
    if (worker != null) {
      _busy.remove(worker);
      unawaited(worker.terminate());
    }
    _pump();
  }
}

/// One queued or running call, and the job standing in for its answer.
final class _PendingCall {
  _PendingCall(this.lane, void Function(_PendingCall) stop) {
    job = _PooledJob(() => stop(this));
  }

  /// Calls sharing a lane run one at a time, in the order they were queued.
  final String? lane;
  late final _PooledJob job;

  /// What to run, once the call has been prepared.
  ToolWorkRequest? request;

  /// The worker running this call, once it has one.
  ToolWorker? worker;

  bool get isSettled => job.outcome != null;
}

/// A [Job] whose work happens on a worker.
final class _PooledJob implements Job {
  _PooledJob(this._stop);

  final void Function() _stop;
  final Completer<JobOutcome> _settled = Completer<JobOutcome>();
  JobOutcome? _outcome;

  @override
  JobOutcome? get outcome => _outcome;

  @override
  Future<JobOutcome> get settled => _settled.future;

  /// A tool call is answered by whoever made it, never handed back to run on
  /// in the background.
  @override
  Future<String> get inBackground => Completer<String>().future;

  @override
  void stop() => _stop();

  void complete(JobOutcome outcome) {
    if (_settled.isCompleted) return;
    _outcome = outcome;
    _settled.complete(outcome);
  }
}
