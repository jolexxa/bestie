import 'package:markdown/markdown.dart' as md;

/// Remembers the inline parse of every leaf text one parse used, so the next
/// parse of a block that only grew re-parses just its new text.
///
/// Entries live for one parse beyond the one that made them: [advance] keeps
/// what the finished parse used and drops the rest, which bounds the memo to
/// the texts of the block being parsed again.
///
/// An inline parse also depends on the document's link references and
/// footnotes, so a memo is only exact while its document has none; [clear]
/// it when that stops being true.
final class InlineMemo {
  /// Creates an empty memo.
  InlineMemo();

  Map<String, List<md.Node>> _previous = {};
  Map<String, List<md.Node>> _current = {};

  /// Replaces every unparsed leaf under [nodes] with its inline nodes, the
  /// way the document's own parse does, taking each from the memo when it
  /// has it.
  void parseInlineContent(List<md.Node> nodes, md.Document document) {
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node is md.UnparsedContent) {
        final inlineNodes = _parse(node.textContent, document);
        nodes
          ..removeAt(index)
          ..insertAll(index, inlineNodes);
        index += inlineNodes.length - 1;
      } else if (node case md.Element(:final children?)) {
        parseInlineContent(children, document);
      }
    }
  }

  List<md.Node> _parse(String text, md.Document document) =>
      _current[text] ??= _previous[text] ?? document.parseInline(text);

  /// Keeps only what the parse just finished used.
  void advance() {
    _previous = _current;
    _current = {};
  }

  /// Forgets everything.
  void clear() {
    _previous = {};
    _current = {};
  }
}
