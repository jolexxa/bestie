import 'dart:async';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/src/session/shell_session_input.dart';
import 'package:shell_repository/src/session/shell_session_logic.dart';
import 'package:shell_repository/src/session/shell_session_output.dart';
import 'package:shell_repository/src/session/shell_session_request.dart';
import 'package:shell_repository/src/session/shell_write_result.dart';
import 'package:shell_repository/src/session/terminal_surface.dart';
import 'package:shell_repository/src/session/transcript_page.dart';

/// Identifier for a [ShellSession] within a `ShellRepository`.
typedef ShellSessionId = String;

/// Which lifecycle a session follows.
@model
enum ShellSessionKind {
  /// Lives until someone closes it — an [InteractiveShell].
  interactive,

  /// Runs one command and is reaped when it settles — an [EphemeralShell].
  ephemeral,
}

/// A stateful owner of one running shell, projected as a [ShellSessionState]
/// stream.
@model
sealed class ShellSession implements TerminalSurface {
  /// Brings up a shell described by [request], spawning through [host].
  ShellSession({
    required this.id,
    required TerminalHost host,
    required this.request,
  }) : _logic = ShellSessionLogic(host: host, request: request) {
    _binding = _logic.bind()..onOutput<ShellSessionChanged>((_) => _emit());
    _logic
      ..start()
      ..input(const StartShell());
    _lastState = _logic.value;
  }

  /// This session's id within a `ShellRepository`.
  final ShellSessionId id;

  /// Which lifecycle this session follows.
  ShellSessionKind get kind;

  /// What this session was asked to run.
  final ShellSessionRequest request;

  final ShellSessionLogic _logic;
  late final LogicBlockBinding<ShellSessionState> _binding;
  final _controller = StreamController<ShellSessionState>.broadcast();
  final _screenChanges = StreamController<void>.broadcast();

  late ShellSessionState _lastState;
  bool _disposed = false;

  AgentTerminal? _boundTerminal;
  StreamSubscription<void>? _screenSub;

  // ── Reactive surface ──────────────────────────────────

  /// Broadcast stream of this session's state changes.
  Stream<ShellSessionState> get stream => _controller.stream;

  /// Current state.
  ShellSessionState get state => _lastState;

  /// Fires when the child wrote to [screen] but nothing in the state changed —
  /// one event per chunk the pipe delivers.
  Stream<void> get screenChanges => _screenChanges.stream;

  /// Everything that changes what a view of this session would draw.
  @override
  Stream<void> get changes => Stream<void>.multi((controller) {
    final following = [
      stream.listen((_) => controller.add(null)),
      screenChanges.listen((_) => controller.add(null)),
    ];
    controller.onCancel = () async {
      for (final subscription in following) {
        await subscription.cancel();
      }
    };
  });

  /// The rendered output. Null until the shell has spawned; survives the
  /// child's exit so a transcript stays readable.
  @override
  Screen? get screen => _lastState.terminal?.screen;

  /// How far the displayed viewport sits above the live region, in rows.
  /// Zero while following the shell's output.
  @override
  int get viewOffset => screen?.viewOffset ?? 0;

  /// Whether the shell has exited, leaving [screen] as a transcript.
  @override
  bool get exited => _lastState.exited;

  /// Whether this session has come to rest: its shell exited, or a spawn was
  /// refused and left it not started with a failure to say why.
  bool get atRest => _atRest(_lastState);

  /// The state this session came to rest in, or null if it was released
  /// before it got there.
  Future<ShellSessionState?> get settled {
    if (atRest) return Future.value(_lastState);

    final rested = Completer<ShellSessionState?>();
    late final StreamSubscription<ShellSessionState> states;
    states = _controller.stream.listen(
      (state) {
        if (!_atRest(state)) return;
        unawaited(states.cancel());
        rested.complete(state);
      },
      onDone: rested.complete,
    );
    return rested.future;
  }

  static bool _atRest(ShellSessionState state) =>
      state.exited || (state.notStarted && state.failure != null);

  /// Emits the new [title] each time screen output retitles the session —
  /// an OSC title arrives as output, so it never surfaces on [stream].
  Stream<String> get titleChanges {
    var last = title;
    return _screenChanges.stream.map((_) => title).where((current) {
      if (current == last) return false;
      last = current;
      return true;
    });
  }

  /// What the child set via OSC, else the name of what was launched.
  String get title {
    final fromApp = screen?.title;
    if (fromApp != null && fromApp.isNotEmpty) return fromApp;
    final executable = request.executable;
    if (executable == null || executable.isEmpty) return 'shell';
    return executable.split(RegExp(r'[/\\]')).last;
  }

  // ── Commands ──────────────────────────────────────────

  /// Sends [bytes] to the child's stdin, refusing when no shell is live.
  @override
  ShellWriteResult write(List<int> bytes) {
    final terminal = _lastState.terminal;
    if (terminal == null || !_lastState.running) {
      return const ShellWriteRefused('no live shell to write to');
    }
    terminal.writeBytes(bytes);
    return const ShellWriteAccepted();
  }

  /// Resizes the terminal. A no-op when no shell is live.
  @override
  void resize({required int rows, required int cols}) =>
      _lastState.terminal?.resize(rows: rows, cols: cols);

  /// Scrolls the viewport to [offset] rows above the live region, clamped to
  /// scrollback. Returns the offset actually taken.
  @override
  int setViewOffset(int offset) => screen?.setViewOffset(offset) ?? 0;

  /// Releases the session and its terminal. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _screenSub?.cancel();
    _screenSub = null;
    _boundTerminal = null;
    _binding.dispose();
    // stop() runs onStop synchronously, which kicks off the terminal
    // teardown. Await it so the read-loop / waitpid isolates actually shut
    // down before this future resolves.
    _logic.stop();
    final closing = _logic.terminalCloseFuture;
    if (closing != null) await closing;
    _logic.dispose();
    await _controller.close();
    await _screenChanges.close();
  }

  void _emit() {
    if (_disposed) return;
    _lastState = _logic.value;
    _bindScreen(_lastState.terminal);
    _controller.add(_lastState);
  }

  /// Follows the screen of whichever terminal is current, if any.
  void _bindScreen(AgentTerminal? terminal) {
    if (identical(terminal, _boundTerminal)) return;
    unawaited(_screenSub?.cancel());
    _boundTerminal = terminal;
    _screenSub = terminal?.screenChanges.listen((_) => _onScreenChanged());
  }

  void _onScreenChanged() {
    if (_disposed || _screenChanges.isClosed) return;
    _screenChanges.add(null);
  }
}

/// A shell that lives until someone closes it — a user tab, or an agent
/// driving a long-lived shell.
@model
final class InteractiveShell extends ShellSession {
  InteractiveShell({
    required super.id,
    required super.host,
    required super.request,
  });

  @override
  ShellSessionKind get kind => ShellSessionKind.interactive;

  /// Brings the shell back up after it exited, reusing this session.
  void restart() => _logic.input(const StartShell());
}

/// A shell that runs one command and is reaped when it settles.
@model
final class EphemeralShell extends ShellSession {
  EphemeralShell({
    required super.id,
    required super.host,
    required super.request,
    required Future<TranscriptPage> record,
  }) : _record = record;

  final Future<TranscriptPage> _record;

  @override
  ShellSessionKind get kind => ShellSessionKind.ephemeral;

  /// Completes with the settled transcript once the repository reaps this.
  Future<TranscriptPage> get transcriptPage => _record;
}
