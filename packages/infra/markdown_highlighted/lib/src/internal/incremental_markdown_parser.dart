import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/block_boundary_probe.dart';
import 'package:markdown_highlighted/src/internal/inline_memo.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';

/// The top-level nodes of a markdown source after an update.
final class MarkdownParse {
  /// Creates a parse of [nodes] whose first [stableCount] are the same
  /// instances the previous update produced.
  const MarkdownParse({required this.nodes, required this.stableCount});

  /// The document's top-level nodes.
  final List<md.Node> nodes;

  /// How many leading [nodes] are the same instances as last time, so their
  /// rendering can be kept.
  final int stableCount;
}

/// Parses a markdown source that grows between updates, parsing again only
/// the part that can still change.
///
/// Block parsing only moves forward: once the parser has started a top-level
/// block, every block before it is final however the source grows. Each
/// update therefore parses from the start of the previous last block and
/// keeps the nodes before it, and the inline parse of every leaf text that
/// block held last time is reused.
///
/// The library carries three things across blocks. Link reference
/// definitions and footnotes live on the document, so a source holding any
/// is parsed whole. A raw HTML block takes a leading newline from having a
/// predecessor, which is given to one that opens a tail.
final class IncrementalMarkdownParser {
  /// Creates a parser with nothing parsed yet.
  IncrementalMarkdownParser();

  final _probe = BlockBoundaryProbe();
  final _memo = InlineMemo();
  late md.Document _document = buildMarkdownDocument(probe: _probe);
  String _stableSource = '';
  List<md.Node> _stableNodes = const [];
  String? _sharedStatePrefix;

  /// Parses [source], reusing what the previous update settled.
  MarkdownParse update(String source) {
    if (_sharedStatePrefix case final prefix? when source.startsWith(prefix)) {
      return _parseWhole(source);
    }
    if (!source.startsWith(_stableSource)) _reset();
    final tail = _parseBlocks(source);
    if (_documentSharesState) {
      _reset();
      _sharedStatePrefix = source;
      return _parseWhole(source);
    }
    _joinRawHtml(tail);
    _memo.parseInlineContent(tail.nodes, _document);
    _memo.advance();
    final nodes = [..._stableNodes, ...tail.nodes];
    final stableCount = _stableNodes.length;
    _settle(source, tail, nodes);
    return MarkdownParse(nodes: nodes, stableCount: stableCount);
  }

  /// Definitions and footnotes register while blocks parse, and a source
  /// that holds any keeps them however it grows.
  bool get _documentSharesState =>
      _document.linkReferences.isNotEmpty ||
      _document.footnoteReferences.isNotEmpty;

  void _reset() {
    _stableSource = '';
    _stableNodes = const [];
    _sharedStatePrefix = null;
    _document = buildMarkdownDocument(probe: _probe);
    _memo.clear();
  }

  MarkdownParse _parseWhole(String source) => MarkdownParse(
    nodes: buildMarkdownDocument().parse(source),
    stableCount: 0,
  );

  /// Block-parses the part of [source] after the settled prefix.
  _Tail _parseBlocks(String source) {
    final text = source.substring(_stableSource.length);
    final lines = LineSplitter.split(text).map(md.Line.new).toList();
    _probe.watch(lines);
    final nodes = md.BlockParser(lines, _document).parseLines();
    return _Tail(
      text: text,
      lines: lines,
      nodes: nodes,
      starts: _probe.collect(),
    );
  }

  /// A raw HTML block, the one block the library returns as a top-level text
  /// node, takes a leading newline from having anything before it, blank
  /// lines included, which a tail parsed on its own cannot see.
  void _joinRawHtml(_Tail tail) {
    if (_stableSource.isEmpty) return;
    if (tail.nodes.firstOrNull case md.Text(:final text)) {
      tail.nodes[0] = md.Text('\n$text');
    }
  }

  /// Moves the settled prefix up to the start of the last block, when the
  /// block starts the probe saw line up with the nodes.
  void _settle(String source, _Tail tail, List<md.Node> nodes) {
    if (tail.starts.length != tail.nodes.length || tail.nodes.isEmpty) return;
    _stableSource = source.substring(
      0,
      _stableSource.length + tail.lastBlockStartOffset(),
    );
    _stableNodes = nodes.sublist(0, nodes.length - 1);
  }
}

final class _Tail {
  const _Tail({
    required this.text,
    required this.lines,
    required this.nodes,
    required this.starts,
  });

  final String text;
  final List<md.Line> lines;
  final List<md.Node> nodes;
  final List<md.Line> starts;

  /// The offset in [text] of the line the last block starts on.
  int lastBlockStartOffset() {
    final lineIndex = lines.indexWhere(
      (line) => identical(line, starts.last),
    );
    return _lineStartOffset(text, lineIndex);
  }
}

/// The offset of the first character of line [lineIndex], counting lines the
/// way `LineSplitter` does: a line ends at `\n`, `\r` or `\r\n`.
int _lineStartOffset(String text, int lineIndex) {
  const lineFeed = 0x0A;
  const carriageReturn = 0x0D;
  var offset = 0;
  for (var line = 0; line < lineIndex; line++) {
    while (true) {
      final unit = text.codeUnitAt(offset++);
      if (unit == lineFeed) break;
      if (unit == carriageReturn) {
        if (offset < text.length && text.codeUnitAt(offset) == lineFeed) {
          offset++;
        }
        break;
      }
    }
  }
  return offset;
}
