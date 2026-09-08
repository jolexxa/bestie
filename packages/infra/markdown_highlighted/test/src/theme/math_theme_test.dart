import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _red = TextStyle(color: Colors.red);
const _green = TextStyle(color: Colors.green);

const _theme = MathTheme(tagger: tagSymbols, slotStyles: [_red, _green]);

/// Renders [data] and returns the math block's span.
InlineSpan _mathSpan(String data, {MathTheme theme = MathTheme.none}) {
  final nodes = buildMarkdownDocument().parse(data);
  final visitor = MarkdownVisitor(
    theme: MarkdownTheme.terminal(),
    builders: MarkdownBuilders.defaults(),
    mathTheme: theme,
  );
  final block = visitor.visit(nodes).whereType<MathBlock>().single;
  return block.span;
}

/// Holds a [MathThemeScope] whose data can be swapped without rebuilding the
/// tree around it — the shape a live theme change takes.
class _Swapper extends StatefulComponent {
  const _Swapper({required this.initial, required this.onReady});

  final MathTheme initial;
  final void Function(void Function(MathTheme)) onReady;

  @override
  State<_Swapper> createState() => _SwapperState();
}

class _SwapperState extends State<_Swapper> {
  late MathTheme _data = component.initial;

  @override
  void initState() {
    super.initState();
    component.onReady((next) => setState(() => _data = next));
  }

  @override
  Component build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 20,
      height: 3,
      child: MathThemeScope(
        data: _data,
        child: const MarkdownView(r'$$a + b$$'),
      ),
    ),
  );
}

/// The (text, style) runs a span tree flattens to.
List<(String, TextStyle?)> _runs(InlineSpan span) => [
  for (final segment in (span as TextSpan).toStyledSegments())
    (segment.text, segment.style),
];

String _plain(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

void main() {
  group('styleFor', () {
    test('cycles slot styles, wrapping past the end', () {
      expect(_theme.styleFor(0), _red);
      expect(_theme.styleFor(1), _green);
      expect(_theme.styleFor(2), _red);
      expect(_theme.styleFor(5), _green);
    });

    test('paints nothing for an unslotted cell', () {
      expect(_theme.styleFor(null), isNull);
    });

    test('paints nothing when no slot styles are given', () {
      expect(const MathTheme(tagger: tagSymbols).styleFor(0), isNull);
    });

    test('MathTheme.none paints nothing at all', () {
      expect(MathTheme.none.styleFor(0), isNull);
      expect(MathTheme.none.styleFor(null), isNull);
    });
  });

  group('isPlain', () {
    test('is true only when the theme would paint nothing', () {
      expect(MathTheme.none.isPlain, isTrue);
      expect(_theme.isPlain, isFalse);
      expect(const MathTheme(slotStyles: [_red]).isPlain, isFalse);
    });
  });

  group('equality', () {
    // Themes are derived per build rather than held, so two derivations of the
    // same styling have to be interchangeable — it is what stops a rebuild
    // from re-laying-out every equation on screen.
    test('two separately built themes agree', () {
      const other = MathTheme(tagger: tagSymbols, slotStyles: [_red, _green]);
      expect(other, _theme);
      expect(other.hashCode, _theme.hashCode);
    });

    test('a different slot cycle is a different theme', () {
      const other = MathTheme(tagger: tagSymbols, slotStyles: [_green, _red]);
      expect(other, isNot(_theme));
    });

    test('the same colours under a different rule is a different theme', () {
      const other = MathTheme(slotStyles: [_red, _green]);
      expect(other, isNot(_theme));
    });

    test('a MathTheme is never equal to some other value', () {
      expect(_theme, isNot(Object()));
    });
  });

  group('span emission', () {
    test('paints each symbol from the cycle', () {
      final runs = _runs(_mathSpan(r'$$a + b$$', theme: _theme));
      expect(runs, contains(('a', _red)));
      expect(runs, contains(('b', _green)));
    });

    test('leaves an operator to the surrounding style', () {
      // Operators carry meaning and are not structure the renderer drew, so
      // they read as body text rather than receding. The spacing katex sets
      // around them is unclaimed too, so the whole gap coalesces into one run.
      final runs = _runs(_mathSpan(r'$$a + b$$', theme: _theme));
      expect(runs, contains((' + ', null)));
    });

    test('leaves a fraction bar to the surrounding style', () {
      // Structure the renderer drew is already visible as structure; only the
      // symbols take a colour.
      final runs = _runs(_mathSpan(r'$$\frac{a}{b}$$', theme: _theme));
      expect(runs, contains(('─', null)));
    });

    test('coalesces a run of cells sharing a slot into one span', () {
      final runs = _runs(_mathSpan(r'$$xx$$', theme: _theme));
      expect(runs, contains(('xx', _red)));
    });

    test('rejoins rows with newlines', () {
      expect(_plain(_mathSpan(r'$$\frac{a}{b}$$', theme: _theme)), 'a\n─\nb');
    });

    test('renders the same text as an unthemed pass', () {
      const tex = r'$$\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$';
      expect(
        _plain(_mathSpan(tex, theme: _theme)),
        _plain(_mathSpan(tex)),
      );
    });

    test('emits a single unstyled run under MathTheme.none', () {
      final runs = _runs(_mathSpan(r'$$a + b$$'));
      expect(runs.every((run) => run.$2 == null), isTrue);
    });

    test('falls back to raw tex when the math is malformed', () {
      final span = _mathSpan(r'$$\frac{$$', theme: _theme);
      expect(_plain(span), contains(r'\frac{'));
    });

    test('a math span survives heading uppercasing untouched', () {
      // `\Pi` and `\pi` are different symbols; rewriting the characters of an
      // already-laid-out grid corrupts it.
      final span = _mathSpan(r'$$x + y$$', theme: _theme);
      expect(_plain(MarkdownVisitor.uppercase(span as TextSpan)), _plain(span));
    });
  });

  group('MarkdownView', () {
    /// The painted colour of the cell showing [glyph] on the first row.
    Color? colorOf(NoctermTester tester, String glyph) {
      final row = tester.terminalState.getTextAt(0, 0, length: 20) ?? '';
      final x = row.indexOf(glyph);
      expect(x, isNonNegative, reason: 'no "$glyph" in "$row"');
      return tester.terminalState.getCellAt(x, 0)?.style.color;
    }

    test('paints display math from the enclosing scope', () async {
      await testNocterm('scoped math', (tester) async {
        await tester.pumpComponent(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 20,
              height: 3,
              child: MathThemeScope(
                data: _theme,
                child: MarkdownView(r'$$a + b$$'),
              ),
            ),
          ),
        );
        expect(colorOf(tester, 'a'), Colors.red);
        expect(colorOf(tester, 'b'), Colors.green);
      });
    });

    test('repaints when the scope swaps its theme in place', () async {
      // What a live theme switch does: the scope stays put and its data
      // changes. The view has to notice and re-emit its spans rather than keep
      // the colours it parsed the first time.
      await testNocterm('scope swap', (tester) async {
        late void Function(MathTheme) swap;
        await tester.pumpComponent(
          _Swapper(initial: _theme, onReady: (fn) => swap = fn),
        );
        expect(colorOf(tester, 'a'), Colors.red);

        swap(const MathTheme(tagger: tagSymbols, slotStyles: [_green]));
        await tester.pump();

        expect(colorOf(tester, 'a'), Colors.green);
      });
    });

    test('leaves display math unpainted with no scope installed', () async {
      await testNocterm('unscoped math', (tester) async {
        await tester.pumpComponent(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 20,
              height: 3,
              child: MarkdownView(r'$$a + b$$'),
            ),
          ),
        );
        expect(colorOf(tester, 'a'), colorOf(tester, 'b'));
      });
    });
  });
}
