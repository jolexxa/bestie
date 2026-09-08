import 'dart:async';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/src/session/shell_session.dart';
import 'package:shell_repository/src/session/shell_session_data.dart';
import 'package:shell_repository/src/session/shell_session_input.dart';
import 'package:shell_repository/src/session/shell_session_output.dart';
import 'package:shell_repository/src/session/shell_session_request.dart';

// ── Base state ──────────────────────────────────────────────

/// One shell session's lifecycle. Subscribers read these off
/// `ShellSession.stream`.
@model
sealed class ShellSessionState extends StateLogic<ShellSessionState> {
  ShellSessionData get data => get<ShellSessionData>();

  /// The live terminal, once the spawn has succeeded.
  AgentTerminal? get terminal => data.terminal;

  /// The child's exit status, once it has exited. Not `exit` — that name is
  /// taken by [StateLogic]'s own lifecycle hook.
  ProcessExit? get exitStatus => data.exit;

  /// Why the last spawn was refused, if it was.
  SpawnFailure? get failure => data.failure;

  bool get notStarted => false;
  bool get starting => false;
  bool get running => false;
  bool get exited => false;
}

// ── Concrete states ─────────────────────────────────────────

/// Nothing is running: either the session has not been started yet, or a
/// previous shell exited and was reset.
@model
final class ShellSessionNotStarted extends ShellSessionState {
  ShellSessionNotStarted() {
    onEnter(() => output(const ShellSessionChanged()));

    on<StartShell>((_) => to<ShellSessionStarting>());
  }

  @override
  bool get notStarted => true;
}

/// The spawn is in flight.
@model
final class ShellSessionStarting extends ShellSessionState {
  ShellSessionStarting() {
    onEnter(() {
      data.failure = null;
      output(const ShellSessionChanged());
      final request = data.request;
      async(
        data.host.spawn(
          executable: request.executable,
          arguments: request.arguments,
          environment: request.environment,
          launchMode: request.launchMode,
          rows: request.rows,
          cols: request.cols,
          scrollbackBytes: request.scrollbackBytes,
          forwardHostResize: request.forwardHostResize,
          sandbox: request.sandbox,
        ),
      ).input(SpawnSettled.new).errorInput(_unexpected);
    });

    on<SpawnSettled>(
      (input) => switch (input.result) {
        TerminalSpawnSucceeded(:final terminal) => _started(terminal),
        TerminalSpawnFailed(:final failure) => _refused(failure),
      },
    );
  }

  Transition _started(AgentTerminal terminal) {
    data.terminal = terminal;
    return to<ShellSessionRunning>();
  }

  Transition _refused(SpawnFailure failure) {
    data.failure = failure;
    return to<ShellSessionNotStarted>();
  }

  /// A [TerminalHost] answers rather than throws, so anything here is a defect
  /// below us — surfaced where a refused spawn shows up rather than lost.
  static SpawnSettled _unexpected(Object error) => SpawnSettled(
    TerminalSpawnFailed(
      SpawnFailure(function: 'TerminalHost.spawn', message: '$error'),
    ),
  );

  @override
  bool get starting => true;
}

/// The child is alive.
@model
final class ShellSessionRunning extends ShellSessionState {
  ShellSessionRunning() {
    onEnter(() {
      output(const ShellSessionChanged());
      final terminal = data.terminal;
      if (terminal != null) {
        async(terminal.exit).input(ShellExited.new);
      }
    });

    on<ShellExited>((input) {
      data.exit = input.exit;
      return to<ShellSessionExited>();
    });
  }

  @override
  bool get running => true;
}

/// The child has terminated; its screen is still readable.
@model
final class ShellSessionExited extends ShellSessionState {
  ShellSessionExited() {
    onEnter(() => output(const ShellSessionChanged()));

    on<StartShell>((_) {
      final terminal = data.terminal;
      data
        ..terminal = null
        ..exit = null
        ..failure = null;
      if (terminal != null) {
        unawaited(terminal.close());
      }
      return to<ShellSessionStarting>();
    });
  }

  @override
  bool get exited => true;
}

// ── Logic block ─────────────────────────────────────────────

/// The state machine behind one [ShellSession]. An implementation detail —
/// subscribers see [ShellSessionState] through the session's stream.
@PartOf(ShellSession)
final class ShellSessionLogic extends LogicBlock<ShellSessionState> {
  ShellSessionLogic({
    required TerminalHost host,
    required ShellSessionRequest request,
  }) {
    set(ShellSessionData(host: host, request: request));

    set(ShellSessionNotStarted());
    set(ShellSessionStarting());
    set(ShellSessionRunning());
    set(ShellSessionExited());
  }

  /// The in-flight terminal teardown, awaited during `dispose()` so the
  /// read-loop / waitpid isolates don't outlive the session and pin threads.
  Future<void>? terminalCloseFuture;

  @override
  Transition getInitialState() => to<ShellSessionNotStarted>();

  @override
  void onStop() {
    final data = get<ShellSessionData>();
    final terminal = data.terminal;
    data.terminal = null;
    if (terminal != null) {
      terminalCloseFuture = terminal.close();
    }
  }
}
