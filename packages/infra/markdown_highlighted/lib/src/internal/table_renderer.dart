import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:math_render/math_render.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a markdown `<table>` element into a single ASCII-bordered
/// [InlineSpan]. Lifted from nocterm's `MarkdownText` visitor — kept as pure
/// static helpers here so the package's visitor stays focused on AST
/// traversal.
///
/// Cells are width-distributed to fit `maxWidth` terminal columns when
/// possible, with proportional shrinking and word wrap when the natural width
/// exceeds the budget.
class TableRenderer {
  /// Renders [table] (an `md.Element` with tag `table`) into an [InlineSpan].
  /// Returns an empty span when the table has no rows.
  static InlineSpan render(md.Element table, {int? maxWidth}) {
    final rows = <List<String>>[];
    final naturalWidths = <int>[];
    final requiredWidths = <int>[];

    if (table.children != null) {
      for (final child in table.children!) {
        if (child is! md.Element) continue;
        if (child.tag != 'thead' && child.tag != 'tbody') continue;
        if (child.children == null) continue;
        for (final row in child.children!) {
          if (row is! md.Element || row.tag != 'tr') continue;
          final cells = <String>[];
          if (row.children != null) {
            for (final cell in row.children!) {
              if (cell is md.Element &&
                  (cell.tag == 'th' || cell.tag == 'td')) {
                cells.add(_cellText(cell));
              }
            }
          }
          rows.add(cells);
          for (var i = 0; i < cells.length; i++) {
            if (i >= naturalWidths.length) {
              naturalWidths.add(0);
              requiredWidths.add(0);
            }
            final cellWidth = UnicodeWidth.stringWidth(cells[i]);
            naturalWidths[i] = naturalWidths[i] > cellWidth
                ? naturalWidths[i]
                : cellWidth;
            final wordWidth = _longestWord(cells[i]);
            requiredWidths[i] = requiredWidths[i] > wordWidth
                ? requiredWidths[i]
                : wordWidth;
          }
        }
      }
    }

    if (rows.isEmpty || naturalWidths.isEmpty) {
      return const TextSpan(text: '');
    }

    final columnWidths = _distributeColumnWidths(
      naturalWidths,
      requiredWidths,
      maxWidth,
    );

    final wrappedRows = <List<List<String>>>[];
    for (final row in rows) {
      final wrappedCells = <List<String>>[];
      for (var c = 0; c < naturalWidths.length; c++) {
        final content = c < row.length ? row[c] : '';
        wrappedCells.add(_wrapCell(content, columnWidths[c]));
      }
      wrappedRows.add(wrappedCells);
    }

    final buffer = StringBuffer();
    _writeHorizontalBorder(buffer, columnWidths, '┌', '─', '┬', '┐');

    for (var r = 0; r < wrappedRows.length; r++) {
      final rowCells = wrappedRows[r];
      final rowHeight = rowCells.fold(
        1,
        (max, cell) => math.max(max, cell.length),
      );

      for (var l = 0; l < rowHeight; l++) {
        buffer.write('│');
        for (var c = 0; c < columnWidths.length; c++) {
          final lines = c < rowCells.length ? rowCells[c] : const [''];
          final line = l < lines.length ? lines[l] : '';
          final displayWidth = UnicodeWidth.stringWidth(line);
          final paddingNeeded = columnWidths[c] - displayWidth;
          buffer
            ..write(' ')
            ..write(line);
          if (paddingNeeded > 0) {
            buffer.write(' ' * paddingNeeded);
          }
          buffer.write(' │');
        }
        buffer.write('\n');
      }

      if (r == 0 && wrappedRows.length > 1) {
        _writeHorizontalBorder(buffer, columnWidths, '├', '─', '┼', '┤');
      }
    }

    _writeHorizontalBorder(buffer, columnWidths, '└', '─', '┴', '┘');
    return TextSpan(text: buffer.toString());
  }

  /// Flattens a cell to plain text, linearizing any `math` / `mathDisplay`
  /// elements to their single-row unicode form so math survives the table's
  /// per-cell text model. Falls back to the raw TeX on a parse failure.
  static String _cellText(md.Element cell) {
    final buffer = StringBuffer();
    _writeCell(cell, buffer);
    return buffer.toString();
  }

  static void _writeCell(md.Node node, StringBuffer buffer) {
    if (node is! md.Element) {
      buffer.write(node.textContent);
      return;
    }
    if (node.tag == 'math' || node.tag == 'mathDisplay') {
      final result = renderMathInline(node.textContent);
      buffer.write(switch (result) {
        MathInlineRendered(:final line) => line,
        MathInlineParseFailed() => node.textContent,
      });
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      _writeCell(child, buffer);
    }
  }

  /// Distributes column widths to fit within [maxWidth].
  ///
  /// Algorithm (CSS-table-ish):
  /// 1. If every column's natural (one-line) width fits, use natural.
  /// 2. Otherwise, each column gets at least its **required** width (the
  ///    widest single word in any of its cells — the smallest width that
  ///    avoids mid-word breaks). Any remaining budget is then distributed
  ///    among columns proportionally to their **flex** = natural − required.
  /// 3. If even the required widths can't fit, fall back to the original
  ///    proportional-shrink-by-natural algorithm with a `minColWidth` floor.
  ///    This produces ugly mid-word breaks but never overflows.
  static List<int> _distributeColumnWidths(
    List<int> naturalWidths,
    List<int> requiredWidths,
    int? maxWidth,
  ) {
    final numCols = naturalWidths.length;
    final overhead = 3 * numCols + 1;
    final naturalTotal = naturalWidths.fold(0, (sum, w) => sum + w);

    if (maxWidth == null || naturalTotal + overhead <= maxWidth) {
      return List.of(naturalWidths);
    }

    final available = maxWidth - overhead;
    final requiredTotal = requiredWidths.fold(0, (sum, w) => sum + w);

    if (requiredTotal > available) {
      // Even required widths overflow — fall back to proportional shrink
      // (the old algorithm, which accepts mid-word breaks).
      return _proportionalShrink(naturalWidths, available, numCols);
    }

    // Allocate required width to each column, then split the remaining
    // budget by flex (natural − required). totalFlex is guaranteed > 0 here:
    // we reach this branch only when naturalTotal > available ≥ requiredTotal,
    // which implies sum(natural − required) > 0.
    final result = List<int>.from(requiredWidths);
    var remaining = available - requiredTotal;
    final flex = [
      for (var i = 0; i < numCols; i++)
        math.max(0, naturalWidths[i] - requiredWidths[i]),
    ];
    final totalFlex = flex.fold(0, (sum, f) => sum + f);

    var distributed = 0;
    for (var i = 0; i < numCols; i++) {
      final share = (flex[i] * remaining / totalFlex).floor();
      result[i] += share;
      distributed += share;
    }
    remaining -= distributed;

    // Hand any rounding leftovers to the columns with the most unfilled flex,
    // one column at a time. The loop terminates because:
    //   total unfilled flex == remaining (each `share` is a floor of its
    //   true proportional cut, so the dropped fractions sum to `remaining`),
    // so at least one column always has deficit > 0 while remaining > 0.
    while (remaining > 0) {
      var bestIdx = 0;
      var bestDeficit = 0;
      for (var i = 0; i < numCols; i++) {
        final deficit = naturalWidths[i] - result[i];
        if (deficit > bestDeficit) {
          bestDeficit = deficit;
          bestIdx = i;
        }
      }
      result[bestIdx]++;
      remaining--;
    }

    return result;
  }

  /// Original "shrink everything by natural ratio" algorithm, used when even
  /// the required widths overflow the budget. Keeps the `minColWidth` floor
  /// so narrow columns don't disappear, then reclaims any over-allocation
  /// from the widest column.
  static List<int> _proportionalShrink(
    List<int> naturalWidths,
    int available,
    int numCols,
  ) {
    const minColWidth = 3;
    if (available < numCols * minColWidth) {
      return List.filled(numCols, minColWidth);
    }

    final result = List<int>.filled(numCols, 0);
    final totalNatural = naturalWidths.fold(0, (sum, w) => sum + w);

    var allocated = 0;
    for (var i = 0; i < numCols; i++) {
      result[i] = math.max(
        minColWidth,
        (naturalWidths[i] * available / totalNatural).floor(),
      );
      allocated += result[i];
    }

    var remaining = available - allocated;
    while (remaining > 0) {
      var bestIdx = 0;
      var bestDeficit = 0;
      for (var i = 0; i < numCols; i++) {
        final deficit = naturalWidths[i] - result[i];
        if (deficit > bestDeficit) {
          bestDeficit = deficit;
          bestIdx = i;
        }
      }
      if (bestDeficit == 0) break;
      result[bestIdx]++;
      remaining--;
    }

    while (remaining < 0) {
      var bestIdx = 0;
      var bestExcess = 0;
      for (var i = 0; i < numCols; i++) {
        final excess = result[i] - minColWidth;
        if (excess > bestExcess) {
          bestExcess = excess;
          bestIdx = i;
        }
      }
      if (bestExcess == 0) break;
      result[bestIdx]--;
      remaining++;
    }

    return result;
  }

  /// Returns the visual width of the widest whitespace-separated token in
  /// [text]. Used as a column's "required" width — the smallest width that
  /// avoids breaking words mid-character.
  static int _longestWord(String text) {
    var max = 0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final w = UnicodeWidth.stringWidth(word);
      if (w > max) max = w;
    }
    return max;
  }

  static List<String> _wrapCell(String content, int cellWidth) {
    if (cellWidth <= 0) return [''];
    if (UnicodeWidth.stringWidth(content) <= cellWidth) return [content];

    final lines = <String>[];
    final words = content.split(' ');
    var currentLine = '';
    var currentWidth = 0;

    for (final word in words) {
      final wordWidth = UnicodeWidth.stringWidth(word);

      if (currentWidth == 0) {
        if (wordWidth > cellWidth) {
          lines.addAll(_breakLongWord(word, cellWidth));
          final lastLine = lines.removeLast();
          currentLine = lastLine;
          currentWidth = UnicodeWidth.stringWidth(lastLine);
        } else {
          currentLine = word;
          currentWidth = wordWidth;
        }
      } else if (currentWidth + 1 + wordWidth <= cellWidth) {
        currentLine += ' $word';
        currentWidth += 1 + wordWidth;
      } else {
        lines.add(currentLine);
        if (wordWidth > cellWidth) {
          lines.addAll(_breakLongWord(word, cellWidth));
          final lastLine = lines.removeLast();
          currentLine = lastLine;
          currentWidth = UnicodeWidth.stringWidth(lastLine);
        } else {
          currentLine = word;
          currentWidth = wordWidth;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines.isEmpty ? [''] : lines;
  }

  static List<String> _breakLongWord(String word, int maxWidth) {
    final parts = <String>[];
    var current = '';
    var currentWidth = 0;

    for (final grapheme in word.characters) {
      final w = UnicodeWidth.graphemeWidth(grapheme);
      if (currentWidth + w > maxWidth && current.isNotEmpty) {
        parts.add(current);
        current = grapheme;
        currentWidth = w;
      } else {
        current += grapheme;
        currentWidth += w;
      }
    }
    if (current.isNotEmpty) parts.add(current);
    return parts.isEmpty ? [''] : parts;
  }

  static void _writeHorizontalBorder(
    StringBuffer buffer,
    List<int> columnWidths,
    String left,
    String fill,
    String middle,
    String right,
  ) {
    buffer.write(left);
    for (var i = 0; i < columnWidths.length; i++) {
      buffer.write(fill * (columnWidths[i] + 2));
      if (i < columnWidths.length - 1) {
        buffer.write(middle);
      }
    }
    buffer
      ..write(right)
      ..write('\n');
  }
}
