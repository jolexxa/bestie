import 'dart:math';

import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/incremental_markdown_parser.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:nocterm/nocterm.dart' show InlineSpan;
import 'package:test/test.dart';

import '../fixtures/reasoning_outline.dart';
import '../support/markdown_generator.dart';

final MarkdownVisitor _visitor = MarkdownVisitor(
  theme: MarkdownTheme.terminal(),
  builders: MarkdownBuilders.defaults(),
  maxWidth: 60,
  streaming: true,
);

List<MarkdownBlock> _renderFull(String source) =>
    _visitor.visit(buildMarkdownDocument().parse(source));

InlineSpan? _spanOf(MarkdownBlock block) => switch (block) {
  ProseBlock(:final span) ||
  CodeBlock(:final span) ||
  MathBlock(:final span) ||
  TableBlock(:final span) => span,
  RuleBlock() => null,
};

/// Fails unless [actual] renders to exactly the blocks [expected] does.
void _expectSameBlocks(
  List<MarkdownBlock> actual,
  List<MarkdownBlock> expected, {
  required String reason,
}) {
  expect(actual, hasLength(expected.length), reason: reason);
  for (final (index, block) in actual.indexed) {
    expect(block.runtimeType, expected[index].runtimeType, reason: reason);
    expect(_spanOf(block), _spanOf(expected[index]), reason: reason);
  }
}

/// Feeds [source] to a fresh parser in random chunks, checking after every
/// chunk that the incremental parse renders exactly like a full parse and
/// that the nodes it calls stable are the instances it handed out before.
void _replay(String source, Random random, {int maxChunk = 32}) {
  final parser = IncrementalMarkdownParser();
  var previous = const <md.Node>[];
  var fed = 0;
  while (fed < source.length) {
    fed = min(source.length, fed + 1 + random.nextInt(maxChunk));
    final partial = source.substring(0, fed);
    final parse = parser.update(partial);
    final reason = 'after ${partial.length} of ${source.length} chars';

    expect(
      parse.stableCount,
      lessThanOrEqualTo(previous.length),
      reason: reason,
    );
    for (var index = 0; index < parse.stableCount; index++) {
      expect(parse.nodes[index], same(previous[index]), reason: reason);
    }
    _expectSameBlocks(
      _visitor.visit(parse.nodes),
      _renderFull(partial),
      reason: reason,
    );
    previous = parse.nodes;
  }
}

void main() {
  group('IncrementalMarkdownParser', () {
    test('renders like a full parse at every step of a streamed document', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        _replay(generateMarkdown(random, blockCount: 10), random);
      }
    });

    test('renders the reasoning fixture like a full parse at every step', () {
      _replay(reasoningOutlineFixture, Random(1), maxChunk: 8);
    });

    test('keeps the nodes before the last block as the source grows', () {
      final parser = IncrementalMarkdownParser();
      final first = parser.update('one\n\ntwo\n\nthr');

      final second = parser.update('one\n\ntwo\n\nthree\n\nfour');

      expect(second.stableCount, 2);
      expect(second.nodes.take(2), orderedEquals(first.nodes.take(2)));
      expect(second.nodes[2], isNot(same(first.nodes[2])));
      expect(second.nodes, hasLength(4));
    });

    test('a list that grows is still one node, parsed again', () {
      final parser = IncrementalMarkdownParser()..update('intro\n\n- a\n- b');

      final grown = parser.update('intro\n\n- a\n- b\n\n- c');

      expect(grown.stableCount, 1);
      expect(grown.nodes, hasLength(2));
      expect((grown.nodes[1] as md.Element).children, hasLength(3));
    });

    test('a list that grows keeps the inline parse of its earlier items', () {
      final parser = IncrementalMarkdownParser()..update('- **a**\n- b');
      final first = parser.update('- **a**\n- b\n- c');

      final grown = parser.update('- **a**\n- b\n- c\n- d');

      md.Node firstItemStrong(MarkdownParse parse) {
        final list = parse.nodes.single as md.Element;
        final item = list.children!.first as md.Element;
        return item.children!.first;
      }

      expect(grown.stableCount, 0);
      expect(grown.nodes.single, isNot(same(first.nodes.single)));
      expect(firstItemStrong(grown), same(firstItemStrong(first)));
    });

    test('an unclosed fence or math block at the tail stays the tail', () {
      final parser = IncrementalMarkdownParser()
        ..update('text\n\n```dart\nvar a');

      final closed = parser.update('text\n\n```dart\nvar a = 1;\n```\n\nmore');

      expect(closed.stableCount, 1);
      expect(closed.nodes.map((node) => (node as md.Element).tag), [
        'p',
        'pre',
        'p',
      ]);
    });

    test('starts over when the source changes before the tail', () {
      final parser = IncrementalMarkdownParser();
      final first = parser.update('one\n\ntwo\n\nthree');

      final edited = parser.update('ONE\n\ntwo\n\nthree');

      expect(edited.stableCount, 0);
      expect(edited.nodes.first, isNot(same(first.nodes.first)));
      expect((edited.nodes.first as md.Element).textContent, 'ONE');
    });

    test('starts over when the source shrinks', () {
      final parser = IncrementalMarkdownParser()..update('one\n\ntwo\n\nthree');

      final shorter = parser.update('one');

      expect(shorter.stableCount, 0);
      expect(shorter.nodes, hasLength(1));
    });

    test('parses a document with link references whole every time', () {
      final parser = IncrementalMarkdownParser()
        ..update('[ref]: https://example.com\n\nsee [it][ref]');

      final grown = parser.update(
        '[ref]: https://example.com\n\nsee [it][ref]\n\nmore',
      );

      expect(grown.stableCount, 0);
      final link = (grown.nodes[0] as md.Element).children!
          .whereType<md.Element>();
      expect(link.single.attributes['href'], 'https://example.com');
    });

    test('parses a document with footnotes whole every time', () {
      final parser = IncrementalMarkdownParser()
        ..update('note[^1]\n\n[^1]: the note');

      final grown = parser.update('note[^1]\n\n[^1]: the note\n\nmore');

      expect(grown.stableCount, 0);
      expect(
        grown.nodes.map((node) => (node as md.Element).tag),
        ['p', 'p', 'section'],
      );
    });

    test('a raw HTML block that opens the tail keeps its leading newline', () {
      final parser = IncrementalMarkdownParser()..update('before\n\n<div>\nhi');

      final grown = parser.update('before\n\n<div>\nhi there');

      expect(grown.stableCount, 1);
      expect((grown.nodes[1] as md.Text).text, '\n<div>\nhi there');
      _expectSameBlocks(
        _visitor.visit(grown.nodes),
        _renderFull('before\n\n<div>\nhi there'),
        reason: 'html tail',
      );
    });

    test('a paragraph that grows into raw HTML gets the newline too', () {
      final parser = IncrementalMarkdownParser()..update('before\n\n<di');

      final grown = parser.update('before\n\n<div>');

      expect(grown.stableCount, 1);
      expect((grown.nodes[1] as md.Text).text, '\n<div>');
    });

    test('leading blank lines count as a predecessor of raw HTML', () {
      final parser = IncrementalMarkdownParser()..update('\n\n<di');

      final grown = parser.update('\n\n<div>');

      expect(grown.stableCount, 0);
      expect((grown.nodes.single as md.Text).text, '\n<div>');
    });

    test('raw HTML that opens the source has no newline to take', () {
      final parser = IncrementalMarkdownParser()..update('<di');

      final grown = parser.update('<div>');

      expect((grown.nodes.single as md.Text).text, '<div>');
    });

    test('renders documents with every feature like a full parse', () {
      const features = MarkdownFeatures(
        linkReferences: true,
        footnotes: true,
        htmlBlocks: true,
      );
      for (var seed = 0; seed < 12; seed++) {
        final random = Random(seed);
        _replay(
          generateMarkdown(random, blockCount: 10, features: features),
          random,
        );
      }
    });

    test('renders like a full parse with carriage return line endings', () {
      for (var seed = 0; seed < 12; seed++) {
        final random = Random(seed);
        final source = generateMarkdown(random, blockCount: 8)
            .split('\n')
            .map((line) => random.nextBool() ? '$line\r\n' : '$line\r')
            .join();
        _replay(source, random, maxChunk: 5);
      }
    });

    test('handles an empty source', () {
      final parser = IncrementalMarkdownParser();

      expect(parser.update('').nodes, isEmpty);
      expect(parser.update('text').nodes, hasLength(1));
    });
  });
}
