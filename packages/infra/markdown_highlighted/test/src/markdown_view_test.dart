// Non-const widget instances are used here intentionally so distinct State
// objects aren't deduped against each other across pumps.
// ignore_for_file: prefer_const_constructors
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// A parent that wraps a MarkdownView and forces State rebuilds via
/// setState so we can hit the cache-hit path inside the view's LayoutBuilder.
class _RebuildHarness extends StatefulComponent {
  const _RebuildHarness({required this.data});
  final String data;

  @override
  State<_RebuildHarness> createState() => _RebuildHarnessState();
}

class _RebuildHarnessState extends State<_RebuildHarness> {
  int _tick = 0;
  void bump() => setState(() => _tick++);

  @override
  Component build(BuildContext context) {
    return MarkdownView(component.data);
  }
}

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

/// Joins a block list back into one span the way the blocks read — content
/// separated by blank lines — so flatten-based assertions stay meaningful.
InlineSpan _spanFromBlocks(List<MarkdownBlock> blocks) {
  return TextSpan(
    children: [
      for (final (index, block) in blocks.indexed) ...[
        if (index > 0) const TextSpan(text: '\n\n'),
        switch (block) {
          ProseBlock(:final span) ||
          CodeBlock(:final span) ||
          MathBlock(:final span) ||
          TableBlock(:final span) => span,
          RuleBlock() => const TextSpan(text: ''),
        },
      ],
    ],
  );
}

List<MarkdownBlock> _renderToBlocks(String data, {int? maxWidth}) {
  final nodes = buildMarkdownDocument().parse(data);
  final visitor = MarkdownVisitor(
    theme: MarkdownTheme.terminal(),
    builders: MarkdownBuilders.defaults(),
    maxWidth: maxWidth,
  );
  return visitor.visit(nodes);
}

InlineSpan _renderToSpan(String data, {int? maxWidth}) =>
    _spanFromBlocks(_renderToBlocks(data, maxWidth: maxWidth));

void main() {
  group('MarkdownVisitor', () {
    test('renders paragraphs as-is', () {
      final span = _renderToSpan('hello world');
      expect(_flatten(span), contains('hello world'));
    });

    test('h1 renders uppercase + bold (no leading source marker)', () {
      final span = _renderToSpan('# Hello world');
      final text = _flatten(span);
      expect(text, contains('HELLO WORLD'));
      // No literal source marker or sigil leaks into the rendered output.
      expect(text, isNot(contains('# ')));
    });

    test('h1 uppercase preserves nested styling (bold/italic inside)', () {
      // The recursive uppercase walks past nested element spans (em, strong,
      // code) without flattening them. Only the leaf text changes.
      final span = _renderToSpan('# Hello *emphasized*');
      expect(_flatten(span), contains('HELLO EMPHASIZED'));
    });

    test('h2 renders bold + underline (mixed case, no leading marker)', () {
      final span = _renderToSpan('## Section');
      expect(_flatten(span), contains('Section'));
      expect(_flatten(span), isNot(contains('## ')));
    });

    test('h3 renders bold (mixed case, no leading marker)', () {
      final span = _renderToSpan('### Subsection');
      expect(_flatten(span), contains('Subsection'));
      expect(_flatten(span), isNot(contains('### ')));
    });

    test('h4 renders bold italic', () {
      final span = _renderToSpan('#### Detail');
      expect(_flatten(span), contains('Detail'));
    });

    test('h5 and h6 render with italic styling', () {
      final h5 = _renderToSpan('##### Subdetail');
      expect(_flatten(h5), contains('Subdetail'));
      final h6 = _renderToSpan('###### Leaf');
      expect(_flatten(h6), contains('Leaf'));
    });

    test(
      'headings never emit the literal # prefix from the markdown source',
      () {
        // Lock-in: the previous renderer leaked '# '/'## '/'### ' into the
        // visible output. Those source-markers must never appear in a
        // rendered heading.
        for (var level = 1; level <= 6; level++) {
          final prefix = '#' * level;
          final span = _renderToSpan('$prefix Heading');
          expect(_flatten(span), isNot(contains('# ')));
        }
      },
    );

    test('renders bold and italic', () {
      final bold = _renderToSpan('**bold**');
      expect(_flatten(bold), contains('bold'));
      final italic = _renderToSpan('*italic*');
      expect(_flatten(italic), contains('italic'));
      final strike = _renderToSpan('~~struck~~');
      expect(_flatten(strike), contains('struck'));
    });

    test('renders inline code with the theme style', () {
      final span = _renderToSpan('a `snippet` b');
      expect(_flatten(span), contains('snippet'));
    });

    test('renders a fenced code block through the codeBlock builder', () {
      final span = _renderToSpan('```dart\nvar x = 1;\n```');
      expect(_flatten(span), contains('var x = 1;'));
    });

    test('renders a diff fence through diffSpan', () {
      const md = '''
```diff
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
-a
+b
```
''';
      final span = _renderToSpan(md);
      // Diff path emits a path header — highlightSpan path wouldn't.
      expect(_flatten(span), contains('── x'));
    });

    test('renders a blockquote with the gutter character', () {
      final span = _renderToSpan('> quoted');
      expect(_flatten(span), contains('│'));
      expect(_flatten(span), contains('quoted'));
    });

    test('renders a link with its url annotation', () {
      final span = _renderToSpan('[click](https://example.com)');
      final text = _flatten(span);
      expect(text, contains('click'));
      expect(text, contains('[https://example.com]'));
    });

    test('renders an image alt placeholder', () {
      final span = _renderToSpan('![diagram](foo.png)');
      expect(_flatten(span), contains('[Image: diagram]'));
    });

    test('renders unordered lists with bullets', () {
      final span = _renderToSpan('- one\n- two');
      final text = _flatten(span);
      expect(text, contains('one'));
      expect(text, contains('two'));
      expect(text, contains('•'));
    });

    test('renders nested lists with deeper indentation', () {
      final span = _renderToSpan('- outer\n  - inner');
      final text = _flatten(span);
      expect(text, contains('outer'));
      expect(text, contains('inner'));
    });

    test('renders ordered lists', () {
      final span = _renderToSpan('1. a\n2. b');
      expect(_flatten(span), contains('a'));
    });

    test('renders horizontal rules as textless rule blocks', () {
      // The rule spans the pane at paint time; its selectable text carries
      // no width so a resize can't shift selection indexes.
      final blocks = _renderToBlocks('---', maxWidth: 20);
      expect(blocks, hasLength(1));
      expect(blocks.single, isA<RuleBlock>());
    });

    test('renders nested horizontal rules with a fixed short run', () {
      final span = _renderToSpan('> above\n> \n> ---');
      expect(_flatten(span), contains('─' * 3));
      expect(_flatten(span), isNot(contains('─' * 4)));
    });

    test('renders hard line breaks', () {
      // Two trailing spaces in GFM = <br>.
      final span = _renderToSpan('one  \ntwo');
      expect(_flatten(span), contains('one'));
      expect(_flatten(span), contains('two'));
    });

    test('renders tables with ASCII borders', () {
      final span = _renderToSpan(
        '| a | b |\n|---|---|\n| 1 | 2 |',
        maxWidth: 80,
      );
      final text = _flatten(span);
      expect(text, contains('a'));
      expect(text, contains('1'));
      expect(text, contains('┌'));
      expect(text, contains('└'));
    });

    test('renders a table nested in a blockquote through the span path', () {
      final span = _renderToSpan('> | a | b |\n> |---|---|\n> | 1 | 2 |');
      final text = _flatten(span);
      expect(text, contains('┌'));
      expect(text, contains('1'));
    });

    test('renders bare-fenced code as plaintext through highlightSpan', () {
      final span = _renderToSpan('```\nplain text\n```');
      expect(_flatten(span), contains('plain text'));
    });

    test(
      'falls back to default code-block style when codeBlock hook is null',
      () {
        final nodes = buildMarkdownDocument().parse('```\nhello\n```');
        final visitor = MarkdownVisitor(
          theme: MarkdownTheme.terminal(),
          builders: const MarkdownBuilders(),
        );
        final span = _spanFromBlocks(visitor.visit(nodes));
        expect(_flatten(span), contains('hello'));
      },
    );

    test('routes inline code through inlineCode builder when provided', () {
      final nodes = buildMarkdownDocument().parse('a `code` b');
      final visitor = MarkdownVisitor(
        theme: MarkdownTheme.terminal(),
        builders: MarkdownBuilders(
          inlineCode: (code) => TextSpan(text: 'INLINE<$code>'),
        ),
      );
      final span = _spanFromBlocks(visitor.visit(nodes));
      expect(_flatten(span), contains('INLINE<code>'));
    });

    test('handles unknown element tags by visiting children', () {
      // Synthesize an md.Element with a tag the visitor doesn't switch on —
      // hits the `default` arm.
      final visitor = MarkdownVisitor(
        theme: MarkdownTheme.terminal(),
        builders: MarkdownBuilders.defaults(),
      );
      final element = md.Element('unknown-tag', [md.Text('payload')]);
      final span = visitor.visitElement(element);
      expect(_flatten(span!), contains('payload'));
    });

    test('renders a <pre> without a <code> child via textContent fallback', () {
      final visitor = MarkdownVisitor(
        theme: MarkdownTheme.terminal(),
        builders: MarkdownBuilders.defaults(),
      );
      // A <pre> whose first child is a Text node, not an Element.
      final element = md.Element('pre', [md.Text('bare code')]);
      final span = visitor.visitElement(element);
      expect(_flatten(span!), contains('bare code'));
    });

    test('handles empty input', () {
      final span = _renderToSpan('');
      expect(_flatten(span), '');
    });

    test('code blocks carry the backdrop color, never text padding', () {
      const bg = Color.fromRGB(30, 31, 41);
      final nodes = buildMarkdownDocument().parse('```\nfoo\n```');
      final visitor = MarkdownVisitor(
        theme: MarkdownTheme.terminal(),
        builders: MarkdownBuilders.defaults(
          theme: HighlightTheme(styles: const {}, background: bg),
        ),
        maxWidth: 10,
        codeBlockBackground: bg,
      );
      final block = visitor.visit(nodes).single as CodeBlock;
      // The backdrop is painted at the box layer; the selectable text is
      // exactly the code.
      expect(block.background, bg);
      expect(_flatten(block.span), 'foo');
    });
  });

  group('MarkdownVisitor.uppercase', () {
    test('uppercases the text of a leaf TextSpan', () {
      const input = TextSpan(text: 'hello');
      final upper = MarkdownVisitor.uppercase(input);
      expect(upper.text, 'HELLO');
    });

    test('recursively uppercases nested children, preserving their styles', () {
      const input = TextSpan(
        style: TextStyle(fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: 'a '),
          TextSpan(
            style: TextStyle(fontStyle: FontStyle.italic),
            children: [TextSpan(text: 'b')],
          ),
        ],
      );
      final upper = MarkdownVisitor.uppercase(input);
      // Top-level style preserved.
      expect(upper.style?.fontWeight, FontWeight.bold);
      // Leaf text uppercased.
      final flat = StringBuffer();
      upper.computeToPlainText(flat);
      expect(flat.toString(), 'A B');
      // Nested italic style preserved.
      final nested = upper.children![1] as TextSpan;
      expect(nested.style?.fontStyle, FontStyle.italic);
    });

    test('handles a TextSpan with neither text nor children', () {
      const input = TextSpan();
      final upper = MarkdownVisitor.uppercase(input);
      expect(upper.text, isNull);
      expect(upper.children, isNull);
    });
  });

  group('MarkdownVisitor.trimTrailingNewlines', () {
    test('drops a pure-newline last child', () {
      final input = TextSpan(
        children: const [
          TextSpan(text: 'body'),
          TextSpan(text: '\n\n'),
        ],
      );
      final out = MarkdownVisitor.trimTrailingNewlines(input);
      expect((out as TextSpan).children, hasLength(1));
    });

    test('recurses into a non-newline last child to trim its tail', () {
      // outer.children = [Text('hi'), inner]
      // inner.children = [Text('x'), Text('\n\n')]
      // First pass: outer's last child is `inner`, not a pure-newline span.
      // Recursion trims inner's tail; result swaps the replaced child in.
      final inner = TextSpan(
        children: const [
          TextSpan(text: 'x'),
          TextSpan(text: '\n\n'),
        ],
      );
      final outer = TextSpan(
        children: [
          const TextSpan(text: 'hi'),
          inner,
        ],
      );
      final trimmed = MarkdownVisitor.trimTrailingNewlines(outer) as TextSpan;
      final trimmedInner = trimmed.children!.last as TextSpan;
      expect(trimmedInner.children, hasLength(1));
    });

    test('trims a trailing newline on a leaf text span', () {
      const input = TextSpan(text: 'hello\n');
      final out = MarkdownVisitor.trimTrailingNewlines(input) as TextSpan;
      expect(out.text, 'hello');
    });

    test('returns non-TextSpan inputs unchanged', () {
      // Use a TextSpan as itself — any InlineSpan that's not specifically a
      // pure TextSpan returns from the early `if (span is! TextSpan)`. Since
      // TextSpan is the only InlineSpan in nocterm, exercise the no-op leaf
      // path: a TextSpan with no children and no trailing newline.
      const input = TextSpan(text: 'unchanged');
      final out = MarkdownVisitor.trimTrailingNewlines(input);
      expect(identical(out, input), isTrue);
    });
  });

  group('MarkdownView widget', () {
    test('renders to the terminal', () async {
      await testNocterm('MarkdownView smoke', (tester) async {
        await tester.pumpComponent(
          const MarkdownView('# Title\n\nA paragraph.'),
        );
        // h1 uppercases, so the rendered title is 'TITLE' not 'Title'.
        expect(tester.terminalState, containsText('TITLE'));
        expect(tester.terminalState, containsText('A paragraph.'));
      });
    });

    test('rebuilds on data change', () async {
      await testNocterm('MarkdownView rebuild', (tester) async {
        await tester.pumpComponent(const MarkdownView('first'));
        expect(tester.terminalState, containsText('first'));
        await tester.pumpComponent(const MarkdownView('second'));
        expect(tester.terminalState, containsText('second'));
      });
    });

    test('accepts a custom theme', () async {
      await testNocterm('MarkdownView custom theme', (tester) async {
        const custom = MarkdownTheme(listBullet: '> ');
        await tester.pumpComponent(
          const MarkdownView(
            '- item',
            theme: custom,
          ),
        );
        expect(tester.terminalState, containsText('item'));
      });
    });

    test('reuses cached spans when nothing changes between builds', () async {
      // Force a rebuild via setState on a harness — preserves the
      // MarkdownView's State so its `_last*` fields are populated. The cache
      // check then evaluates all five comparisons as false, exercising lines
      // 85-88 of the `||` chain.
      await testNocterm('MarkdownView cache hit', (tester) async {
        await tester.pumpComponent(_RebuildHarness(data: 'cached'));
        tester.findState<_RebuildHarnessState>().bump();
        await tester.pump();
        expect(tester.terminalState, containsText('cached'));
      });
    });

    test('rebuilds when theme changes (covers theme cache key)', () async {
      await testNocterm('MarkdownView theme miss', (tester) async {
        await tester.pumpComponent(MarkdownView('- a'));
        await tester.pumpComponent(
          MarkdownView(
            '- a',
            theme: MarkdownTheme(listBullet: '> '),
          ),
        );
        expect(tester.terminalState, containsText('a'));
      });
    });

    test('rebuilds when builders change (covers builders cache key)', () async {
      await testNocterm('MarkdownView builders miss', (tester) async {
        await tester.pumpComponent(MarkdownView('```\nx\n```'));
        await tester.pumpComponent(
          MarkdownView(
            '```\nx\n```',
            builders: MarkdownBuilders.defaults(),
          ),
        );
        expect(tester.terminalState, containsText('x'));
      });
    });

    test('rebuilds when highlightTheme changes '
        '(covers highlightTheme cache key)', () async {
      final customTheme = HighlightTheme(styles: const {});
      await testNocterm('MarkdownView highlight miss', (tester) async {
        await tester.pumpComponent(MarkdownView('```dart\nx\n```'));
        await tester.pumpComponent(
          MarkdownView(
            '```dart\nx\n```',
            highlightTheme: customTheme,
          ),
        );
        expect(tester.terminalState, containsText('x'));
      });
    });

    test('re-reads half-written math once streaming clears '
        '(covers streaming cache key)', () async {
      await testNocterm('MarkdownView streaming miss', (tester) async {
        await tester.pumpComponent(
          MarkdownView(r'value \(x^2', streaming: true),
        );
        expect(tester.terminalState, containsText('…'));

        await tester.pumpComponent(MarkdownView(r'value \(x^2'));
        expect(tester.terminalState, containsText(r'\(x^2'));
      });
    });
  });
}
