// Recorded ConPTY sessions, replayed with no pty involved: `git status`
// printed at 120 columns, then the pty narrowed to 42 and widened back.
// The child repaints after each resize, and what it repaints is laid out by
// its own re-wrap rather than ours.
//
// Both captures came through bestie's own spawn path, so they carry what the
// `OpenConsole.exe` bestie ships beside its `conpty.dll` really emits. It
// reflows its own buffer and then reports only where the prompt landed,
// leaving the history above it to us — so nothing may be lost.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

/// Absolute path to a fixture, anchored to this package.
Future<String> _fixturePath(String name) async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:terminal_screen/terminal_screen.dart'),
  );
  return lib!.resolve('../test/fixtures/$name.jsonl').toFilePath();
}

/// The recorded child output and resizes, in the order they happened.
Future<List<Map<String, dynamic>>> _journal(String name) async =>
    File(await _fixturePath(name))
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();

String _read(int cols, CellData Function(int col) cell) {
  final out = StringBuffer();
  for (var col = 0; col < cols; col++) {
    final data = cell(col);
    if (data.width == CellWidth.continuation) continue;
    out.write(data.char);
  }
  return out.toString().trimRight();
}

/// Every row holding something a reader would see, oldest first.
List<String> _rows(Screen screen) => [
  for (var line = 0; line < screen.scrollbackLength; line++)
    _read(screen.cols, (col) => screen.scrollbackCellAt(line, col)),
  for (var row = 0; row < screen.rows; row++)
    _read(screen.cols, (col) => screen.cellAt(row, col)),
].where((row) => row.isNotEmpty).toList();

/// What a capture looked like before its first resize, and after its last.
class _Replay {
  const _Replay({required this.printed, required this.finished});

  final List<String> printed;
  final List<String> finished;

  /// Rows the child had printed that no longer read the same way.
  List<String> get lost =>
      printed.where((row) => !finished.toSet().contains(row)).toList();
}

Future<_Replay> _replay(String name) async {
  final events = await _journal(name);
  final start = events.firstWhere((event) => event['kind'] == 'start');
  final screen = Screen(
    rows: start['rows'] as int,
    cols: start['cols'] as int,
    scrollbackBytes: 1000 * 4096,
    resizeBehavior: const RepaintingResize(),
  );
  final parser = VtParser(sink: screen);

  List<String>? printed;
  for (final event in events) {
    switch (event['kind']) {
      case 'out':
        parser.advance(base64Decode(event['b64'] as String));
      case 'resize':
        screen.snapshot();
        printed ??= _rows(screen);
        screen.resize(rows: event['rows'] as int, cols: event['cols'] as int);
    }
  }
  screen.snapshot();

  return _Replay(printed: printed!, finished: _rows(screen));
}

void main() {
  // The captures start and end at the same width, so a row that survived is
  // a row that reads exactly as it did before.
  void expectRowCountHeld(_Replay replay) {
    expect(
      replay.finished,
      hasLength(replay.printed.length),
      reason: 'row count moved:\n${replay.finished.join('\n')}',
    );
  }

  group('the console host bestie ships', () {
    // OpenConsole reflows its own buffer and then says only where the prompt
    // landed, leaving everything above it to us. Nothing is lost, and that
    // is the whole reason bestie ships it.
    test('loses nothing across a resize', () async {
      final replay = await _replay('openconsole_resize');

      expectRowCountHeld(replay);
      expect(replay.lost, isEmpty);
    });

    test('loses nothing across a drag', () async {
      final replay = await _replay('openconsole_drag');

      expectRowCountHeld(replay);
      expect(replay.lost, isEmpty);
    });
  });
}
