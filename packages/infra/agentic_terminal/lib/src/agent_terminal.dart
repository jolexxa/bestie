import 'dart:async';

import 'package:agentic_terminal/src/terminal_key.dart';
import 'package:process_host/process_host.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:vt_parser/vt_parser.dart';

/// A fully-wired terminal session: supervised process + parser + screen
/// in one handle. This is the primary entry point for agents that want
/// to drive interactive TUI programs.
class AgentTerminal {
  AgentTerminal._({
    required this.screen,
    required RunningProcess process,
    required StreamSubscription<List<int>> outputSubscription,
    required Sink<List<int>> outbound,
    required StreamController<void> screenChanges,
  }) : _process = process,
       _outputSub = outputSubscription,
       _outbound = outbound,
       _screenChanges = screenChanges;

  /// Wire an already-running [process] to a VT parser and screen model,
  /// and start piping bytes.
  ///
  /// [process] must have been spawned on a terminal (not piped) at
  /// [rows]×[cols], so the screen grid matches what the child believes
  /// it is drawing to. `TerminalHost` pairs the two; call it rather than
  /// this directly unless you are building a host.
  factory AgentTerminal.attach(
    RunningProcess process, {
    required int rows,
    required int cols,
    required int scrollbackBytes,
  }) {
    final outbound = _OutboundToProcess(process);
    final screen = Screen(
      rows: rows,
      cols: cols,
      scrollbackBytes: scrollbackBytes,
      resizeBehavior: process.childRepaintsOnResize
          ? const RepaintingResize()
          : const ReflowingResize(),
      outbound: outbound,
    );
    final parser = VtParser(sink: screen);
    final screenChanges = StreamController<void>.broadcast();

    return AgentTerminal._(
      screen: screen,
      process: process,
      outbound: outbound,
      screenChanges: screenChanges,
      outputSubscription: process.stdout.listen((chunk) {
        parser.advance(chunk);
        if (!screenChanges.isClosed) screenChanges.add(null);
      }),
    );
  }

  final RunningProcess _process;
  final Sink<List<int>> _outbound;
  final StreamSubscription<List<int>> _outputSub;
  final StreamController<void> _screenChanges;

  /// Fires after each chunk of the child's output has been applied to
  /// [screen].
  Stream<void> get screenChanges => _screenChanges.stream;

  /// The live screen model. Read cells, check cursor position,
  /// inspect modes, take snapshots.
  final Screen screen;

  // --- Observation

  /// Take an immutable snapshot of the current screen state.
  ScreenSnapshot snapshot({bool includeScrollback = false}) =>
      screen.snapshot(includeScrollback: includeScrollback);

  /// Wait until the visible text contains [needle].
  Future<ScreenSnapshot> waitForText(
    String needle, {
    required Duration timeout,
  }) => screen.waitForText(needle, timeout: timeout);

  /// Wait until the visible text matches [pattern].
  Future<ScreenSnapshot> waitForRegex(
    RegExp pattern, {
    required Duration timeout,
  }) => screen.waitForRegex(pattern, timeout: timeout);

  /// Wait until [predicate] returns `true` for a fresh snapshot.
  Future<ScreenSnapshot> waitFor(
    bool Function(ScreenSnapshot) predicate, {
    required Duration timeout,
  }) => screen.waitFor(predicate, timeout: timeout);

  // --- Input -----------------------------------------------------------------

  /// Send a string to the child's stdin.
  void writeString(String input) => _process.writeString(input);

  /// Send raw bytes to the child's stdin.
  void writeBytes(List<int> bytes) => _process.writeBytes(bytes);

  /// Send a named key sequence.
  void sendKey(TerminalKey key) => _process.writeString(key.sequence);

  // --- Lifecycle

  /// Resize the terminal, updating both the child's window size
  /// and the screen grid. Dimensions floor at one cell — a collapsed
  /// host pane must still describe a real terminal to the child.
  void resize({required int rows, required int cols}) {
    final clampedRows = rows < 1 ? 1 : rows;
    final clampedCols = cols < 1 ? 1 : cols;
    _process.resize(rows: clampedRows, cols: clampedCols);
    screen.resize(rows: clampedRows, cols: clampedCols);
  }

  /// The child's exit status. Resolves when the process dies.
  Future<ProcessExit> get exit => _process.exit;

  /// The child's pid, once the platform reports it. Most callers can
  /// ignore this — useful only for diagnostics / direct signalling.
  Future<int> get pid => _process.pid;

  /// Stop the child immediately.
  Future<void> kill() async {
    await _process.kill(force: true);
  }

  /// Tear down: stop painting, close the screen's reply channel, kill
  /// the child, and release the process so its resources don't leak
  /// across respawns.
  Future<void> close() async {
    await _outputSub.cancel();
    await _screenChanges.close();
    _outbound.close();
    await _process.kill(force: true);
    await _process.close();
  }
}

/// A [Sink<List<int>>] that forwards outbound replies from the screen
/// back to the child's stdin.
class _OutboundToProcess implements Sink<List<int>> {
  _OutboundToProcess(this._process);
  final RunningProcess _process;

  @override
  void add(List<int> data) => _process.writeBytes(data);

  @override
  void close() {}
}
