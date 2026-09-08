import 'package:bestie_tools_use_case/src/utility_tools_use_case.dart';
import 'package:bestie_tools_use_case/src/worker/tool_command_handler.dart';
import 'package:bestie_tools_use_case/src/worker/tool_work_request.dart';
import 'package:bestie_tools_use_case/src/worker/toolbox.dart';
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// One concurrency slot: somewhere a tool call can run that is not here.
@PartOf(UtilityToolsUseCase)
abstract interface class ToolWorker {
  /// Runs [request] to its outcome. Never throws.
  Future<JobOutcome> run(ToolWorkRequest request);

  /// Stops the worker, abandoning whatever it was running.
  Future<void> terminate();
}

/// Produces a worker, or explains why it could not.
typedef ToolWorkerFactory = Future<ToolWorkerCreateResult> Function();

/// The result of standing up a [ToolWorker].
@PartOf(UtilityToolsUseCase)
sealed class ToolWorkerCreateResult {
  const ToolWorkerCreateResult();
}

/// A worker ready to take calls.
@PartOf(UtilityToolsUseCase)
final class ToolWorkerCreated extends ToolWorkerCreateResult {
  const ToolWorkerCreated(this.worker);

  final ToolWorker worker;
}

/// No worker; the call that wanted one has to be answered without it.
@PartOf(UtilityToolsUseCase)
final class ToolWorkerCreateFailed extends ToolWorkerCreateResult {
  const ToolWorkerCreateFailed(this.message);

  final String message;
}

/// A [ToolWorker] backed by its own isolate.
@PartOf(UtilityToolsUseCase)
final class ToolIsolateWorker implements ToolWorker {
  const ToolIsolateWorker(this._worker);

  final IsolateWorker<ToolWorkRequest, JobOutcome> _worker;

  /// Spawns an isolate holding a toolbox built by [toolboxFactory] from
  /// [config], on the far side.
  static Future<ToolWorkerCreateResult> spawn({
    required ToolWorkerConfig config,
    required ToolboxFactory toolboxFactory,
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
  }) async {
    final handler = ToolCommandHandler(
      config: config,
      toolboxFactory: toolboxFactory,
    );
    final result = await IsolateWorker.spawn<ToolWorkRequest, JobOutcome>(
      commandHandler: handler.call,
      isolateSpawner: isolateSpawner,
      debugName: 'bestie-tools',
    );

    return switch (result) {
      IsolateSpawnSucceeded(:final worker) => ToolWorkerCreated(
        ToolIsolateWorker(worker),
      ),
      IsolateSpawnFailed(:final message) => ToolWorkerCreateFailed(message),
    };
  }

  @override
  Future<JobOutcome> run(ToolWorkRequest request) async {
    final result = await _worker.send(request);
    return switch (result) {
      IsolateSucceeded(:final value) => value,
      IsolateFailed(:final message) => JobFailed(message),
    };
  }

  /// Kills rather than drains: a tool worker holds nothing worth finishing, and
  /// a call being abandoned is one nobody is waiting on any more.
  @override
  Future<void> terminate() => _worker.close(timeout: Duration.zero);
}
