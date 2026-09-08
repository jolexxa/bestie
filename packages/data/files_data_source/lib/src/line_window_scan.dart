import 'package:files_data_source/src/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Walks decoded text in one pass, keeping only the window asked of it.
@PartOf(FilesDataSource)
final class LineWindowScan {
  LineWindowScan({required LinePlace at, this.limit, this.chars})
    : _seekLine = at.line < 0 ? 0 : at.line,
      _seekInto = at.into < 0 ? 0 : at.into;

  final int _seekLine;
  final int _seekInto;

  /// Lines the window may span, unbounded when null.
  final int? limit;

  /// Characters the window may hold, unbounded when null.
  final int? chars;

  final StringBuffer _kept = StringBuffer();
  int _line = 0;
  int _col = 0;
  bool _pendingCR = false;
  int _startInto = 0;
  int _linesKept = 0;
  _Phase _phase = _Phase.seeking;

  /// Offers the next run of decoded text.
  void add(String chunk) {
    for (var i = 0; i < chunk.length; i++) {
      final unit = chunk.codeUnitAt(i);
      if (_pendingCR) {
        _pendingCR = false;
        _take(0x0A);
        if (unit == 0x0A) continue;
      }
      if (unit == 0x0D) {
        _pendingCR = true;
        continue;
      }
      _take(unit);
    }
  }

  /// The window as an excerpt, once the whole file has streamed by.
  Excerpt<LinePlace> finish() {
    if (_pendingCR) {
      _pendingCR = false;
      _take(0x0A);
    }
    final extent = LinePlace(line: _line, into: _col);
    final start = switch (_phase) {
      _Phase.seeking => LinePlace(
        line: _seekLine < extent.tally ? _seekLine : extent.tally,
      ),
      _Phase.skipping => LinePlace(line: _seekLine, into: _col),
      _Phase.capturing || _Phase.counting => LinePlace(
        line: _seekLine,
        into: _startInto,
      ),
    };
    return Excerpt.lines(_window(), at: start, extent: extent);
  }

  /// The captured text, never ending on the near half of a surrogate pair:
  /// a trailing half is always the cap's doing, and giving it back keeps
  /// [Excerpt.next] in front of the whole character.
  String _window() {
    final text = _kept.toString();
    if (text.isEmpty) return text;
    final last = text.codeUnitAt(text.length - 1);
    final splitsPair = last >= 0xD800 && last <= 0xDBFF;
    return splitsPair ? text.substring(0, text.length - 1) : text;
  }

  void _take(int unit) {
    if (_phase == _Phase.seeking && _line == _seekLine) {
      _phase = _Phase.skipping;
    }
    if (_phase == _Phase.skipping && !_opensAt(unit)) {
      _advance(unit);
      return;
    }
    if (_phase == _Phase.skipping) {
      _startInto = _col;
      _phase = _hasRoom ? _Phase.capturing : _Phase.counting;
    }
    if (_phase == _Phase.capturing) {
      _kept.writeCharCode(unit);
      if (unit == 0x0A) _linesKept += 1;
      if (!_hasRoom) _phase = _Phase.counting;
      _advance(unit);
      return;
    }
    _advance(unit);
  }

  /// Whether the window begins on [unit]: a newline opens it early, and the
  /// far half of a surrogate pair never opens it.
  bool _opensAt(int unit) {
    if (unit == 0x0A) return true;
    if (_col < _seekInto) return false;
    return !(_col > 0 && unit >= 0xDC00 && unit <= 0xDFFF);
  }

  /// Whether the window may still take more.
  bool get _hasRoom {
    final lines = limit;
    final units = chars;
    if (lines != null && _linesKept >= lines) return false;
    if (units != null && _kept.length >= units) return false;
    return true;
  }

  void _advance(int unit) {
    if (unit == 0x0A) {
      _line += 1;
      _col = 0;
    } else {
      _col += 1;
    }
  }
}

/// Where a scan stands: short of the window, inside its opening line, taking
/// it, or past it and only counting.
enum _Phase { seeking, skipping, capturing, counting }
