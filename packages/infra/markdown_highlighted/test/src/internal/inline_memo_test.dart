import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/inline_memo.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:test/test.dart';

/// A paragraph holding one unparsed leaf, as the block parser leaves it.
md.Element _paragraph(String text) =>
    md.Element('p', [md.UnparsedContent(text)]);

void main() {
  group('InlineMemo', () {
    late InlineMemo memo;
    late md.Document document;

    setUp(() {
      memo = InlineMemo();
      document = buildMarkdownDocument();
    });

    test('parses leaves like the document does', () {
      final nodes = <md.Node>[
        _paragraph('plain **bold** `code`'),
        md.Element('ul', [
          md.Element('li', [md.UnparsedContent('item *one*')]),
        ]),
      ];

      memo.parseInlineContent(nodes, document);

      final expected = buildMarkdownDocument().parse(
        'plain **bold** `code`\n\n- item *one*',
      );
      expect(
        nodes.map((node) => node.textContent),
        expected.map((node) => node.textContent),
      );
      expect(
        (nodes[0] as md.Element).children!.map((node) => node.runtimeType),
        (expected[0] as md.Element).children!.map((node) => node.runtimeType),
      );
    });

    test('reuses the previous parse of the same text once advanced', () {
      final first = _paragraph('same **text**');
      memo
        ..parseInlineContent([first], document)
        ..advance();
      final second = _paragraph('same **text**');

      memo.parseInlineContent([second], document);

      expect(second.children!.first, same(first.children!.first));
    });

    test('reuses a parse within the same pass', () {
      final first = _paragraph('twice');
      final second = _paragraph('twice');

      memo.parseInlineContent([first, second], document);

      expect(second.children!.single, same(first.children!.single));
    });

    test('drops what the last pass did not use', () {
      final first = _paragraph('old');
      memo
        ..parseInlineContent([first], document)
        ..advance()
        ..parseInlineContent([_paragraph('other')], document)
        ..advance();
      final again = _paragraph('old');

      memo.parseInlineContent([again], document);

      expect(again.children!.single, isNot(same(first.children!.single)));
    });

    test('forgets everything when cleared', () {
      final first = _paragraph('kept?');
      memo
        ..parseInlineContent([first], document)
        ..advance()
        ..clear();
      final again = _paragraph('kept?');

      memo.parseInlineContent([again], document);

      expect(again.children!.single, isNot(same(first.children!.single)));
    });
  });
}
