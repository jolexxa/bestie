import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/recorded_shell.dart';
import 'package:shell_repository/src/session/session_transcript.dart';
import 'package:shell_repository/src/session/shell_session.dart';
import 'package:shell_repository/src/session/shell_session_request.dart';
import 'package:shell_repository/src/session/shell_session_summary.dart';
import 'package:shell_repository/src/session/terminal_surface.dart';
import 'package:shell_repository/src/session/tracked_session.dart';
import 'package:shell_repository/src/session/transcript_page.dart';
import 'package:shell_repository/src/session/transcript_reader.dart';

/// Domain-layer repository that owns the lifecycle of [ShellSession]s and
/// publishes the roster as it changes.
@repository
class ShellRepository {
  /// Spawns every session through [host] and persists transcripts with
  /// [files].
  ShellRepository({required TerminalHost host, required FilesDataSource files})
    : _host = host,
      _files = files;

  final TerminalHost _host;
  final FilesDataSource _files;
  final Map<ShellSessionId, TrackedSession> _sessions = {};
  final Map<ShellSessionId, SessionTranscript> _transcripts = {};
  final Map<ShellSessionId, Completer<TranscriptPage>> _endings = {};
  final _summariesController =
      StreamController<List<ShellSessionSummary>>.broadcast();

  int _counter = 0;
  bool _disposed = false;

  // ── Access ────────────────────────────────────────────

  /// Emits the roster each time it changes — a session opens, closes, or
  /// moves through its lifecycle.
  Stream<List<ShellSessionSummary>> get sessionsStream =>
      _summariesController.stream;

  /// Current roster snapshot.
  List<ShellSessionSummary> get sessions => List.unmodifiable([
    for (final tracked in _sessions.values) tracked.summary,
  ]);

  /// The session registered under [id], or null once it has been closed.
  ShellSession? sessionFor(ShellSessionId id) => _sessions[id]?.session;

  /// Ephemeral shells running right now, which is as many as are recording.
  int get runningEphemeralShells => _sessions.values
      .where((tracked) => tracked.session is EphemeralShell)
      .length;

  // ── Transcripts ───────────────────────────────────────

  /// The characters of the transcript at [path] from [at], as many as
  /// [length] holds.
  Future<TranscriptPage> readTranscript(
    String path, {
    required int length,
    int at = 0,
  }) => _reading(path, (reader) => reader.window(at: at, length: length));

  /// The bytes that draw [limit] lines of the transcript at [path] from
  /// [offset] back onto a terminal.
  Future<Uint8List> replayTranscript(
    String path, {
    int offset = 0,
    int? limit,
  }) => _reading(path, (reader) => reader.ansi(offset: offset, limit: limit));

  /// The recorded transcript at [path] put back on a terminal of its own,
  /// parsed off the main isolate.
  Future<TerminalSurface> recordedShellFor(
    String path, {
    int rows = 24,
    int cols = 80,
    int scrollbackBytes = defaultReplayScrollbackBytes,
  }) async {
    final ansi = await replayTranscript(path);
    final screen = await Isolate.run(
      () => Screen.fromAnsi(
        ansi,
        rows: rows,
        cols: cols,
        scrollbackBytes: scrollbackBytes,
      ),
    );
    return RecordedShell(screen: screen);
  }

  /// Runs [read] against whichever reader serves [path] — a live transcript if
  /// one records it, else a stored one opened and closed for the read.
  Future<T> _reading<T>(
    String path,
    Future<T> Function(TranscriptReader reader) read,
  ) async {
    final resolved = _files.pathOf(path);
    for (final transcript in _transcripts.values) {
      if (transcript.path == resolved) return read(transcript);
    }
    final record = await _files.openRecords(resolved);
    final reader = record == null
        ? EmptyTranscript(resolved)
        : StoredTranscript(record);
    try {
      return await read(reader);
    } finally {
      await reader.dispose();
    }
  }

  /// What a session nobody asked to record has to show for itself.
  static final TranscriptPage _nothingCaptured = TranscriptPage.empty(
    at: 0,
    totalChars: 0,
    totalLines: 0,
  );

  // ── Lifecycle ─────────────────────────────────────────

  /// Brings up an interactive shell described by [request] and tracks it.
  InteractiveShell open(ShellSessionRequest request) {
    final id = 'shell:${_counter++}';
    final session = InteractiveShell(id: id, host: _host, request: request);
    _sessions[id] = TrackedSession(
      session: session,
      stateSub: session.stream.listen((_) => _emit()),
      titleSub: session.titleChanges.listen((_) => _emit()),
    );
    _emit();
    return session;
  }

  /// Brings up an ephemeral shell recording to [path], and reaps it once it
  /// settles.
  Future<EphemeralShell> openEphemeral(
    ShellSessionRequest request, {
    required String path,
    required int endingChars,
  }) async {
    final record = await _files.openRecordFile(path);
    final id = 'shell:${_counter++}';
    final ending = Completer<TranscriptPage>();
    final session = EphemeralShell(
      id: id,
      host: _host,
      request: request,
      record: ending.future,
    );
    _endings[id] = ending;
    _transcripts[id] = SessionTranscript(
      session: session,
      record: record,
      endingChars: endingChars,
    );
    _sessions[id] = TrackedSession(
      session: session,
      stateSub: session.stream.listen((_) {
        _emit();
        if (session.atRest) unawaited(close(id));
      }),
      titleSub: session.titleChanges.listen((_) => _emit()),
    );
    _emit();
    return session;
  }

  /// Closes the session under [id], keeping whatever it recorded and answering
  /// with the end of that record.
  Future<TranscriptPage> close(ShellSessionId id) async {
    final tracked = _sessions.remove(id);
    if (tracked == null) return _nothingCaptured;
    final page =
        await (_transcripts.remove(id)?.finish() ??
            Future.value(_nothingCaptured));
    _endings.remove(id)?.complete(page);
    await tracked.release();
    _emit();
    return page;
  }

  /// Closes every session and stops publishing. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final transcript in _transcripts.values) {
      await transcript.abandon();
    }
    _transcripts.clear();
    for (final ending in _endings.values) {
      if (!ending.isCompleted) ending.complete(_nothingCaptured);
    }
    _endings.clear();
    for (final tracked in _sessions.values) {
      await tracked.release();
    }
    _sessions.clear();
    await _summariesController.close();
  }

  void _emit() {
    if (_disposed || _summariesController.isClosed) return;
    _summariesController.add(sessions);
  }
}
