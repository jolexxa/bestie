import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/terminal_surface.dart';
import 'package:shell_repository/src/session/transcript_page.dart';
import 'package:shell_repository/src/session/transcript_reader.dart';
import 'package:shell_repository/src/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// One session's recording, kept fed and readable at once.
@PartOf(ShellRepository)
final class SessionTranscript extends TranscriptReader {
  SessionTranscript({
    required this.session,
    required RecordFile record,
    required this.endingChars,
  }) : _record = record {
    _states = session.changes.listen((_) => _followScreen());
    _followScreen();
  }

  /// The surface being recorded.
  final TerminalSurface session;

  /// How much of the end anyone asking for a summary of this gets.
  final int endingChars;

  final RecordFile _record;

  late final StreamSubscription<void> _states;

  /// The screen currently reporting to us.
  Screen? _bound;

  bool _closed = false;

  /// The end of the record, once there is one and the file has gone.
  TranscriptPage? _ending;

  @override
  String get path => _record.path;

  @override
  int get lines => _record.records + _live.lines.length;

  @override
  int get chars => _record.chars + _live.chars;

  @override
  bool get isLive => !_closed;

  @override
  Future<RecordCursor> locate(int at) async {
    final settled = _record.chars;
    if (at < settled) return _record.locate(at);
    final live = _live.locate(at - settled);
    return RecordCursor(_record.records + live.record, live.into);
  }

  @override
  Future<List<ByteRecord>> records(int from, int count) async {
    final settled = _record.records;
    final live = _live.lines;
    final total = settled + live.length;
    final start = from.clamp(0, total);
    final int end = math.min(total, start + math.max(0, count));

    final page = <ByteRecord>[];
    final lastSettled = math.min(end, settled);
    if (start < lastSettled) {
      page.addAll(await _record.read(start, lastSettled - start));
    }

    var at = start + page.length;
    for (var i = at - settled; i >= 0 && i < live.length && at < end; i++) {
      page.add(
        ByteRecord(body: live[i].text, note: live[i].pen, units: live[i].units),
      );
      at += 1;
    }
    return page;
  }

  /// Settles what is still on screen, closes the file, and answers with the
  /// end of the whole record.
  Future<TranscriptPage> finish() async {
    final done = _ending;
    if (done != null) return done;
    await _stop();
    for (final line in _live.lines) {
      _record.append(line.text, line.pen, weight: line.units);
    }
    _closed = true;
    await _record.finish();
    final end = await ending(length: endingChars);
    await _record.close();
    return _ending = end;
  }

  /// What an abandoned record has to show for itself: nothing at all.
  static final TranscriptPage _nothingKept = TranscriptPage.empty(
    at: 0,
    totalChars: 0,
    totalLines: 0,
  );

  /// Gives up on the record — the session is going away with it.
  Future<void> abandon() async {
    if (_closed) return;
    await _stop();
    _closed = true;
    _ending = _nothingKept;
    await _record.close();
  }

  /// Owned by the repository, which closes it through [finish] or [abandon].
  @override
  Future<void> dispose() async {}

  Future<void> _stop() async {
    _unbind();
    await _states.cancel();
  }

  void _unbind() {
    _bound?.onEvicted = null;
    _bound = null;
  }

  void _followScreen() {
    final screen = session.screen;
    if (identical(screen, _bound)) return;
    _unbind();
    _bound = screen;
    screen?.onEvicted = _settle;
  }

  /// Takes a line leaving the live half for good, its bytes belonging to the
  /// screen for exactly as long as copying them into the file's buffer takes.
  void _settle(Uint8List text, Uint8List pen, int units) =>
      _record.append(text, pen, weight: units);

  Screen? _cachedScreen;
  int _cachedAt = -1;
  _LiveLines _cached = _LiveLines.none;

  /// What is still on screen and has not settled, walked again only once the
  /// screen has changed, because a read asks for it several times over.
  _LiveLines get _live {
    if (_closed) return _LiveLines.none;
    final screen = session.screen;
    if (screen == null) return _LiveLines.none;
    if (identical(screen, _cachedScreen) && screen.mutationCount == _cachedAt) {
      return _cached;
    }
    _cachedScreen = screen;
    _cachedAt = screen.mutationCount;
    return _cached = _LiveLines(screen.recordedLines());
  }
}

/// The lines still on screen and where each of them begins, so the live half
/// of a recording is addressed the same way the settled half is.
final class _LiveLines {
  _LiveLines(this.lines) : marks = _marksOf(lines);

  const _LiveLines._none() : lines = const [], marks = const [0];

  /// No lines at all, which is what a screen that has gone away leaves —
  /// held rather than built, since every read of a closed record asks for it.
  static const _LiveLines none = _LiveLines._none();

  final List<LineBytes> lines;

  /// Characters before each line, and the whole of them last.
  final List<int> marks;

  /// Characters these lines occupy, each owning the separator behind it.
  int get chars => marks.last;

  /// Which of these lines holds the [at]th character, and how far into it.
  RecordCursor locate(int at) {
    if (at <= 0 || lines.isEmpty) return RecordCursor.start;
    if (at >= chars) return RecordCursor(lines.length, 0);

    var low = 0;
    var high = lines.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (marks[mid] <= at) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return RecordCursor(low, at - marks[low]);
  }

  static List<int> _marksOf(List<LineBytes> lines) {
    final marks = <int>[0];
    for (final line in lines) {
      marks.add(marks.last + line.units + 1);
    }
    return marks;
  }
}
