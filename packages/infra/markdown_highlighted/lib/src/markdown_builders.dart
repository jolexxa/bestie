import 'package:markdown_highlighted/src/diff_view.dart';
import 'package:markdown_highlighted/src/syntax_highlight.dart';
import 'package:markdown_highlighted/src/theme/highlight_theme.dart';
import 'package:nocterm/nocterm.dart';

/// Builds an [InlineSpan] for a fenced code block. [language] is the language
/// hint from the opening fence (` ```dart `, ` ```rust `, etc.), or `null` for
/// a bare ` ``` ` fence.
typedef CodeBlockBuilder = InlineSpan Function(String code, String? language);

/// Builds an [InlineSpan] for an inline `` `code` `` span.
typedef InlineCodeBuilder = InlineSpan Function(String code);

/// Per-element renderer hooks for `MarkdownView`. Hooks override the default
/// rendering for their respective element types. Pass an instance to
/// `MarkdownView` to plug in custom block/inline rendering — e.g. routing a
/// `diff` code fence to [DiffView]-style output, or rendering a tool-call
/// block as a card.
///
/// Use [MarkdownBuilders.defaults] for the standard hooks (syntax-highlighted
/// code blocks, plain inline code).
class MarkdownBuilders {
  /// Creates a builder set. Any null hook falls back to the visitor's
  /// built-in plain rendering.
  const MarkdownBuilders({this.codeBlock, this.inlineCode});

  /// Default hook set:
  ///
  /// - `codeBlock`: routes `lang == 'diff'` to [diffSpan] (gutter + signs +
  ///   per-line highlight), everything else to [highlightSpan] using [theme].
  ///   Unknown languages fall through to plaintext (no error).
  /// - `inlineCode`: only registered when [theme] declares a `background`. In
  ///   that case the inline span gets the same backdrop as block code (plus
  ///   bold) so inline `code` reads consistently with fenced blocks. When the
  ///   theme has no backdrop, this is left null and the visitor uses the
  ///   markdown theme's `inlineCodeStyle`.
  factory MarkdownBuilders.defaults({
    HighlightTheme theme = HighlightTheme.dracula,
  }) {
    return MarkdownBuilders(
      codeBlock: (code, language) {
        if ((language ?? '').toLowerCase() == 'diff') {
          return diffSpan(code, theme: theme);
        }
        return highlightSpan(code: code, language: language, theme: theme);
      },
      inlineCode: theme.background == null
          ? null
          : (code) => TextSpan(
              text: code,
              // Pin color to the theme's fallback so inline code doesn't
              // inherit the surrounding paragraph color (which would clash
              // with the backdrop).
              style: TextStyle(
                color: theme.fallback?.color,
                backgroundColor: theme.background,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  /// Renders a fenced code block. When `null`, blocks render as plain
  /// (un-highlighted) text using the surrounding markdown theme's
  /// `codeBlockStyle`.
  final CodeBlockBuilder? codeBlock;

  /// Renders an inline code span. When `null`, spans render as plain text
  /// using the markdown theme's `inlineCodeStyle`.
  final InlineCodeBuilder? inlineCode;
}
