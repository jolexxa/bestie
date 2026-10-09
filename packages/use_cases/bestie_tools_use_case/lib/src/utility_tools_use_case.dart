import 'dart:async';

import 'package:bestie_tools_use_case/src/definitions/utility_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:bestie_tools_use_case/src/tools_config_keys.dart';
import 'package:bestie_tools_use_case/src/worker/tool_work_request.dart';
import 'package:bestie_tools_use_case/src/worker/tool_worker_pool.dart';
import 'package:config_repository/config_repository.dart';
import 'package:fs_tools/fs_tools.dart';
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
    required WorkspacePaths workspacePaths,
  }) : _pool = pool,
       _config = config,
       _configKeys = configKeys,
       _sandboxes = sandboxes,
       _workspacePaths = workspacePaths {
    _resize(_config.resolve(_configKeys.concurrentTools.global));
    _concurrencySub = _config
        .watch(_configKeys.concurrentTools.global)
        .listen(_resize);
  }

  final ToolWorkerPool _pool;
  final ConfigRepository _config;
  final ToolsConfigKeys _configKeys;
  final SandboxRepository _sandboxes;

  final WorkspacePaths _workspacePaths;
  late final StreamSubscription<int> _concurrencySub;

  @override
  final ToolDefinitions definitions = ToolDefinitions(utilityToolDefinitions);

  /// Sizes the pool to [workers], held to the range the setting offers.
  void _resize(int workers) =>
      _pool.size = workers.clamp(minConcurrentTools, maxConcurrentTools);

  /// Queues the call before anything is awaited, so calls reach the pool in
  /// the order they were made.
  @override
  Future<Job> respond(ToolCallInvocation invocation) async {
    // Answered here rather than on a worker: a name this feature never offered
    // should not wait behind real work for a slot it has no use for.
    if (definitions.definitionFor(invocation.toolName) == null) {
      return Job.failed('No such tool: ${invocation.toolName}.');
    }
    if (!_confined.contains(invocation.toolName)) {
      return _pool.run(
        Future.value(ToolWorkReady(ToolWorkRequest(invocation))),
      );
    }
    final lane = _laneFor(invocation);
    final resolved = lane == null ? invocation : _withPath(invocation, lane);
    return _pool.run(_confine(resolved), lane: lane);
  }

  /// The file the call's `path` really reaches, so the lane and the file the
  /// editor touches are one and the same.
  String? _laneFor(ToolCallInvocation invocation) =>
      switch (invocation.arguments['path']) {
        final String path when path.isNotEmpty => _workspacePaths.targetOf(
          path,
        ),
        _ => null,
      };

  ToolCallInvocation _withPath(ToolCallInvocation invocation, String path) =>
      ToolCallInvocation(
        conversationId: invocation.conversationId,
        agentId: invocation.agentId,
        callId: invocation.callId,
        toolName: invocation.toolName,
        outputPath: invocation.outputPath,
        maxOutputChars: invocation.maxOutputChars,
        arguments: {...invocation.arguments, 'path': path},
      );

  Future<ToolWorkStart> _confine(ToolCallInvocation invocation) async =>
      switch (await _sandboxes.confine()) {
        Unconfined() => ToolWorkReady(ToolWorkRequest(invocation)),
        Confined(:final sandbox) => ToolWorkReady(
          ToolWorkRequest(invocation, sandbox: sandbox),
        ),
        ConfinementRefused(:final reason) => ToolWorkRefused(
          'Could not confine the editor: $reason',
        ),
      };

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
