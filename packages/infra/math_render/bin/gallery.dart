import 'dart:io';

import 'package:math_render/math_render.dart';

/// A tour of what the terminal math renderer can draw.
///
/// Run the whole gallery:
///
/// ```sh
/// dart run math_render:gallery
/// ```
///
/// Or render your own expression (add `--inline` for inline style):
///
/// ```sh
/// dart run math_render:gallery '\int_0^1 \frac{x^2}{\sqrt{1-x}}\, dx'
/// ```
///
/// `--color` colours by symbol and `--sketch` prints the tag overlay beside the
/// render, which is the quickest way to see what the tagger decided.
const _gallery = <String>[
  r'4 \times 8 + 3^{\log(315)}',
  r'e^{i\pi} + 1 = 0',
  r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
  r'\sum_{i=0}^{n} \frac{i^2}{2}',
  r'\prod_{k=1}^{n} \frac{1}{k}',
  r'\int_0^\infty \frac{x^2}{e^x - 1}\, dx',
  r'\oint_C \vec{F} \cdot d\vec{r}',
  r'\sqrt{\frac{a}{b}}',
  r'\left(\frac{a}{b}\right)^2',
  r'\left[\frac{\partial f}{\partial x}\right]',
  r'\left\{ x : x^2 < \frac{1}{2} \right\}',
  r'\lim_{x \to 0} \frac{\sin x}{x}',
  r'\begin{matrix} a & b \\ c & d \end{matrix}',
];

/// Stand-in term colours for the gallery only. The app derives its own from
/// whichever theme is active; these are just four distinguishable slots so the
/// cycling can be eyeballed from a terminal.
const _slotColors = ['\x1b[36m', '\x1b[33m', '\x1b[35m', '\x1b[32m'];
const _dim = '\x1b[2m';
const _reset = '\x1b[0m';

void main(List<String> args) {
  final rest = [...args];
  final inline = rest.remove('--inline');
  final color = rest.remove('--color');
  final showSketch = rest.remove('--sketch');
  final expressions = rest.isNotEmpty ? [rest.join(' ')] : _gallery;

  for (final tex in expressions) {
    stdout.writeln('\n$_dim$tex$_reset');
    final result = renderMath(
      tex,
      displayMode: !inline,
      tagger: color || showSketch ? tagSymbols : tagNothing,
    );
    switch (result) {
      case MathRendered(:final grid):
        final sketch = grid.slotSketch().split('\n');
        final runs = grid.rowRuns();
        for (var i = 0; i < runs.length; i++) {
          final row = color ? _paint(runs[i]) : grid.lines[i];
          stdout.writeln(showSketch ? '$row  $_dim${sketch[i]}$_reset' : row);
        }
      case MathParseFailed(:final message):
        stdout.writeln('  parse error: $message');
    }
  }
}

String _paint(List<MathRun> runs) {
  final buffer = StringBuffer();
  for (final run in runs) {
    final slot = run.slot;
    if (slot == null) {
      buffer.write(run.text);
      continue;
    }
    buffer.write(
      '${_slotColors[slot % _slotColors.length]}${run.text}$_reset',
    );
  }
  return buffer.toString();
}
