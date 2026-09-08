import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/line_bytes.dart';
import 'package:terminal_screen/src/line_writer.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:terminal_screen/src/selection_text.dart';

/// Renders the logical lines of [source] as bytes with the pen behind each,
/// taking cells as character codes rather than strings so the ordinary ones
/// go straight out as bytes.
List<LineBytes> renderPenLines(
  ReflowSource source, {
  required int Function(int row, int col) codeAt,
  required String Function(int code) decode,
  required int Function(int row, int col) fgAt,
  required int Function(int row, int col) bgAt,
  required int Function(int row, int col) attrsAt,
}) {
  final last = lastContentRow(source);
  final lines = <LineBytes>[];
  final writer = LineWriter();

  for (var row = 0; row <= last; row++) {
    final cols = trimmedLengthAt(source, row);
    for (var col = 0; col < cols; col++) {
      if (source.widthAt(row, col) == CellWidth.continuation) continue;
      writer.add(
        codeAt(row, col),
        decode,
        fg: fgAt(row, col),
        bg: bgAt(row, col),
        attrs: attrsAt(row, col),
      );
    }
    if (row == last || !wrapsToNext(source, row)) {
      writer.end();
      lines.add(writer.take());
      writer.reset();
    }
  }

  return lines;
}

/// Recording a line of history without a [ReflowSource] in between.
extension LogicalLineRecording on LogicalLine {
  /// Writes this line into the caller's [writer], decoding each cell through
  /// [decode], so recording a whole history costs no allocation per line.
  void writeInto(LineWriter writer, String Function(int code) decode) {
    for (var col = 0; col < length; col++) {
      final style = styleAt(col);
      if (styleWidth(style) == CellWidth.continuation) continue;
      writer.add(
        charCodeAt(col),
        decode,
        fg: fgAt(col),
        bg: bgAt(col),
        attrs: styleAttrs(style),
      );
    }
    writer.end();
  }
}
