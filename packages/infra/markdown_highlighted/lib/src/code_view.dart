import 'package:markdown_highlighted/src/internal/backdrop.dart';
import 'package:markdown_highlighted/src/internal/gutter.dart';
import 'package:markdown_highlighted/src/syntax_highlight.dart';
import 'package:markdown_highlighted/src/theme/highlight_theme.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a whole file as numbered, syntax-highlighted lines over the
/// theme's backdrop: the rows of a diff view without the signs.
class CodeView extends StatelessComponent {
  /// Creates a code view over [code].
  const CodeView(
    this.code, {
    super.key,
    this.theme = HighlightTheme.dracula,
    this.language,
    this.showLineNumbers = true,
  });

  /// The text to render.
  final String code;

  /// Theme used to highlight each line, and whose background is painted
  /// behind the block. Defaults to [HighlightTheme.dracula].
  final HighlightTheme theme;

  /// The language every line is highlighted as. `null` renders plain text.
  final String? language;

  /// Whether to show the line-number gutter.
  final bool showLineNumbers;

  @override
  Component build(BuildContext context) => paintBackdrop(
    RichText(
      text: codeSpan(
        code,
        theme: theme,
        language: language,
        showLineNumbers: showLineNumbers,
      ),
    ),
    theme.background,
  );
}

/// Renders [code] as a single [InlineSpan] tree, one row per line — the same
/// output as the [CodeView] widget, for embedding in a larger span. A final
/// newline ends the last line rather than starting an empty one.
InlineSpan codeSpan(
  String code, {
  HighlightTheme theme = HighlightTheme.dracula,
  String? language,
  bool showLineNumbers = true,
}) {
  final lines = code.isEmpty ? <String>[] : code.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  final width = lines.length.toString().length;
  return TextSpan(
    children: [
      for (final (index, line) in lines.indexed)
        TextSpan(
          children: [
            if (index > 0) const TextSpan(text: '\n'),
            if (showLineNumbers) gutterSpan(index + 1, width),
            highlightSpan(
              code: line,
              language: language,
              theme: theme,
              autoDetect: false,
            ),
          ],
        ),
    ],
  );
}
