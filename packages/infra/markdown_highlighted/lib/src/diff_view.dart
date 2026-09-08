import 'package:markdown_highlighted/src/internal/backdrop.dart';
import 'package:markdown_highlighted/src/internal/gutter.dart';
import 'package:markdown_highlighted/src/internal/unified_diff.dart';
import 'package:markdown_highlighted/src/languages.dart';
import 'package:markdown_highlighted/src/syntax_highlight.dart';
import 'package:markdown_highlighted/src/theme/highlight_theme.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a git-style unified diff with line numbers and syntax-highlighted
/// content per line.
///
/// Accepts the diff as a raw string (the format produced by `git diff` or
/// `diff -u`). Multiple files in one diff are rendered with a path header
/// between them; multiple hunks per file are separated by a hunk anchor
/// (`@@ -a,b +c,d @@`).
///
/// The language used to syntax-highlight each line is inferred from the
/// file's path extension. Pass [contextLanguage] to override that, or to
/// supply a language when the diff has no file headers (a bare hunk).
class DiffView extends StatelessComponent {
  /// Creates a diff view from a raw unified diff string.
  const DiffView(
    this.diff, {
    super.key,
    this.theme = HighlightTheme.dracula,
    this.showLineNumbers = true,
    this.contextLanguage,
  });

  /// The unified diff text to render.
  final String diff;

  /// Theme used to highlight each line's body. Defaults to
  /// [HighlightTheme.dracula].
  final HighlightTheme theme;

  /// Whether to show the line-number gutter. When `false`, lines are still
  /// signed with `+`/`-`/` ` but the number column is omitted.
  final bool showLineNumbers;

  /// Override for language detection. When non-null, every line is
  /// highlighted using this language instead of the language inferred from
  /// each file's path. Useful for bare hunks (no file headers).
  final String? contextLanguage;

  @override
  Component build(BuildContext context) => paintBackdrop(
    RichText(
      text: diffSpan(
        diff,
        theme: theme,
        showLineNumbers: showLineNumbers,
        contextLanguage: contextLanguage,
      ),
    ),
    theme.background,
  );
}

/// Renders [diff] as a single [InlineSpan] tree — same output as the
/// [DiffView] widget, but suitable for embedding inside a larger [TextSpan]
/// structure (e.g. a markdown code block builder).
InlineSpan diffSpan(
  String diff, {
  HighlightTheme theme = HighlightTheme.dracula,
  bool showLineNumbers = true,
  String? contextLanguage,
}) {
  final parsed = UnifiedDiffParser.parse(diff);
  return TextSpan(
    children: _buildFileSpans(
      parsed.files,
      theme: theme,
      showLineNumbers: showLineNumbers,
      contextLanguage: contextLanguage,
    ),
  );
}

List<InlineSpan> _buildFileSpans(
  List<DiffFile> files, {
  required HighlightTheme theme,
  required bool showLineNumbers,
  required String? contextLanguage,
}) {
  final spans = <InlineSpan>[];
  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    final language = contextLanguage ?? inferLanguageFromPath(file.displayPath);
    final gutterWidth = showLineNumbers ? _gutterWidthFor(file) : 0;
    if (i > 0) spans.add(const TextSpan(text: '\n'));
    if (file.displayPath != null) {
      spans.add(_headerSpan(file.displayPath!));
    }
    for (var h = 0; h < file.hunks.length; h++) {
      if (h > 0 || file.displayPath != null) {
        spans.add(_hunkAnchorSpan(file.hunks[h], gutterWidth));
      }
      for (final line in file.hunks[h].lines) {
        spans.add(
          _lineSpan(
            line,
            language,
            gutterWidth,
            theme,
            showLineNumbers,
          ),
        );
      }
    }
  }
  return spans;
}

InlineSpan _headerSpan(String path) {
  return TextSpan(
    text: '── $path\n',
    style: const TextStyle(fontWeight: FontWeight.bold),
  );
}

InlineSpan _hunkAnchorSpan(DiffHunk hunk, int gutterWidth) {
  final old = '${hunk.oldStart},${hunk.oldCount}';
  final new_ = '${hunk.newStart},${hunk.newCount}';
  final anchor = '@@ -$old +$new_ @@';
  return TextSpan(
    text: '${' ' * (gutterWidth + 2)}$anchor\n',
    style: const TextStyle(color: gutterColor, fontStyle: FontStyle.italic),
  );
}

InlineSpan _lineSpan(
  DiffLine line,
  String? language,
  int gutterWidth,
  HighlightTheme theme,
  bool showLineNumbers,
) {
  final sign = switch (line.kind) {
    DiffLineKind.addition => '+',
    DiffLineKind.deletion => '-',
    DiffLineKind.context => ' ',
  };
  final signStyle = switch (line.kind) {
    DiffLineKind.addition => const TextStyle(
      color: _additionSign,
      fontWeight: FontWeight.bold,
    ),
    DiffLineKind.deletion => const TextStyle(
      color: _deletionSign,
      fontWeight: FontWeight.bold,
    ),
    DiffLineKind.context => null,
  };

  final lineNumber = switch (line.kind) {
    DiffLineKind.addition => line.newLineNumber,
    DiffLineKind.deletion => line.oldLineNumber,
    DiffLineKind.context => line.newLineNumber,
  };

  final children = <InlineSpan>[
    if (showLineNumbers) gutterSpan(lineNumber, gutterWidth),
    TextSpan(text: sign, style: signStyle),
    const TextSpan(text: ' '),
    highlightSpan(
      code: line.text,
      language: language,
      theme: theme,
      // Skip the 500-language scan per line; the diff already knows what
      // file it's in, so unknown == we genuinely don't have a hint.
      autoDetect: false,
    ),
  ];
  if (line.noNewlineAtEof) {
    children.add(
      const TextSpan(
        text: ' ⏎',
        style: TextStyle(color: gutterColor, fontStyle: FontStyle.italic),
      ),
    );
  }
  children.add(const TextSpan(text: '\n'));

  return TextSpan(children: children);
}

/// Computes the column width needed to right-align every line number in
/// [file] within the gutter.
int _gutterWidthFor(DiffFile file) {
  var maxLine = 0;
  for (final hunk in file.hunks) {
    final oldEnd = hunk.oldStart + hunk.oldCount;
    final newEnd = hunk.newStart + hunk.newCount;
    if (oldEnd > maxLine) maxLine = oldEnd;
    if (newEnd > maxLine) maxLine = newEnd;
  }
  return maxLine.toString().length;
}

const _additionSign = Color.fromRGB(80, 250, 123);
const _deletionSign = Color.fromRGB(255, 85, 85);
