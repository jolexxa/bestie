import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const Color _backdrop = Color(0xFF282A36);

/// A highlight theme with a backdrop, mirroring the shape bestie derives from
/// its app theme.
const HighlightTheme _backedTheme = HighlightTheme(
  styles: {},
  background: _backdrop,
);

const double _paneWidth = 30;

const Size _terminalSize = Size(80, 14);

/// Pins a markdown view to a fixed pane width beside empty space, the chat
/// pane's shape.
Component _paned(String data, {double width = _paneWidth}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: width,
      child: MarkdownView(data, highlightTheme: _backedTheme),
    ),
    Expanded(child: const SizedBox()),
  ],
);

Color? _backgroundAt(NoctermTester tester, int x, int y) =>
    tester.terminalState.getCellAt(x, y)?.style.backgroundColor;

void main() {
  group('MarkdownView blocks', () {
    test('code backdrop spans the pane, including blank code lines', () async {
      await testNocterm('code backdrop', (tester) async {
        // A blank line INSIDE the fence: its row has no glyphs at all, so
        // only a box-layer backdrop can color it.
        await tester.pumpComponent(
          _paned('```dart\na = 1\n\nb = 2\n```'),
        );
        expect(tester.terminalState, containsText('a = 1'));
        for (var y = 0; y < 3; y++) {
          expect(
            _backgroundAt(tester, 0, y),
            _backdrop,
            reason: 'row $y left edge',
          );
          expect(
            _backgroundAt(tester, _paneWidth.toInt() - 1, y),
            _backdrop,
            reason: 'row $y right edge',
          );
        }
        // The backdrop stops at the pane boundary.
        expect(_backgroundAt(tester, _paneWidth.toInt(), 0), isNot(_backdrop));
      }, size: _terminalSize);
    });

    test('a horizontal rule paints across the pane with no text', () async {
      await testNocterm('rule row', (tester) async {
        await tester.pumpComponent(_paned('above\n\n---\n\nbelow'));
        // Rows: above, gap, rule, gap, below.
        expect(
          tester.terminalState.getTextAt(0, 2, length: _paneWidth.toInt()),
          '─' * _paneWidth.toInt(),
        );
        expect(
          tester.terminalState.getTextAt(0, 4, length: 5),
          'below',
        );
      }, size: _terminalSize);
    });

    test('display math centres within the pane at layout time', () async {
      await testNocterm('centred math', (tester) async {
        await tester.pumpComponent(_paned('\$\$\nx = y\n\$\$'));
        final row = tester.terminalState.getTextAt(
          0,
          0,
          length: _paneWidth.toInt(),
        );
        expect(row, contains('x = y'));
        // Centred by the block component (±1 for alignment rounding), not
        // left-flush and not via spaces baked into the grid text.
        expect(row!.indexOf('x = y'), inInclusiveRange(12, 13));
      }, size: _terminalSize);
    });

    test('a grid wider than the pane clips at the pane edge', () async {
      await testNocterm('clipped math', (tester) async {
        await tester.pumpComponent(
          _paned(r'$$\frac{a+b+c+d+e+f}{g}$$', width: 10),
        );
        // The grid is 39 columns; the pane is 10. The fraction bar fills
        // the pane and stops dead at its edge — clipped at paint, with the
        // grid text itself intact (the unit suite proves it unmutated).
        expect(
          tester.terminalState.getTextAt(0, 1, length: 10),
          '─' * 10,
        );
        final beyond = tester.terminalState.getTextAt(10, 1, length: 2);
        expect(beyond?.contains('─'), isNot(true));
      }, size: _terminalSize);
    });

    test('blocks sit one blank row apart, none after the last', () async {
      await testNocterm('block spacing', (tester) async {
        await tester.pumpComponent(_paned('one\n\n```dart\ntwo\n```\n\nthree'));
        expect(tester.terminalState.getTextAt(0, 0, length: 3), 'one');
        expect(tester.terminalState.getTextAt(0, 1, length: 3)?.trim(), '');
        expect(tester.terminalState.getTextAt(0, 2, length: 3), 'two');
        expect(tester.terminalState.getTextAt(0, 3, length: 3)?.trim(), '');
        expect(tester.terminalState.getTextAt(0, 4, length: 5), 'three');
        expect(tester.terminalState.getTextAt(0, 5, length: 5)?.trim(), '');
      }, size: _terminalSize);
    });

    test('a table renders through the view as its own block', () async {
      await testNocterm('table block', (tester) async {
        await tester.pumpComponent(_paned('| a | b |\n|---|---|\n| 1 | 2 |'));
        expect(tester.terminalState, containsText('┌'));
        expect(tester.terminalState, containsText('1'));
      }, size: _terminalSize);
    });

    test('code nested in a blockquote keeps a glyph-only backdrop', () async {
      await testNocterm('nested code', (tester) async {
        await tester.pumpComponent(_paned('> quote\n>\n> ```\n> xyz\n> ```'));
        expect(tester.terminalState, containsText('xyz'));
        // The nested block renders through the span path: its backdrop hugs
        // the glyphs instead of spanning the pane, and no row is padded.
        final xyzRow =
            [
              for (var y = 0; y < 8; y++) y,
            ].firstWhere(
              (y) =>
                  tester.terminalState
                      .getTextAt(0, y, length: _paneWidth.toInt())
                      ?.contains('xyz') ??
                  false,
            );
        expect(
          _backgroundAt(tester, _paneWidth.toInt() - 1, xyzRow),
          isNot(_backdrop),
        );
      }, size: _terminalSize);
    });
  });

  group('selection across streaming', () {
    test('a held selection survives the tail block changing type', () async {
      await testNocterm('streaming type flip', (tester) async {
        final harness = GlobalKey<_StreamHarnessState>();
        final changes = <String>[];
        await tester.pumpComponent(
          _StreamHarness(key: harness, onSelectionChanged: changes.add),
        );

        // Select 'first' on row 0 while the tail is still prose. Overshoot
        // past the word's end so the edge clamps to the line — the clamped
        // edge survives the delegate's replay identically.
        await tester.press(0, 0);
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.left,
            x: 7,
            y: 0,
            pressed: true,
            isMotion: true,
          ),
        );
        await tester.release(7, 0);
        expect(changes.length, greaterThan(0));
        final before = changes.last;
        expect(before, 'first');

        // The stream closes the fence: the tail block flips from a prose
        // paragraph to a code block — a different component type. The
        // prefix blocks must keep their render objects and the selection.
        harness.currentState!.grow('first\n\n```dart\nx = 1\n```');
        await tester.pump();

        expect(tester.terminalState, containsText('x = 1'));
        expect(changes.last, 'first');
      }, size: _terminalSize);
    });
  });
}

/// Streams a markdown document under a selection area, the chat's shape.
class _StreamHarness extends StatefulComponent {
  const _StreamHarness({required this.onSelectionChanged, super.key});

  final void Function(String) onSelectionChanged;

  @override
  State<_StreamHarness> createState() => _StreamHarnessState();
}

class _StreamHarnessState extends State<_StreamHarness> {
  String _data = 'first\n\n```dart';

  void grow(String value) => setState(() => _data = value);

  @override
  Component build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _paneWidth,
          child: SelectionArea(
            onSelectionChanged: component.onSelectionChanged,
            child: MarkdownView(
              _data,
              highlightTheme: _backedTheme,
              streaming: true,
            ),
          ),
        ),
        Expanded(child: const SizedBox()),
      ],
    );
  }
}
