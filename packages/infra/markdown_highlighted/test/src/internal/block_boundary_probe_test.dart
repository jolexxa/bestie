import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/block_boundary_probe.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:test/test.dart';

List<md.Line> _lines(String source) =>
    LineSplitter.split(source).map(md.Line.new).toList();

void main() {
  group('BlockBoundaryProbe', () {
    late BlockBoundaryProbe probe;
    late md.Document document;

    setUp(() {
      probe = BlockBoundaryProbe();
      document = buildMarkdownDocument(probe: probe);
    });

    /// Parses [source] while watching, returning the recorded starts and
    /// the nodes it produced.
    List<md.Line> starts(String source, {required int nodeCount}) {
      final lines = _lines(source);
      probe.watch(lines);
      final nodes = document.parseLineList(lines);
      expect(nodes, hasLength(nodeCount));
      return probe.collect();
    }

    test('is the first syntax of the document it is built into', () {
      expect(document.blockSyntaxes.first, same(probe));
    });

    test('never matches a line on its own', () {
      expect(probe.pattern.hasMatch('anything'), isFalse);
      final parser = md.BlockParser(_lines('text'), document);
      expect(probe.canEndBlock(parser), isFalse);
      expect(probe.parse(parser), isNull);
    });

    test('records one start per block', () {
      final recorded = starts('one\n\ntwo\n\n- three\n- four', nodeCount: 3);

      expect(recorded.map((line) => line.content), ['one', 'two', '- three']);
    });

    test('skips blank lines, however many', () {
      final recorded = starts('one\n\n\n\n\ntwo', nodeCount: 2);

      expect(recorded.map((line) => line.content), ['one', 'two']);
    });

    test('records a setext heading once, at its text', () {
      final recorded = starts('Title\n===\n\nbody', nodeCount: 2);

      expect(recorded.map((line) => line.content), ['Title', 'body']);
    });

    test('records a loose list once', () {
      final recorded = starts('- a\n\n- b\n\nafter', nodeCount: 2);

      expect(recorded.map((line) => line.content), ['- a', 'after']);
    });

    test('ignores the lines nested parsers see', () {
      final recorded = starts('- a\n  - b\n\n> quote\n> more', nodeCount: 2);

      expect(recorded.map((line) => line.content), ['- a', '> quote']);
    });

    test('records a link reference definition that yields no node', () {
      final recorded = starts('[x]: https://x\n\nbody', nodeCount: 1);

      expect(recorded, hasLength(2));
    });

    test('records nothing while not watching', () {
      final lines = _lines('one\n\ntwo');
      document.parseLineList(lines);

      expect(probe.collect(), isEmpty);
    });

    test('forgets the previous watch', () {
      starts('one', nodeCount: 1);

      expect(starts('two\n\nthree', nodeCount: 2), hasLength(2));
    });
  });
}
