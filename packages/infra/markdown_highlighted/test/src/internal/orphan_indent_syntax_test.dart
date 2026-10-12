import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/internal/math_syntax.dart';
import 'package:markdown_highlighted/src/internal/orphan_indent_syntax.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:test/test.dart';

import '../fixtures/reasoning_outline.dart';

List<md.Node> _parse(String source) => buildMarkdownDocument().parse(source);

List<MarkdownBlock> _render(String source) => MarkdownVisitor(
  theme: MarkdownTheme.terminal(),
  builders: MarkdownBuilders.defaults(),
).visit(_parse(source));

/// Every element in [nodes] with [tag], at any depth.
List<md.Element> _elementsTagged(List<md.Node> nodes, String tag) => [
  for (final node in nodes)
    if (node is md.Element) ...[
      if (node.tag == tag) node,
      ..._elementsTagged(node.children ?? const [], tag),
    ],
];

List<String> _topTags(List<md.Node> nodes) => [
  for (final node in nodes)
    if (node is md.Element) node.tag else node.runtimeType.toString(),
];

void main() {
  group('OrphanIndentSyntax', () {
    test('parses an orphaned indented outline as nested bullet lists', () {
      final nodes = _parse(reasoningOutlineFixture);

      expect(_elementsTagged(nodes, 'pre'), isEmpty);
      expect(_topTags(nodes), ['p', 'div', 'p']);
      final outline = nodes[1] as md.Element;
      expect(_topTags(outline.children!).first, 'ul');
      final nested = _elementsTagged(outline.children!, 'ul');
      expect(nested.length, greaterThan(1));
      expect(
        nested.first.textContent,
        contains('Since no genre was specified, I have freedom.'),
      );
    });

    test('renders the outline as prose blocks and never as code', () {
      final blocks = _render(reasoningOutlineFixture);

      expect(blocks.whereType<CodeBlock>(), isEmpty);
      expect(blocks.length, greaterThan(3));
      expect(blocks.first, isA<ProseBlock>());
    });

    test('dedents by the indent so deeper lines nest', () {
      final nodes = _parse('    - outer\n        - inner');

      final lists = _elementsTagged(nodes, 'ul');
      expect(lists.length, 2);
      expect(lists.last.textContent, 'inner');
    });

    test('keeps blank lines inside the run', () {
      final nodes = _parse('    one\n\n    two');

      expect(_topTags(nodes), ['div']);
      final div = nodes.single as md.Element;
      expect(_topTags(div.children!), ['p', 'p']);
    });

    test('ends the run before text that is not indented', () {
      final nodes = _parse('    one\n\n\ntwo');

      expect(_topTags(nodes), ['div', 'p']);
      expect((nodes.last as md.Element).textContent, 'two');
    });

    test('ends the run at the end of the input after blank lines', () {
      final nodes = _parse('    one\n\n');

      expect(_topTags(nodes), ['div']);
    });

    test('treats a tab as the indent', () {
      final nodes = _parse('\t# Heading');

      expect(_elementsTagged(nodes, 'h1').single.textContent, 'Heading');
    });

    test('does not interrupt a paragraph', () {
      final nodes = _parse('first line\n    continued');

      expect(_topTags(nodes), ['p']);
      expect(
        (nodes.single as md.Element).textContent,
        'first line\n    continued',
      );
    });

    test('leaves fenced code as a code block', () {
      final blocks = _render('```dart\nvar x = 1;\n```');

      expect(blocks.single, isA<CodeBlock>());
    });

    test('leaves a list with indented children alone', () {
      final nodes = _parse('- a\n    - b');

      expect(_topTags(nodes), ['ul']);
      expect(_elementsTagged(nodes, 'div'), isEmpty);
    });

    test('renders an over-indented run inside a list item as prose', () {
      final blocks = _render('- a\n\n      note');

      expect(blocks.single, isA<ProseBlock>());
      expect(_elementsTagged(_parse('- a\n\n      note'), 'pre'), isEmpty);
    });

    test('leaves display math alone', () {
      final nodes = _parse(
        r'$$'
        '\nx = y\n'
        r'$$',
      );

      expect(_topTags(nodes), ['mathBlock']);
    });
  });

  group('markdownBlockSyntaxes', () {
    test('tries math, then GitHub extensions, then CommonMark', () {
      final types = markdownBlockSyntaxes.map((syntax) => syntax.runtimeType);
      final mathCount = mathBlockSyntaxes.length;
      final gitHub = md.ExtensionSet.gitHubFlavored.blockSyntaxes;

      expect(
        types.take(mathCount),
        mathBlockSyntaxes.map((syntax) => syntax.runtimeType),
      );
      expect(
        types.skip(mathCount).take(gitHub.length),
        gitHub.map((syntax) => syntax.runtimeType),
      );
      expect(types.skip(mathCount + gitHub.length), [
        md.EmptyBlockSyntax,
        md.HtmlBlockSyntax,
        md.SetextHeaderSyntax,
        md.HeaderSyntax,
        OrphanIndentSyntax,
        md.BlockquoteSyntax,
        md.HorizontalRuleSyntax,
        md.UnorderedListSyntax,
        md.OrderedListSyntax,
        md.LinkReferenceDefinitionSyntax,
        md.ParagraphSyntax,
      ]);
    });

    test('is the whole grammar of the shared document', () {
      final document = buildMarkdownDocument();

      expect(document.withDefaultBlockSyntaxes, isFalse);
      expect(
        document.blockSyntaxes.map((syntax) => syntax.runtimeType),
        markdownBlockSyntaxes.map((syntax) => syntax.runtimeType),
      );
      expect(
        document.blockSyntaxes,
        isNot(contains(isA<md.CodeBlockSyntax>())),
      );
    });
  });

  group('MarkdownVisitor.blocksFor', () {
    test('flattens a div into one block per child', () {
      final blocks = _render(
        '    para\n\n    ---\n\n    ```\n    code\n    ```',
      );

      expect(blocks, [isA<ProseBlock>(), isA<RuleBlock>(), isA<CodeBlock>()]);
    });

    test('renders a div nested in a list item through its children', () {
      final blocks = _render('- a\n\n      note');
      final buffer = StringBuffer();
      (blocks.single as ProseBlock).span.computeToPlainText(buffer);

      expect(buffer.toString(), contains('note'));
    });
  });
}
