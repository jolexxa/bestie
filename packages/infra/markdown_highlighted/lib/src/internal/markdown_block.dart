import 'package:nocterm/nocterm.dart';

/// One top-level block of a rendered markdown document.
///
/// A document renders as a vertical stack of blocks.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// Flowing text: paragraphs, headings, blockquotes, lists — anything that
/// soft-wraps at the pane width.
class ProseBlock extends MarkdownBlock {
  /// Creates a prose block over [span].
  const ProseBlock(this.span);

  /// The block's styled content.
  final InlineSpan span;
}

/// A fenced code block. [background], when set, becomes a full-width
/// backdrop painted behind the block.
class CodeBlock extends MarkdownBlock {
  /// Creates a code block over [span] with an optional [background] backdrop.
  const CodeBlock(this.span, {this.background});

  /// The highlighted code content.
  final InlineSpan span;

  /// Backdrop color for the block, painted at the box layer.
  final Color? background;
}

/// A horizontal rule.
class RuleBlock extends MarkdownBlock {
  /// Creates a horizontal rule block.
  const RuleBlock();
}

/// A standalone display-math grid, centred within the pane at layout time
/// and clipped at the pane edge when wider than it.
class MathBlock extends MarkdownBlock {
  /// Creates a display math block over [span].
  const MathBlock(this.span);

  /// The rendered math grid.
  final InlineSpan span;
}

/// A table, pre-composed as box-drawing text. Tables that exceed the pane
/// redistribute their columns and are consciously width-dependent.
class TableBlock extends MarkdownBlock {
  /// Creates a table block over [span].
  const TableBlock(this.span);

  /// The composed table text.
  final InlineSpan span;
}
