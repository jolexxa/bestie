import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const Color _backdrop = Color(0xFF282A36);

const HighlightTheme _backedTheme = HighlightTheme(
  styles: {},
  background: _backdrop,
);

const HighlightTheme _bareTheme = HighlightTheme(styles: {});

const double _paneWidth = 30;

const Size _terminalSize = Size(80, 8);

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

/// Pins a view to a fixed pane width beside empty space, the details pane's
/// shape.
Component _paned(Component child) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(width: _paneWidth, child: child),
    Expanded(child: const SizedBox()),
  ],
);

Color? _backgroundAt(NoctermTester tester, int x, int y) =>
    tester.terminalState.getCellAt(x, y)?.style.backgroundColor;

void main() {
  group('codeSpan', () {
    test('numbers every line, the gutter as wide as the last number', () {
      final text = _flatten(
        codeSpan(List.generate(10, (at) => 'line $at').join('\n')),
      );

      expect(text.split('\n').first, ' 1 line 0');
      expect(text.split('\n').last, '10 line 9');
    });

    test('ends the last line at a final newline instead of adding one', () {
      expect(_flatten(codeSpan('a\nb\n')), '1 a\n2 b');
      expect(_flatten(codeSpan('a\n\n')), '1 a\n2 ');
      expect(_flatten(codeSpan('')), '');
    });

    test('omits the gutter when asked', () {
      expect(_flatten(codeSpan('a\nb', showLineNumbers: false)), 'a\nb');
    });
  });

  group('CodeView', () {
    test('paints the backdrop to the edge of the pane on every row', () async {
      await testNocterm('code view backdrop', (tester) async {
        await tester.pumpComponent(
          _paned(
            const CodeView(
              'a = 1\n\nb = 2\n',
              theme: _backedTheme,
              language: 'python',
            ),
          ),
        );

        expect(tester.terminalState, containsText('1 a = 1'));
        for (var y = 0; y < 3; y++) {
          expect(_backgroundAt(tester, 0, y), _backdrop, reason: 'row $y');
          expect(
            _backgroundAt(tester, _paneWidth.toInt() - 1, y),
            _backdrop,
            reason: 'row $y right edge',
          );
        }
        expect(_backgroundAt(tester, _paneWidth.toInt(), 0), isNot(_backdrop));
        expect(_backgroundAt(tester, 0, 3), isNot(_backdrop));
      }, size: _terminalSize);
    });

    test('paints nothing behind a theme without a backdrop', () async {
      await testNocterm('code view bare', (tester) async {
        await tester.pumpComponent(
          _paned(const CodeView('a = 1\n', theme: _bareTheme)),
        );

        expect(tester.terminalState, containsText('1 a = 1'));
        expect(_backgroundAt(tester, _paneWidth.toInt() - 1, 0), isNull);
      }, size: _terminalSize);
    });
  });
}
