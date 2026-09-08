import 'dart:async';

import 'package:bestie_shell_use_case/src/agent_shell_attachment.dart';
import 'package:bestie_shell_use_case/src/shell_call_index.dart';
import 'package:bestie_shell_use_case/src/shell_config_keys.dart';
import 'package:bestie_shell_use_case/src/shell_replies.dart';
import 'package:bestie_shell_use_case/src/shell_tools.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// How long a command is given to finish before it is handed back as
/// something to watch rather than something to wait for.
const Duration agentShellYieldWindow = Duration(seconds: 10);

/// Shells an agent may hold at once, so a conversation full of subagents is not
/// a conversation full of terminals.
const int maxAgentShells = 8;

/// The terminal an agent's command is given before anything resizes it.
const int _agentShellRows = 24;
const int _agentShellCols = 40;

/// Opens and closes the shell sessions bestie runs, and answers the shell tools
/// an agent calls.
@useCase
class ShellUseCase implements ToolResponder, CommandContribution {
  ShellUseCase({
    required this.repository,
    required this.environment,
    required this.config,
    required this.configKeys,
    required this.sandboxes,
  }) : _calls = ShellCallIndex(repository) {
    commands = List.unmodifiable([
      Command(
        id: 'shell.closeTerminal',
        title: 'Close terminal session',
        glyph: '⊠',
        description: 'End the embedded shell and free its pane',
        group: 'Terminal',
        availability: _closeTerminalAvailability(),
        next: _closeTerminalFlow,
        invoke: _closeTerminalInvoke,
      ),
    ]);
  }

  @override
  late final List<Command> commands;

  static const _closeTerminalKey = ParamKey<String>('shellSessionId');

  /// Tracks every session this opens.
  final ShellRepository repository;

  /// The environment every session runs in.
  final ShellEnvironment environment;

  /// Resolves shell configuration.
  final ConfigKeyResolver config;

  final ShellConfigKeys configKeys;

  /// Provisions the confinement each agent command runs under.
  final SandboxRepository sandboxes;

  /// Which agent call each shell belongs to, and the record each leaves.
  final ShellCallIndex _calls;

  int get _scrollbackBytes =>
      config.resolve(configKeys.scrollbackMb.global) << 20;

  /// Snapshot of the shells the user drives, in the order they were opened.
  List<ShellSessionSummary> get userShells => _onlyUser(repository.sessions);

  /// Emits [userShells] each time the roster changes.
  Stream<List<ShellSessionSummary>> get userShellsStream =>
      repository.sessionsStream.map(_onlyUser);

  /// The live session registered under [id], or null once it has been closed.
  ShellSession? sessionFor(ShellSessionId id) => repository.sessionFor(id);

  /// What the call [toolCallId] has to show of its shell, as it runs one and
  /// is finally read off disk.
  Stream<AgentShellAttachment> agentShellFor(String toolCallId) =>
      _calls.watch(toolCallId);

  List<ShellSessionSummary> _onlyUser(List<ShellSessionSummary> sessions) => [
    for (final session in sessions)
      if (session.kind == ShellSessionKind.interactive) session,
  ];

  /// Opens a shell the user drives.
  ShellSession openUserShell({required int rows, required int cols}) =>
      repository.open(
        ShellSessionRequest.userShell(
          environment: environment,
          rows: rows,
          cols: cols,
          scrollbackBytes: _scrollbackBytes,
        ),
      );

  /// Closes the session registered under [id].
  Future<void> close(ShellSessionId id) => repository.close(id);

  // ── Palette commands ──────────────────────────────────

  Stream<Availability> _closeTerminalAvailability() => gatedAvailability(
    () => userShells,
    userShellsStream,
    (sessions) => sessions.isEmpty
        ? const Unavailable('no open terminal')
        : const Available(),
  );

  Param? _closeTerminalFlow(Answers soFar) =>
      soFar.maybe(_closeTerminalKey) == null
      ? ChoiceParam<String>.fixed(
          key: _closeTerminalKey,
          label: 'Terminal',
          options: [
            for (final session in userShells)
              Option(value: session.id, label: session.title),
          ],
        )
      : null;

  Future<CommandResult> _closeTerminalInvoke(Answers answers) async {
    final id = answers.get(_closeTerminalKey);
    if (sessionFor(id) == null) {
      return const CommandRejected('terminal already closed');
    }
    await close(id);
    return const CommandRan();
  }

  // ── Tool surface ──────────────────────────────────────

  @override
  ToolDefinitions get definitions => shellToolDefinitions;

  @override
  Future<Job> respond(ToolCallInvocation invocation) async {
    _calls.forget(before: invocation.conversationId);
    return invocation.toolName == bashReadName
        ? _readBack(invocation)
        : _run(invocation);
  }

  /// Answers a `bash_read` call with a page of what a command printed.
  Future<Job> _readBack(ToolCallInvocation invocation) async {
    final id = (invocation.arguments['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) {
      return Job.failed('$bashReadName requires a non-empty "id".');
    }
    final path = _calls.pathOf(id);
    if (path == null) return Job.failed('No $bashName call "$id" here.');

    final page = await repository.readTranscript(
      path,
      length: invocation.maxOutputChars,
      at: _whole(invocation.arguments['offset']) ?? 0,
    );
    return Job.done(page.read(id, maxChars: invocation.maxOutputChars));
  }

  /// A tool argument as a place in the output, or null when it was not one.
  static int? _whole(Object? argument) => switch (argument) {
    final int value => value,
    final String value => int.tryParse(value),
    final num value => value.toInt(),
    _ => null,
  };

  Future<Job> _run(ToolCallInvocation invocation) async {
    final command = (invocation.arguments['command'] as String?)?.trim() ?? '';
    if (command.isEmpty) {
      return Job.failed('$bashName requires a non-empty "command".');
    }
    if (repository.runningEphemeralShells >= maxAgentShells) {
      return Job.failed(
        'Already running $maxAgentShells shells, which is as many as are '
        'allowed at once. Wait for one to finish.',
      );
    }

    final decision = await sandboxes.confine();
    if (decision is ConfinementRefused) {
      return Job.failed('Could not confine the shell: ${decision.reason}');
    }
    final confinement = decision is Confined ? decision.sandbox : null;

    // The repository records from open and reaps on settle, so the record is
    // complete once the shell is gone.
    final session = await repository.openEphemeral(
      ShellSessionRequest.agentShell(
        environment: environment,
        command: command,
        rows: _agentShellRows,
        cols: _agentShellCols,
        scrollbackBytes: _scrollbackBytes,
        sandbox: confinement,
      ),
      path: invocation.outputPath,
      endingChars: invocation.maxOutputChars,
    );
    _calls.attach(invocation, session);

    final job = _ShellJob();
    unawaited(_drive(job, session, invocation, confinement));
    return job;
  }

  Future<void> dispose() async => _calls.dispose();

  /// Runs [job] to its outcome, knowing what [confinement] it ran under.
  Future<void> _drive(
    _ShellJob job,
    EphemeralShell session,
    ToolCallInvocation invocation,
    Sandbox? confinement,
  ) async {
    final ended = Future.any<Object?>([
      session.transcriptPage,
      job.stopRequested,
    ]);

    // Once handed back, whatever it settles to is a report, not its answer.
    var reply = ShellReply.answer;
    if (await _outlived(ended)) {
      job.goToBackground(
        'Still running as ${invocation.callId}. You will be told how it '
        'finished.',
      );
      reply = ShellReply.report;
      await ended;
    }

    // A stopped call is reaped now and never settles; a finished one already
    // reaped itself on exit.
    if (job.wasStopped) await repository.close(session.id);
    final stored = await session.transcriptPage;
    final state = job.wasStopped ? null : await session.settled;
    final outcome = _outcomeFor(state, stored, reply, invocation, confinement);
    job.complete(outcome);
  }

  /// Whether [ended] was still outstanding when the yield window closed.
  Future<bool> _outlived(Future<Object?> ended) async {
    const pending = Object();
    return identical(
      await ended.timeout(agentShellYieldWindow, onTimeout: () => pending),
      pending,
    );
  }

  /// The outcome [state] came to under [confinement], carrying [stored] told
  /// as [reply] within what [invocation] allowed its answer.
  JobOutcome _outcomeFor(
    ShellSessionState? state,
    TranscriptPage stored,
    ShellReply reply,
    ToolCallInvocation invocation,
    Sandbox? confinement,
  ) {
    final failure = state?.failure;
    if (state == null) {
      const message = 'The shell was closed before the command finished.';
      return JobCanceled(
        message,
        content: _under(message, stored, reply, invocation),
      );
    }
    if (failure != null) {
      return JobFailed(
        'Could not start a shell: ${failure.function}: ${failure.message}',
      );
    }

    final exit = state.exitStatus;
    final message = switch (exit) {
      ProcessExited(code: 0) => null,
      ProcessExited(:final code) =>
        'Exited with code $code.'
            '${_blockedWriteHint(exit, confinement, stored)}',
      ProcessSignaled(:final signal) => 'Killed by signal $signal.',
      // Both mean the shell is gone without having said how it went.
      ProcessUnknown() ||
      ProcessSupervisorLost() ||
      null => 'The shell ended without reporting how.',
    };

    // Alone among these, a success has no words of its own for a report to
    // carry, so how it exited is the body's to say.
    if (message == null) {
      return JobSucceeded(
        stored.told(
          reply,
          id: invocation.callId,
          maxChars: invocation.maxOutputChars,
          lead: 'Exited with code 0.',
        ),
      );
    }
    return JobFailed(
      message,
      content: _under(message, stored, reply, invocation),
    );
  }

  /// What the sandbox may have had to do with [exit], read from what the
  /// command printed under [confinement]: empty unless a write looks blocked.
  String _blockedWriteHint(
    ProcessExit exit,
    Sandbox? confinement,
    TranscriptPage stored,
  ) {
    if (confinement is! ConfinedSandbox) return '';
    final evidence = const SandboxSuspector()
        .suspect(
          exit: exit,
          sandbox: confinement,
          output: stored.body.text.split('\n'),
        )
        .where(
          (suspicion) =>
              suspicion.dimension == SandboxDimension.filesystemWrite,
        )
        .expand((suspicion) => suspicion.evidence)
        .firstOrNull;
    if (evidence == null) return '';
    final writable = confinement.enforcement.writableRoots.join(', ');
    return ' The sandbox may have blocked a write: ${evidence.trim()} '
        'Writable: $writable. To write elsewhere, call request_write_access '
        'with the directory and why.';
  }

  /// What the command printed, told as [reply] to go under [message].
  String _under(
    String message,
    TranscriptPage stored,
    ShellReply reply,
    ToolCallInvocation invocation,
  ) => stored.told(
    reply,
    id: invocation.callId,
    maxChars: roomUnderMessage(message, maxChars: invocation.maxOutputChars),
  );
}

/// A [Job] whose work is a shell session.
final class _ShellJob implements Job {
  final _settled = Completer<JobOutcome>();
  final _inBackground = Completer<String>();
  final _stopRequested = Completer<void>();
  JobOutcome? _outcome;

  @override
  JobOutcome? get outcome => _outcome;

  @override
  Future<JobOutcome> get settled => _settled.future;

  @override
  Future<String> get inBackground => _inBackground.future;

  /// Completes when someone asks this job to stop.
  Future<void> get stopRequested => _stopRequested.future;

  bool get wasStopped => _stopRequested.isCompleted;

  void goToBackground(String content) => _inBackground.complete(content);

  void complete(JobOutcome outcome) {
    if (_settled.isCompleted) return;
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() {
    if (!_stopRequested.isCompleted) _stopRequested.complete();
  }
}
