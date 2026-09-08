import 'package:markdown/markdown.dart' as md;

const _backslash = 0x5C;
const _dollar = 0x24;

/// Attribute set on a math element whose closing delimiter never arrived.
const String unterminatedMath = 'unterminated';

/// Inline syntaxes that recognise LaTeX math delimiters and lower each match to
/// a `math` (inline) or `mathDisplay` (block) element carrying the raw TeX.
///
/// Registered ahead of the CommonMark defaults so `\(` / `\[` are claimed here
/// before the backslash-escape handler can consume the leading slash. Single
/// `$` is intentionally omitted so currency (`$5 and $10`) stays literal.
final List<md.InlineSyntax> mathInlineSyntaxes = [
  _MathSyntax(r'\\\(([\s\S]+?)\\\)', tag: 'math', startCharacter: _backslash),
  _MathSyntax(
    r'\\\[([\s\S]+?)\\\]',
    tag: 'mathDisplay',
    startCharacter: _backslash,
  ),
  _MathSyntax(
    r'\$\$([\s\S]+?)\$\$',
    tag: 'mathDisplay',
    startCharacter: _dollar,
  ),
  _PendingMathSyntax(r'\\\([\s\S]*', startCharacter: _backslash),
  _PendingMathSyntax(r'\\\[[\s\S]*', startCharacter: _backslash),
  _PendingMathSyntax(r'\$\$[\s\S]*', startCharacter: _dollar),
];

class _MathSyntax extends md.InlineSyntax {
  _MathSyntax(super.pattern, {required this.tag, super.startCharacter});

  final String tag;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(tag, match[1]!.trim()));
    return true;
  }
}

class _PendingMathSyntax extends md.InlineSyntax {
  _PendingMathSyntax(super.pattern, {super.startCharacter});

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // Verbatim, delimiter included: with no closer there is no body to trim to,
    // and a caller that decides this run is settled has nothing to show but the
    // characters as the model wrote them.
    parser.addNode(md.Element.text('mathPending', match[0]!));
    return true;
  }
}

/// Block syntaxes that recognise a display-math block whose opener sits at the
/// start of a line (`\[…\]` or `$$…$$`), spanning one or many lines.
///
/// A display block is captured *raw* — like a fenced code block — so its body
/// never reaches the block parser. That is what lets a multi-line block survive
/// blank lines and keeps a leading `-` a literal minus instead of being read as
/// a list bullet. Each block lowers to a `mathBlock` element carrying the raw
/// TeX — distinct from the inline `mathDisplay` tag so the visitor can set
/// block spacing around it without disturbing in-paragraph display math.
///
/// The inline [mathInlineSyntaxes] still handle mid-paragraph and table-cell
/// math, where block syntaxes don't run.
final List<md.BlockSyntax> mathBlockSyntaxes = [
  _MathBlockSyntax(opener: r'\[', closer: r'\]'),
  _MathBlockSyntax(opener: r'$$', closer: r'$$'),
];

class _MathBlockSyntax extends md.BlockSyntax {
  _MathBlockSyntax({required this.opener, required this.closer})
    : pattern = RegExp(r'^\s*' + RegExp.escape(opener));

  final String opener;
  final String closer;

  @override
  final RegExp pattern;

  @override
  md.Node parse(md.BlockParser parser) {
    final body = <String>[];
    final first = parser.current.content;
    final openMatch = pattern.firstMatch(first)!;
    final rest = first.substring(openMatch.end);
    parser.advance();

    var closed = true;
    final closeOnFirst = rest.indexOf(closer);
    if (closeOnFirst != -1) {
      body.add(rest.substring(0, closeOnFirst));
    } else {
      body.add(rest);
      // Running out of lines is not the same as finding the closer.
      closed = false;
      while (!parser.isDone) {
        final content = parser.current.content;
        final closeIndex = content.indexOf(closer);
        if (closeIndex != -1) {
          body.add(content.substring(0, closeIndex));
          parser.advance();
          closed = true;
          break;
        }
        body.add(content);
        parser.advance();
      }
    }

    final element = md.Element.text('mathBlock', body.join('\n').trim());
    if (!closed) element.attributes[unterminatedMath] = 'true';
    return element;
  }
}
