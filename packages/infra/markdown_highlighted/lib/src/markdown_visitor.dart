import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/math_renderer.dart';
import 'package:markdown_highlighted/src/internal/math_syntax.dart';
import 'package:markdown_highlighted/src/internal/table_renderer.dart';
import 'package:markdown_highlighted/src/markdown_builders.dart';
import 'package:markdown_highlighted/src/theme/markdown_theme.dart';
import 'package:markdown_highlighted/src/theme/math_theme.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// Walks a `package:markdown` AST and emits a tree of [InlineSpan]s suitable
/// for [RichText]. Code blocks and inline code are routed through
/// [MarkdownBuilders] hooks when provided; everything else uses styles from
/// the supplied [MarkdownTheme].
///
/// Mirrors the shape of nocterm's internal markdown visitor but with two
/// added seams: a code-block builder that receives the fence's language hint,
/// and an inline-code builder.
class MarkdownVisitor {
  /// Creates a visitor bound to a theme + builder set.
  MarkdownVisitor({
    required this.theme,
    required this.builders,
    this.mathTheme = MathTheme.none,
    this.maxWidth,
    this.codeBlockBackground,
    this.streaming = false,
  });

  /// Styles for non-code elements.
  final MarkdownTheme theme;

  /// Hooks for code blocks and inline code spans.
  final MarkdownBuilders builders;

  /// Styling for rendered display math.
  final MathTheme mathTheme;

  /// Optional terminal column budget. Used only to shrink tables that would
  /// otherwise overflow the pane — never to pad or clip selectable text.
  final int? maxWidth;

  /// Backdrop color carried onto each [CodeBlock] so the view can paint a
  /// full-width background behind the block at the box layer.
  final Color? codeBlockBackground;

  /// Whether more text is still arriving.
  final bool streaming;

  int _listDepth = 0;

  /// Walks [nodes] and returns the document as a list of top-level blocks.
  List<MarkdownBlock> visit(List<md.Node> nodes) {
    final blocks = <MarkdownBlock>[];
    for (final node in nodes) {
      final block = _blockFor(node);
      if (block != null) blocks.add(block);
    }
    return blocks;
  }

  MarkdownBlock? _blockFor(md.Node node) {
    if (node is md.Element) {
      switch (node.tag) {
        case 'pre':
          return CodeBlock(
            _trimBlockTail(_codeContent(node)),
            background: codeBlockBackground,
          );
        case 'hr':
          return const RuleBlock();
        case 'mathBlock':
          return MathBlock(
            _isPending(node)
                ? MathRenderer.pending(node)
                : MathRenderer.render(node, display: true, theme: mathTheme),
          );
        case 'table':
          return TableBlock(
            _trimBlockTail(TableRenderer.render(node, maxWidth: maxWidth)),
          );
      }
    }
    final span = _visitNode(node);
    if (span == null) return null;
    return ProseBlock(_trimBlockTail(span));
  }

  /// Applies [trimTrailingNewlines] to a fixpoint: block tails shed every
  /// trailing separator (a paragraph's `'\n\n'`, a quote's `'\n'` atop its
  /// last paragraph's `'\n\n'`), however deeply nested.
  static InlineSpan _trimBlockTail(InlineSpan span) {
    var current = span;
    while (true) {
      final trimmed = _trimTrailingNewlines(current);
      if (identical(trimmed, current)) return current;
      current = trimmed;
    }
  }

  InlineSpan? _visitNode(md.Node node) {
    if (node is md.Element) return visitElement(node);
    if (node is md.Text) return TextSpan(text: node.text);
    return null;
  }

  /// Visits a single element. Exposed for unit testing edge cases
  /// (default-case tag handling, `<pre>` without a `<code>` child).
  @visibleForTesting
  InlineSpan? visitElement(md.Element element) {
    switch (element.tag) {
      case 'h1':
        // h1 is the loudest heading — uppercased + bold. We post-process the
        // assembled span tree so nested styling (bold, italic, links inside
        // the heading) survives the transformation.
        return _uppercase(
          _heading('', element, theme.h1Style) as TextSpan,
        );
      case 'h2':
        return _heading('', element, theme.h2Style);
      case 'h3':
        return _heading('', element, theme.h3Style);
      case 'h4':
        return _heading('', element, theme.h4Style);
      case 'h5':
        return _heading('', element, theme.h5Style);
      case 'h6':
        return _heading('', element, theme.h6Style);
      case 'p':
        return TextSpan(
          style: theme.paragraphStyle,
          children: [
            ..._visitChildren(element),
            const TextSpan(text: '\n\n'),
          ],
        );
      case 'strong':
      case 'b':
        return TextSpan(
          style: theme.boldStyle,
          children: _visitChildren(element),
        );
      case 'em':
      case 'i':
        return TextSpan(
          style: theme.italicStyle,
          children: _visitChildren(element),
        );
      case 'del':
      case 's':
        return TextSpan(
          style: theme.strikethroughStyle,
          children: _visitChildren(element),
        );
      case 'code':
        // Inline code (not inside a <pre>). Builder hook wins; fall back to
        // theme.inlineCodeStyle.
        final code = element.textContent;
        final builder = builders.inlineCode;
        if (builder != null) return builder(code);
        return TextSpan(text: code, style: theme.inlineCodeStyle);
      case 'pre':
        return _codeBlock(element);
      case 'blockquote':
        return TextSpan(
          style: theme.blockquoteStyle,
          children: [
            TextSpan(text: '│ ', style: theme.blockquoteStyle),
            ..._visitChildren(element),
            const TextSpan(text: '\n'),
          ],
        );
      case 'a':
        final href = element.attributes['href'] ?? '';
        final text = element.textContent;
        return TextSpan(
          children: [
            TextSpan(text: text, style: theme.linkStyle),
            TextSpan(
              text: ' [$href]',
              style: theme.linkStyle?.copyWith(
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        );
      case 'img':
        final alt = element.attributes['alt'] ?? 'image';
        return TextSpan(
          text: '[Image: $alt]',
          style: const TextStyle(fontStyle: FontStyle.italic),
        );
      case 'ul':
      case 'ol':
        _listDepth++;
        final children = _visitChildren(element);
        _listDepth--;
        return TextSpan(
          children: [
            ...children,
            if (_listDepth == 0) const TextSpan(text: '\n'),
          ],
        );
      case 'li':
        return _listItem(element);
      case 'hr':
        // Only reachable nested (inside a blockquote, say) — a top-level hr
        // becomes a RuleBlock painted across the pane. A short fixed run
        // keeps nested rules width-independent.
        return TextSpan(
          text: '${theme.horizontalRule * 3}\n\n',
          style: const TextStyle(color: Colors.grey),
        );
      case 'br':
        return const TextSpan(text: '\n');
      case 'table':
        return TableRenderer.render(element, maxWidth: maxWidth);
      case 'math':
        return MathRenderer.render(element, display: false, theme: mathTheme);
      case 'mathDisplay':
        return TextSpan(
          children: [
            const TextSpan(text: '\n'),
            MathRenderer.render(element, display: true, theme: mathTheme),
            const TextSpan(text: '\n'),
          ],
        );
      case 'mathBlock':
        // A standalone display block. Same 2D grid as inline display math, but
        // as its own block it needs trailing separation so the following
        // paragraph doesn't butt against it.
        return TextSpan(
          children: [
            if (_isPending(element))
              MathRenderer.pending(element)
            else
              MathRenderer.render(element, display: true, theme: mathTheme),
            const TextSpan(text: '\n\n'),
          ],
        );
      case 'mathPending':
        // An opener the closer never followed.
        return streaming
            ? MathRenderer.pending(element)
            : TextSpan(text: element.textContent);
      default:
        return TextSpan(children: _visitChildren(element));
    }
  }

  bool _isPending(md.Element element) =>
      streaming && element.attributes[unterminatedMath] == 'true';

  /// Recursively converts every text leaf inside [span] to uppercase.
  /// Preserves nested styling (bold, italic, links) — only the leaf strings
  /// change. Used for h1.
  @visibleForTesting
  static TextSpan uppercase(TextSpan span) => _uppercase(span);

  static TextSpan _uppercase(TextSpan span) {
    if (span is MathSpan) return span;
    return TextSpan(
      style: span.style,
      text: span.text?.toUpperCase(),
      children: span.children?.cast<TextSpan>().map(_uppercase).toList(),
    );
  }

  InlineSpan _heading(String prefix, md.Element element, TextStyle? style) {
    return TextSpan(
      style: style,
      children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix, style: style),
        ..._visitChildren(element),
        const TextSpan(text: '\n\n'),
      ],
    );
  }

  InlineSpan _codeBlock(md.Element pre) => TextSpan(
    children: [
      _codeContent(pre),
      const TextSpan(text: '\n\n'),
    ],
  );

  /// The highlighted content of a fenced code block, unpadded.
  InlineSpan _codeContent(md.Element pre) {
    // GFM lowers a fenced code block to `<pre><code class="language-X">...`.
    // Extract the language attribute, then call the builder hook with the
    // raw code body.
    String? language;
    String code;
    final children = pre.children;
    if (children != null &&
        children.isNotEmpty &&
        children.first is md.Element) {
      final codeElement = children.first as md.Element;
      final classes = codeElement.attributes['class'];
      if (classes != null) {
        for (final cls in classes.split(' ')) {
          if (cls.startsWith('language-')) {
            language = cls.substring('language-'.length);
            break;
          }
        }
      }
      code = codeElement.textContent;
    } else {
      code = pre.textContent;
    }

    final builder = builders.codeBlock;
    return builder != null
        ? builder(code, language)
        : TextSpan(text: code, style: theme.codeBlockStyle);
  }

  InlineSpan _listItem(md.Element element) {
    final indent = '  ' * _listDepth;
    final bullet = theme.listBullet;
    final children = <InlineSpan>[TextSpan(text: indent + bullet)];

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element &&
            (child.tag == 'ul' ||
                child.tag == 'ol' ||
                child.tag == 'mathBlock')) {
          // Block children can't share the bullet's line. A nested list or a
          // display-math block that follows the item's inline text needs a
          // break before it, or its first row welds onto the bullet prose.
          if (children.length > 1) {
            children.add(const TextSpan(text: '\n'));
          }
        }
        final span = _visitNode(child);
        if (span != null) children.add(span);
      }
    }

    children.add(const TextSpan(text: '\n'));
    return TextSpan(children: children);
  }

  List<InlineSpan> _visitChildren(md.Element element) {
    final spans = <InlineSpan>[];
    if (element.children == null) return spans;
    for (final child in element.children!) {
      final span = _visitNode(child);
      if (span != null) spans.add(span);
    }
    return spans;
  }

  /// Recursively drops trailing newline-only spans from a span tree so the
  /// last block element doesn't tail off into blank lines. Exposed for unit
  /// testing the recursive case.
  @visibleForTesting
  static InlineSpan trimTrailingNewlines(InlineSpan span) =>
      _trimTrailingNewlines(span);

  static InlineSpan _trimTrailingNewlines(InlineSpan span) {
    if (span is! TextSpan) return span;

    final children = span.children;
    if (children != null && children.isNotEmpty) {
      final last = children.last;
      if (last is TextSpan &&
          last.text != null &&
          RegExp(r'^\n+$').hasMatch(last.text!)) {
        final trimmed = children.sublist(0, children.length - 1);
        return TextSpan(children: trimmed, style: span.style);
      }
      final trimmedLast = _trimTrailingNewlines(last);
      if (trimmedLast != last) {
        final updated = [...children];
        updated[updated.length - 1] = trimmedLast;
        return TextSpan(children: updated, style: span.style);
      }
    } else if (span.text != null && span.text!.endsWith('\n')) {
      return TextSpan(text: span.text!.trimRight(), style: span.style);
    }

    return span;
  }
}
