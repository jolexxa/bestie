import 'dart:convert';

import 'package:byte_codec/byte_codec.dart';
import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/line_bytes.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/pen_codec.dart';

/// Gathers cells into one line's text and the pen beside it, closing a run
/// exactly where the pen changes so the runs cover the text end to end, and
/// reusing both buffers across [reset] so recording a whole history allocates
/// nothing per line.
class LineWriter {
  /// The line's text, as UTF-8.
  final ByteWriter text = ByteWriter();

  /// The pen behind it, left empty when the line used only the default one.
  final ByteWriter pen = ByteWriter();

  int _openLength = 0;
  int _openFg = packedDefaultFg;
  int _openBg = packedDefaultBg;
  int _openAttrs = CellAttrs.none;
  bool _styled = false;
  int _units = 0;

  /// UTF-16 code units written so far, counted on the way past because UTF-8
  /// bytes cannot be turned back into them without decoding.
  int get units => _units;

  /// Takes one content cell, drawn as [code] under the given pen, reaching
  /// [decode] only for a cluster of more than one code point.
  void add(
    int code,
    String Function(int code) decode, {
    required int fg,
    required int bg,
    required int attrs,
  }) {
    if (_openLength > 0 &&
        (fg != _openFg || bg != _openBg || attrs != _openAttrs)) {
      _closeRun();
    }
    if (_openLength == 0) {
      _openFg = fg;
      _openBg = bg;
      _openAttrs = attrs;
    }
    _openLength += _writeChar(code, decode);
  }

  /// Writes the cell's bytes, answering with how many it took.
  int _writeChar(int code, String Function(int code) decode) {
    // A blank cell reads as a space, and anything under 0x80 is its own
    // byte — which is nearly all of a transcript, and the cheapest possible
    // thing to write. Only a real cluster pays for a string and an encode.
    if (code == 0) {
      text.byte(0x20);
      _units += 1;
      return 1;
    }
    if (code < 0x80) {
      text.byte(code);
      _units += 1;
      return 1;
    }
    final drawn = decode(code);
    final bytes = utf8.encode(drawn);
    text.bytes(bytes);
    _units += drawn.length;
    return bytes.length;
  }

  /// The line copied out of both buffers, for a caller gathering lines rather
  /// than passing each one straight on.
  LineBytes take() =>
      LineBytes(text: text.take(), pen: pen.take(), units: _units);

  /// Ends the line, leaving [text] and [pen] holding it — and leaving [pen]
  /// empty for a line drawn entirely in the terminal's own.
  void end() {
    _closeRun();
    if (!_styled) pen.reset();
  }

  /// Drops the line, keeping both buffers for the next one.
  void reset() {
    text.reset();
    pen.reset();
    _openLength = 0;
    _openFg = packedDefaultFg;
    _openBg = packedDefaultBg;
    _openAttrs = CellAttrs.none;
    _styled = false;
    _units = 0;
  }

  void _closeRun() {
    if (_openLength == 0) return;
    if (_openFg != packedDefaultFg ||
        _openBg != packedDefaultBg ||
        _openAttrs != CellAttrs.none) {
      _styled = true;
    }
    writePenRun(
      pen,
      byteLen: _openLength,
      fg: _openFg,
      bg: _openBg,
      attrs: _openAttrs,
    );
    _openLength = 0;
  }
}
