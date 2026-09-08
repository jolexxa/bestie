import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/terminal_surface.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// Scrollback a recording holds.
const int defaultReplayScrollbackBytes = 8 << 20;

/// A stored transcript put back on a terminal of its own. The bytes are parsed
/// once — off the main isolate, before the shell is built — and resizing
/// reflows that parsed screen in place, the same path a live shell takes.
@model
final class RecordedShell implements TerminalSurface {
  RecordedShell({required Screen screen})
    : _screen = screen,
      _rows = screen.rows,
      _cols = screen.cols;

  final Screen _screen;
  int _rows;
  int _cols;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Screen? get screen => _screen;

  /// Always: a transcript is by definition of something already over.
  @override
  bool get exited => true;

  @override
  int get viewOffset => _screen.viewOffset;

  @override
  int setViewOffset(int offset) => _screen.setViewOffset(offset);

  /// Nothing: there is no child behind a transcript to type at.
  @override
  void write(List<int> bytes) {}

  @override
  void resize({required int rows, required int cols}) {
    if (rows == _rows && cols == _cols) return;
    _rows = rows;
    _cols = cols;
    _screen.resize(rows: rows, cols: cols);
    _publish();
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Releases the replay. Idempotent.
  Future<void> dispose() => _changes.close();
}
