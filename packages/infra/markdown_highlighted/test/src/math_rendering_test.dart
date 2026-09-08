import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

String _render(String data, {int? maxWidth, bool streaming = false}) {
  final nodes = buildMarkdownDocument().parse(data);
  final visitor = MarkdownVisitor(
    theme: MarkdownTheme.terminal(),
    builders: MarkdownBuilders.defaults(),
    maxWidth: maxWidth,
    streaming: streaming,
  );
  return [
    for (final block in visitor.visit(nodes))
      switch (block) {
        ProseBlock(:final span) ||
        CodeBlock(:final span) ||
        MathBlock(:final span) ||
        TableBlock(:final span) => _flatten(span),
        RuleBlock() => '',
      },
  ].join('\n\n');
}

/// The placeholder an unterminated run collapses to while streaming.
const _pending = '…';

void main() {
  group('inline math', () {
    test(r'linearizes \(…\) to a single unicode row', () {
      expect(_render(r'the value \(x^2\) here'), contains('x²'));
    });

    test('keeps a run of prose on one line', () {
      expect(_render(r'index \(a_i\) done'), 'index aᵢ done');
    });

    test('leaves single-dollar currency literal', () {
      expect(_render(r'costs $5 and $10 total'), contains(r'$5 and $10'));
    });

    test('falls back to raw tex when the inline math is malformed', () {
      expect(_render(r'oops \(\frac{\) end'), contains(r'\frac{'));
    });
  });

  group('display math', () {
    test(r'lays \[…\] out as a 2D grid', () {
      expect(_render(r'\[ \frac{a}{b} \]'), 'a\n─\nb');
    });

    test(r'lays $$…$$ out as a 2D grid', () {
      expect(_render(r'$$ \frac{a}{b} $$'), 'a\n─\nb');
    });

    test('never bakes centring spaces into the grid text', () {
      // Centring is the math block component's layout job. Padding the text
      // would shift selection char indexes on every pane resize.
      expect(_render(r'\[ \frac{a}{b} \]', maxWidth: 21), 'a\n─\nb');
    });

    test('keeps a grid wider than maxWidth intact instead of clipping it', () {
      // Pane-edge clipping happens at paint time (ClipRect around the math
      // block); mutating the text would make it width-dependent.
      const tex = r'\[ \frac{a+b+c+d+e+f}{g} \]';
      expect(_render(tex, maxWidth: 10), _render(tex));
    });

    test('falls back to raw tex when the display math is malformed', () {
      expect(_render(r'\[ \frac{ \]'), contains(r'\frac{'));
    });
  });

  group('streaming math', () {
    test('holds an unclosed inline run behind a placeholder', () {
      expect(
        _render(r'the value \(x^2', streaming: true),
        'the value $_pending',
      );
    });

    test('holds an unclosed display run behind a placeholder', () {
      expect(_render(r'see \[\frac{a}{b}', streaming: true), 'see $_pending');
    });

    test(r'holds an unclosed $$ run behind a placeholder', () {
      expect(_render(r'see $$\frac{a}{b}', streaming: true), 'see $_pending');
    });

    test('holds an unclosed block behind a placeholder', () {
      expect(_render('\\[\n\\frac{a}{b}', streaming: true), _pending);
    });

    test('keeps the placeholder one cell as the run grows', () {
      // The point of the placeholder: an equation gaining a character must not
      // re-lay out at a new size and shove the rows around it.
      const prefix = r'the value \(';
      final sizes = {
        for (final tex in ['x', 'x^2', 'x^2+y', r'\frac{a}{b}'])
          _render('$prefix$tex', streaming: true).length,
      };

      expect(sizes, {'the value $_pending'.length});
    });

    test('lays the run out for real once its closer arrives', () {
      expect(_render(r'the value \(x^2\)', streaming: true), 'the value x²');
    });

    test('shows a settled unclosed inline run verbatim', () {
      // Nothing more is coming, so this is the model's own text — not a run
      // still being written — and it belongs on screen as written.
      expect(_render(r'the value \(x^2'), r'the value \(x^2');
    });

    test('shows a settled unclosed block through the usual math path', () {
      expect(_render('\\[\n\\frac{a}{b}'), 'a\n─\nb');
    });

    test('leaves prose with no math untouched while streaming', () {
      expect(_render('just words', streaming: true), 'just words');
    });

    test('leaves single-dollar currency literal while streaming', () {
      expect(
        _render(r'costs $5 and $10 total', streaming: true),
        contains(r'$5 and $10'),
      );
    });
  });

  group('block display math', () {
    test('renders a display block that stands on its own line', () {
      expect(_render('\\[\n\\frac{a}{b}\n\\]'), 'a\n─\nb');
    });

    test(r'renders a $$ block on its own line', () {
      expect(_render('\$\$\n\\frac{a}{b}\n\$\$'), 'a\n─\nb');
    });

    test('keeps a leading - a literal minus, not a list bullet', () {
      // A continuation line starting with `- ` used to be shredded into a
      // markdown list item, emitting a phantom bullet. Captured raw, it stays
      // a subtraction.
      final rendered = _render('\\[\na\n- b\n\\]');
      expect(rendered, contains('−'));
      expect(rendered, isNot(contains('•')));
    });

    test('survives a blank line inside the block', () {
      final rendered = _render('\\[\na\n\n- b\n\\]');
      expect(rendered, contains('−'));
      expect(rendered, isNot(contains('•')));
    });

    test('renders a multi-line fraction block as a 2D grid', () {
      expect(_render('\\[\n\\frac{a}{b}\n-\n\\frac{c}{d}\n\\]'), contains('─'));
    });

    test(r'breaks mid-paragraph \[…\] display math onto its own line', () {
      // The opener sits after prose, so the block syntax doesn't claim it and
      // it arrives as inline `mathDisplay`. It's still display math, so it must
      // break onto its own line rather than welding its first grid row to the
      // trailing text.
      final rendered = _render(r'before \[\frac{a}{b}\] after');
      expect(rendered, contains('before \n'));
      expect(rendered, contains('a\n─\nb'));
      expect(rendered, isNot(contains('before a')));
    });

    test('breaks display math out of a list item onto its own line', () {
      // The bullet-plus-trailing-display-math shape that read as a bug: the
      // grid must not start on the same line as the bullet prose.
      final rendered = _render(r'- action $$\frac{a}{b}$$');
      expect(rendered, contains('action \n'));
      expect(rendered, isNot(contains('action a')));
      expect(rendered, contains('a\n─\nb'));
    });

    test('holds an unclosed nested block behind a placeholder', () {
      // An indented, unterminated block equation inside a list item while
      // streaming — the nested mathBlock path's pending branch.
      final rendered = _render(
        '- action:\n  \\[\n\\frac{a}{b}',
        streaming: true,
      );
      expect(rendered, contains(_pending));
      expect(rendered, isNot(contains('─')));
    });

    test('breaks an indented block equation off its bullet prose', () {
      // An indented `$$` block stays inside the list item as a `mathBlock`
      // (not the inline `mathDisplay`). Following the item's inline text, it
      // still needs a leading break or its first grid row welds to the bullet.
      final rendered = _render('- action:\n  \\[\n\\frac{a}{b}\n  \\]');
      expect(rendered, contains('action:\n'));
      expect(rendered, isNot(contains('action:a')));
      expect(rendered, contains('a\n─\nb'));
    });

    test('separates a block from the paragraph that follows it', () {
      // The block is its own element, so following prose must not butt against
      // the grid's last row.
      final rendered = _render('\\[\n\\frac{a}{b}\n\\]\nafter');
      expect(rendered, contains('b\n\nafter'));
    });
  });

  group('math inside headings', () {
    test('uppercases the prose but leaves the math case intact', () {
      expect(_render(r'# formula \(n - a_n\) done'), 'FORMULA n − aₙ DONE');
    });

    test('does not uppercase display math under a heading', () {
      // The heading uppercases 'result', but the display grid keeps its
      // lowercase base 'p' — a capital 'P' would be a different variable.
      final rendered = _render(r'# result \[ p_k \]');
      expect(rendered, contains('RESULT'));
      expect(rendered, contains('p'));
      expect(rendered, isNot(contains('P')));
    });
  });

  group('math inside tables', () {
    String table(String cell) => '| A | B |\n|---|---|\n| $cell | x |';

    test('linearizes inline math in a cell', () {
      expect(_render(table(r'\(x^2\)')), contains('x²'));
    });

    test('linearizes display delimiters to inline form in a cell', () {
      expect(_render(table(r'\[a+b\]')), contains('a + b'));
    });

    test('keeps plain cell text intact', () {
      expect(_render(table('plain')), contains('plain'));
    });

    test('flattens formatting around math in a cell', () {
      expect(_render(table(r'**b** \(y^2\)')), contains('b y²'));
    });

    test('falls back to raw tex for malformed math in a cell', () {
      expect(_render(table(r'\(\frac{\)')), contains(r'\frac{'));
    });
  });
}
