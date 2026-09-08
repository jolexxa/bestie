import 'dart:async';

import 'package:bestie_sandbox_use_case/src/sandbox_config_keys.dart';
import 'package:bestie_sandbox_use_case/src/sandbox_platform_model.dart';
import 'package:bestie_sandbox_use_case/src/sandbox_tools.dart';
import 'package:bestie_sandbox_use_case/src/write_access_job.dart';
import 'package:bestie_sandbox_use_case/src/write_access_outcome.dart';
import 'package:bestie_sandbox_use_case/src/write_access_queue.dart';
import 'package:bestie_sandbox_use_case/src/write_access_request.dart';
import 'package:bestie_sandbox_use_case/src/write_grants_forgotten.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Plans the session's confinement: the one [SandboxPlan] every feature that
/// runs the agent's programs composes over, widened as the user allows the
/// agent's programs to write beyond the workspace.
@useCase
class SandboxUseCase implements CommandContribution, ToolResponder {
  SandboxUseCase({
    required this.sandboxes,
    required this.config,
    required this.configKeys,
    required this.sandboxModel,
    p.Context? paths,
  }) : paths = paths ?? p.context,
       commands = [];

  /// Provisions and reuses this session's confinement.
  final SandboxRepository sandboxes;

  /// Resolves the sandbox configuration and keeps the user's write grants.
  final ConfigRepository config;

  /// The keys the sandbox toggles live under.
  final SandboxConfigKeys configKeys;

  /// The platform-shaped policy — which system trees and home paths a confined
  /// program may read, and which temp trees it may write. Selected by OS at
  /// the composition root.
  final SandboxPlatformModel sandboxModel;

  /// Reads the paths the agent asks about, in the host's style.
  final p.Context paths;

  /// The palette commands, filled in once a sandbox is planned.
  @override
  final List<Command> commands;

  @override
  ToolDefinitions get definitions => sandboxToolDefinitions;

  final WriteAccessQueue _queue = WriteAccessQueue();
  final StreamController<WriteGrantsForgotten> _forgotten =
      StreamController<WriteGrantsForgotten>.broadcast();
  final Set<String> _declined = {};
  _Session? _session;
  int _asked = 0;

  /// Where the session's sandbox stands since startup.
  SandboxReadiness get readiness => sandboxes.readiness;

  /// [readiness] as it moves, opening with the current value.
  Stream<SandboxReadiness> get readinessStream => sandboxes.readinessStream;

  /// The ask in front of the user, or null when there is none.
  WriteAccessRequest? get pendingWriteAccess => _queue.current;

  /// [pendingWriteAccess] as it moves, opening with the current value.
  Stream<WriteAccessRequest?> get pendingWriteAccessStream => _queue.stream;

  /// Each time the user takes back their write grants, once the sandbox has
  /// been rebuilt without them.
  Stream<WriteGrantsForgotten> get writeGrantsForgotten => _forgotten.stream;

  /// Plans confinement for a session working in [workspaceRoot] as the user
  /// whose home is [homeDir] and whose programs stage files in [tempDir],
  /// where the agent's programs live under [programRoots]. Provisioning starts
  /// at once on a prepared host; otherwise it waits at the gate for
  /// [initialize].
  SandboxPlan setupSandbox({
    required String workspaceRoot,
    required String homeDir,
    required String tempDir,
    required List<String> programRoots,
  }) {
    if (!config.resolve(configKeys.sandboxAgentShell.global)) {
      return const SandboxOff();
    }
    final base = SandboxSpec(
      workspaceRoot: workspaceRoot,
      writableRoots: [
        workspaceRoot,
        ...sandboxModel.systemWriteRoots,
        ...sandboxModel.tempWriteRoots(tempDir),
      ],
      readableRoots: [
        ...sandboxModel.systemReadRoots,
        ...sandboxModel.homeReadRoots(homeDir),
        ...programRoots,
        workspaceRoot,
      ],
      deniedReads: sandboxModel.deniedReadsFor(homeDir),
      network: config.resolve(configKeys.sandboxNetworkTier.global),
    );
    _session = _Session(
      workspaceRoot: workspaceRoot,
      homeDir: homeDir,
      base: base,
      paths: paths,
    );
    final plan = SandboxPlanned(
      spec: _widened(base, _grants),
      failClosed: config.resolve(configKeys.sandboxFailClosed.global),
    );
    sandboxes.adopt(plan);
    commands
      ..add(_resetCommand)
      ..add(_forgetWriteGrantsCommand);
    return plan;
  }

  /// The user's answer to the sandbox gate.
  Future<void> initialize() => sandboxes.initialize();

  /// Reverses every grant and starts over.
  Future<void> reset() => sandboxes.reset();

  /// The user's answer to the ask [id]; ignored for an ask no longer waiting.
  void answerWriteAccess(String id, {required bool allow}) =>
      _queue.answer(id, allow: allow);

  @override
  Future<Job> respond(ToolCallInvocation invocation) async {
    final path = (invocation.arguments['path'] as String?)?.trim() ?? '';
    final reason = (invocation.arguments['reason'] as String?)?.trim() ?? '';
    if (path.isEmpty) {
      return Job.failed('$requestWriteAccessName requires a non-empty "path".');
    }
    final id = 'write-access-${++_asked}';
    final job = WriteAccessJob(onStop: () => _queue.withdraw(id));
    final asked = WriteAccessRequest(
      id: id,
      path: path,
      shownPath: path,
      reason: reason,
      agentId: invocation.agentId,
    );
    unawaited(
      _requestWriteAccess(
        asked,
      ).then((outcome) => job.complete(_told(outcome))),
    );
    return job;
  }

  Future<void> dispose() async {
    await _queue.dispose();
    await _forgotten.close();
  }

  List<String> get _grants =>
      config.resolve(configKeys.sandboxWriteGrants.global);

  /// [base] with [directories] granted for write, and so for read.
  SandboxSpec _widened(SandboxSpec base, List<String> directories) =>
      base.copyWith(
        writableRoots: [...base.writableRoots, ...directories],
        readableRoots: [...base.readableRoots, ...directories],
      );

  Future<WriteAccessOutcome> _requestWriteAccess(
    WriteAccessRequest asked,
  ) async {
    final session = _session;
    final plan = sandboxes.plan;
    if (session == null || plan is! SandboxPlanned) {
      return WriteAccessAlreadyAllowed(asked.path);
    }
    final directory = session.normalize(asked.path);
    if (session.writable(plan.spec, directory)) {
      return WriteAccessAlreadyAllowed(directory);
    }
    final refusal = session.refusalFor(directory, plan.spec.deniedReads);
    if (refusal != null) return WriteAccessRefused(directory, refusal);
    if (_declined.contains(directory)) return WriteAccessDeclined(directory);

    final request = WriteAccessRequest(
      id: asked.id,
      path: directory,
      shownPath: session.shorten(directory),
      reason: asked.reason,
      agentId: asked.agentId,
    );
    return switch (await _queue.enqueue(request)) {
      WriteAccessAnswer.allowed => _grant(plan, directory),
      WriteAccessAnswer.declined => _decline(directory),
      WriteAccessAnswer.withdrawn => Future.value(
        WriteAccessDeclined(directory),
      ),
    };
  }

  Future<WriteAccessOutcome> _decline(String directory) async {
    _declined.add(directory);
    return WriteAccessDeclined(directory);
  }

  Future<WriteAccessOutcome> _grant(
    SandboxPlanned plan,
    String directory,
  ) async {
    config.commit({
      configKeys.sandboxWriteGrants.global: ConfigEdit.set(
        {..._grants, directory}.toList(),
      ),
    });
    return switch (await sandboxes.replan(_widened(plan.spec, [directory]))) {
      SandboxAcquired() => WriteAccessGranted(directory),
      SandboxInitializing() => WriteAccessFailed(
        directory,
        'the sandbox is still initializing',
      ),
      SandboxUnavailable(:final reason) => WriteAccessFailed(directory, reason),
      SandboxConsentDeclined(:final path) => WriteAccessFailed(
        directory,
        'consent declined for $path',
      ),
      SandboxProvisioningFailed(:final operation, :final reason) =>
        WriteAccessFailed(directory, '$operation: $reason'),
    };
  }

  /// [outcome] as the model is told it.
  JobOutcome _told(WriteAccessOutcome outcome) => switch (outcome) {
    WriteAccessGranted(:final path) => JobSucceeded(
      'You may now write under $path. Retry the command.',
    ),
    WriteAccessAlreadyAllowed(:final path) => JobSucceeded(
      'Writes under $path are already allowed; nothing to ask.',
    ),
    WriteAccessDeclined(:final path) => JobFailed(
      'The user declined write access to $path. Do not ask again for this '
      'directory unless the user tells you to.',
    ),
    WriteAccessRefused(:final path, :final reason) => JobFailed(
      'Write access to $path cannot be requested: $reason.',
    ),
    WriteAccessFailed(:final path, :final reason) => JobFailed(
      'The user allowed writes under $path and it is saved for the next '
      'launch, but the sandbox could not be rebuilt now: $reason.',
    ),
  };

  Command get _resetCommand => Command(
    id: 'sandbox.reset',
    title: 'Reset sandbox',
    glyph: '⟲',
    description: 'Reverse every sandbox grant on this machine and rebuild',
    group: 'Sandbox',
    running: sandboxModel == SandboxPlatformModel.windows
        ? 'Resetting the Windows sandbox. This can take a while. Please be '
              'patient.'
        : 'Resetting the sandbox…',
    availability: gatedAvailability(
      () => readiness,
      readinessStream,
      _restingGate,
    ),
    invoke: _resetInvoke,
  );

  Command get _forgetWriteGrantsCommand => Command(
    id: 'sandbox.forgetWriteGrants',
    title: 'Forget granted write directories',
    glyph: '⛨',
    description:
        'Take back every directory beyond the workspace the agent was '
        'allowed to write to',
    group: 'Sandbox',
    running: 'Rebuilding the sandbox…',
    availability: gatedAvailability(
      () => readiness,
      readinessStream,
      _restingGate,
    ),
    invoke: _forgetWriteGrantsInvoke,
  );

  Availability _restingGate(SandboxReadiness readiness) => switch (readiness) {
    SandboxReady() || SandboxInitializationFailed() => const Available(),
    SandboxAwaitingInitialization() => const Unavailable(
      'the sandbox has not been initialized yet',
    ),
    SandboxPreparingHost() || SandboxProvisioning() => const Unavailable(
      'the sandbox is still initializing',
    ),
  };

  Future<CommandResult> _resetInvoke(Answers answers) async {
    if (_restingGate(readiness) case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    await reset();
    return const CommandRan();
  }

  Future<CommandResult> _forgetWriteGrantsInvoke(Answers answers) async {
    if (_restingGate(readiness) case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    final forgotten = _grants;
    config.commit({
      configKeys.sandboxWriteGrants.global:
          const ConfigEdit<List<String>>.clear(),
    });
    _declined.clear();
    await sandboxes.replan(_session!.base);
    _forgotten.add(WriteGrantsForgotten(directories: forgotten));
    return const CommandRan();
  }
}

/// What a session was planned around, for reading the paths the agent asks
/// about against it.
final class _Session {
  const _Session({
    required this.workspaceRoot,
    required this.homeDir,
    required this.base,
    required this.paths,
  });

  final String workspaceRoot;
  final String homeDir;

  /// The policy before any of the user's write grants.
  final SandboxSpec base;
  final p.Context paths;

  /// [raw] as an absolute, normalized directory: `~` is the home directory
  /// and a relative path is taken from the workspace.
  String normalize(String raw) {
    final expanded = switch (raw) {
      '~' => homeDir,
      _ when raw.startsWith('~/') || raw.startsWith(r'~\') => paths.join(
        homeDir,
        raw.substring(2),
      ),
      _ => raw,
    };
    return paths.normalize(
      paths.isAbsolute(expanded)
          ? expanded
          : paths.join(workspaceRoot, expanded),
    );
  }

  /// [directory] as the user knows it: their home shortened to `~`.
  String shorten(String directory) => paths.isWithin(homeDir, directory)
      ? paths.join('~', paths.relative(directory, from: homeDir))
      : directory;

  /// Whether [spec] already lets programs write under [directory].
  bool writable(SandboxSpec spec, String directory) =>
      spec.writableRoots.any((root) => _covers(root, directory));

  /// Why [directory] is not one the sandbox will open, or null when it may be
  /// put to the user.
  String? refusalFor(String directory, List<String> deniedReads) {
    if (paths.equals(paths.rootPrefix(directory), directory)) {
      return 'it is the whole filesystem';
    }
    if (paths.equals(homeDir, directory)) {
      return 'it is the whole home directory';
    }
    if (deniedReads.any((secret) => _covers(secret, directory))) {
      return 'it holds secrets the sandbox keeps from the agent';
    }
    return null;
  }

  bool _covers(String root, String directory) =>
      paths.equals(root, directory) || paths.isWithin(root, directory);
}
