import 'dart:async';

import 'package:bestie_tools_use_case/src/definitions/utility_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:bestie_tools_use_case/src/tools_config_keys.dart';
import 'package:bestie_tools_use_case/src/worker/tool_work_request.dart';
import 'package:bestie_tools_use_case/src/worker/tool_worker_pool.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Feature use case for the app's utility tools: what the model may call, what
/// each call is described as, and what comes back from making one.
@useCase
class UtilityToolsUseCase implements ToolResponder {
  UtilityToolsUseCase({
    required ToolWorkerPool pool,
    required ConfigRepository config,
    required ToolsConfigKeys configKeys,
    required SandboxRepository sandboxes,
  }) : _pool = pool,
       _config = config,
       _configKeys = configKeys,
       _sandboxes = sandboxes {
    _resize(_config.resolve(_configKeys.concurrentTools.global));
    _concurrencySub = _config
        .watch(_configKeys.concurrentTools.global)
        .listen(_resize);
  }

  final ToolWorkerPool _pool;
  final ConfigRepository _config;
  final ToolsConfigKeys _configKeys;
  final SandboxRepository _sandboxes;
  late final StreamSubscription<int> _concurrencySub;

  @override
  final ToolDefinitions definitions = ToolDefinitions(utilityToolDefinitions);

  /// Sizes the pool to [workers], held to the range the setting offers.
  void _resize(int workers) =>
      _pool.size = workers.clamp(minConcurrentTools, maxConcurrentTools);

  @override
  Future<Job> respond(ToolCallInvocation invocation) async {
    // Answered here rather than on a worker: a name this feature never offered
    // should not wait behind real work for a slot it has no use for.
    if (definitions.definitionFor(invocation.toolName) == null) {
      return Job.failed('No such tool: ${invocation.toolName}.');
    }
    if (!_confined.contains(invocation.toolName)) {
      return _pool.run(ToolWorkRequest(invocation));
    }
    return switch (await _sandboxes.confine()) {
      Unconfined() => _pool.run(ToolWorkRequest(invocation)),
      Confined(:final sandbox) => _pool.run(
        ToolWorkRequest(invocation, sandbox: sandbox),
      ),
      ConfinementRefused(:final reason) => Job.failed(
        'Could not confine the editor: $reason',
      ),
    };
  }

  /// The tools that write to the workspace, and so run under the sandbox.
  static const Set<String> _confined = {
    UtilityToolNames.create,
    UtilityToolNames.edit,
  };

  Future<void> dispose() async {
    await _concurrencySub.cancel();
    await _pool.close();
  }
}
