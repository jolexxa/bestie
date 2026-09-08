import 'package:math_render/src/math_grid.dart';

/// The Private-Use codepoint katex uses for the `\not` slash. It is emitted
/// immediately before the relation it negates (e.g. `\neq` → slash + `=`); a
/// terminal font has no glyph there, so it renders as tofu.
const _notSlash = '';

/// Relation glyph → its precomposed negation, applied to the `\not` slash + the
/// relation so `\neq`/`\notin`/… become clean single characters.
const _negations = <String, String>{
  '=': '≠',
  '<': '≮',
  '>': '≯',
  '∈': '∉',
  '⊂': '⊄',
  '⊆': '⊈',
  '≡': '≢',
  '∼': '≁',
};

String _collapse(String line) {
  if (!line.contains(_notSlash)) return line;
  var result = line;
  for (final entry in _negations.entries) {
    // Trailing space keeps the relation's right-hand spacing (katex drops it
    // for `\not`) and, in a grid, preserves each row's column count.
    result = result.replaceAll('$_notSlash${entry.key}', '${entry.value} ');
  }
  return result;
}

/// Collapses `\not`-negation pairs in a single line of inline text.
String fixInlineGlyphs(String line) => _collapse(line).trim();

/// Collapses `\not`-negation pairs across grid rows, keeping each row's width
/// and every cell's tag.
List<List<MathCell>> fixGridCells(List<List<MathCell>> rows) => [
  for (final row in rows) _collapseCells(row),
];

List<MathCell> _collapseCells(List<MathCell> row) {
  if (!row.any((cell) => cell.cluster == _notSlash)) return row;
  final result = <MathCell>[];
  for (var i = 0; i < row.length; i++) {
    final cell = row[i];
    final next = i + 1 < row.length ? row[i + 1] : null;
    if (cell.cluster == _notSlash && next != null) {
      final negation = _negations[next.cluster];
      if (negation != null) {
        // Trailing space keeps the relation's right-hand spacing (katex drops
        // it for `\not`) and preserves the row's column count.
        result
          ..add(MathCell(negation, next.slot))
          ..add(MathCell(' ', next.slot));
        i++;
        continue;
      }
    }
    result.add(cell);
  }
  return result;
}
