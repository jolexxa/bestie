import 'package:nocterm/nocterm.dart';

/// The colour of line numbers and hunk anchors beside code.
const gutterColor = Color.fromRGB(98, 114, 164);

/// A right-aligned [lineNumber], or a blank of the same size when there is
/// none, in a gutter [width] columns wide plus its trailing space.
InlineSpan gutterSpan(int? lineNumber, int width) => TextSpan(
  text: '${(lineNumber?.toString() ?? '').padLeft(width)} ',
  style: const TextStyle(color: gutterColor),
);
