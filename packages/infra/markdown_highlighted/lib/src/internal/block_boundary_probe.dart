import 'package:markdown/markdown.dart' as md;

/// A block syntax that matches nothing. While it watches a list of lines, it
/// records the first line of every top-level block the parser starts in them,
/// so a caller can tell where the last block of a parse began.
///
/// It has to be the first block syntax of its document: the parser offers a
/// line to each syntax in order and stops at the first match, so any later
/// position would miss the blocks an earlier syntax claims.
final class BlockBoundaryProbe extends md.BlockSyntax {
  /// Creates a probe that watches nothing yet.
  BlockBoundaryProbe();

  static final RegExp _never = RegExp('(?!)');

  List<md.Line>? _watched;
  List<md.Line> _starts = [];

  @override
  RegExp get pattern => _never;

  @override
  bool canEndBlock(md.BlockParser parser) => false;

  @override
  bool canParse(md.BlockParser parser) {
    if (identical(parser.lines, _watched)) {
      _record(parser.linesToConsume.first);
    }
    return false;
  }

  @override
  md.Node? parse(md.BlockParser parser) => null;

  /// Blank lines never become a block, and a paragraph the parser retries as a
  /// setext heading is offered again from the same first line.
  void _record(md.Line start) {
    if (start.isBlankLine) return;
    if (_starts.isNotEmpty && identical(_starts.last, start)) return;
    _starts.add(start);
  }

  /// Records the block starts of the next parse of [lines].
  void watch(List<md.Line> lines) {
    _watched = lines;
    _starts = [];
  }

  /// The first line of each top-level block started since [watch], in order.
  /// Stops watching.
  List<md.Line> collect() {
    _watched = null;
    return _starts;
  }
}
