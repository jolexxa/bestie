import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/theme/math_theme.dart';
import 'package:math_render/math_render.dart';
import 'package:nocterm/nocterm.dart';

/// A span holding rendered (or raw-fallback) math. Distinct from a plain
/// [TextSpan] so text transforms that walk the span tree — heading
/// uppercasing, say — can structurally skip math: its glyphs are already laid
/// out, and its source is case-sensitive (`n` and `N`, `\Pi` and `\pi` are
/// different symbols), so rewriting its characters corrupts it.
///
/// Renders exactly like the [TextSpan] it extends; [tex] retains the source for
/// debugging and round-trips.
class MathSpan extends TextSpan {
  /// Wraps already-laid-out math as one styled run per [MathRun], rows joined
  /// by newlines.
  const MathSpan({required List<InlineSpan> super.children, required this.tex});

  /// A single unstyled run — a parse-failure fallback, a pending placeholder,
  /// or inline math, none of which carry per-cell styling.
  const MathSpan.plain(String rendered, this.tex) : super(text: rendered);

  /// The raw TeX source this span was rendered from.
  final String tex;
}

/// Renders a `math` / `mathDisplay` element (raw TeX in its text content) into
/// a [MathSpan] via `math_render`. Kept as pure static helpers alongside
/// `TableRenderer` so the visitor stays focused on AST traversal.
///
/// Inline math is linearized to a single unicode row so it flows within prose;
/// display math is laid out as a 2D grid, emitted at its natural width —
/// centring and pane-edge clipping are layout concerns of the block component
/// that hosts it, never baked into the text. Either path falls back to the
/// raw TeX on a parse failure so malformed math still shows something legible.
///
/// Display math is additionally tagged by term and painted from [MathTheme];
/// with [MathTheme.none] no tagging runs at all and the output is exactly what
/// an uncolorized render produces.
class MathRenderer {
  /// Stands in for a math run whose closing delimiter has not arrived.
  static const String pendingGlyph = '…';

  /// Renders [element]'s TeX. [display] selects the display grid versus the
  /// inline single-row linearization.
  static InlineSpan render(
    md.Element element, {
    required bool display,
    required MathTheme theme,
  }) {
    final tex = element.textContent;
    return display ? _display(tex, theme) : _inline(tex);
  }

  /// A placeholder for [element]'s half-written math, retaining its source so
  /// the run can still be read back.
  static InlineSpan pending(md.Element element) =>
      MathSpan.plain(pendingGlyph, element.textContent);

  static InlineSpan _inline(String tex) {
    final result = renderMathInline(tex);
    return switch (result) {
      MathInlineRendered(:final line) => MathSpan.plain(line, tex),
      MathInlineParseFailed() => MathSpan.plain(tex, tex),
    };
  }

  static InlineSpan _display(String tex, MathTheme theme) {
    final result = renderMath(
      tex,
      displayMode: true,
      // Skip the walk entirely when nothing would be painted with its result.
      tagger: theme.isPlain ? tagNothing : theme.tagger,
    );
    return switch (result) {
      MathRendered(:final grid) => MathSpan(
        children: _runs(grid, theme),
        tex: tex,
      ),
      MathParseFailed() => MathSpan.plain(tex, tex),
    };
  }

  /// One span per coalesced run, rows rejoined with newlines.
  static List<InlineSpan> _runs(MathGrid grid, MathTheme theme) {
    final rows = grid.rowRuns();
    final spans = <InlineSpan>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      for (final run in rows[i]) {
        spans.add(TextSpan(text: run.text, style: theme.styleFor(run.slot)));
      }
    }
    return spans;
  }
}
