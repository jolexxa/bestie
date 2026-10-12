import 'package:markdown/markdown.dart' as md;

/// Parses a run of lines indented four spaces, which CommonMark reads as an
/// indented code block, as ordinary markdown blocks instead.
///
/// Model output fences its code, so an unfenced indented run is almost always
/// an outline whose parent line went missing. The run is dedented by the
/// indent and parsed again, returned as a `div` of the blocks it holds.
final class OrphanIndentSyntax extends md.BlockSyntax {
  /// Creates the syntax.
  const OrphanIndentSyntax();

  static final RegExp _indent = RegExp(r'^(?:    | {0,3}\t)(.*)$');

  @override
  RegExp get pattern => _indent;

  @override
  bool canEndBlock(md.BlockParser parser) => false;

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <md.Line>[];
    while (!parser.isDone) {
      final line = parser.current;
      if (line.isBlankLine) {
        if (_runEndsAfterBlanks(parser)) break;
        lines.add(md.Line(''));
      } else {
        final match = _indent.firstMatch(line.content);
        if (match == null) break;
        lines.add(md.Line(match[1]!));
      }
      parser.advance();
    }
    return md.Element(
      'div',
      md.BlockParser(lines, parser.document).parseLines(),
    );
  }

  /// Whether the blank lines at the parser's position are followed by the end
  /// of the input or by a line that is not indented.
  bool _runEndsAfterBlanks(md.BlockParser parser) {
    var ahead = 1;
    while (true) {
      final next = parser.peek(ahead);
      if (next == null) return true;
      if (!next.isBlankLine) return !_indent.hasMatch(next.content);
      ahead += 1;
    }
  }
}
