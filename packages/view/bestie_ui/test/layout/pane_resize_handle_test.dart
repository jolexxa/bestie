import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _paneWidth = 20;
const _paneHeight = 5;
const int _handleColumn = _paneWidth - 1;
const int _centerRow = _paneHeight ~/ 2;

Component _themed(Component child, {AppThemeData theme = appThemeDefault}) =>
    AppTheme(
      data: theme,
      child: TuiTheme(data: theme, child: child),
    );

Component _handle(
  void Function(int) onResize, {
  AppThemeData theme = appThemeDefault,
}) => _themed(
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: _paneWidth.toDouble(),
        height: _paneHeight.toDouble(),
        child: PaneResizeHandle(
          onResize: onResize,
          child: const SizedBox.expand(child: Text('pane')),
        ),
      ),
      Expanded(child: const SizedBox()),
    ],
  ),
  theme: theme,
);

/// Swaps the theme without disturbing the subtree, so the handle keeps the
/// hover state it is being asked to repaint.
class _ThemeSwap extends StatefulComponent {
  const _ThemeSwap({super.key});

  @override
  State<_ThemeSwap> createState() => _ThemeSwapState();
}

class _ThemeSwapState extends State<_ThemeSwap> {
  AppThemeData _theme = appThemeDefault;

  void useHotCocoa() => setState(() => _theme = hotCocoa);

  @override
  Component build(BuildContext context) => _handle((_) {}, theme: _theme);
}

/// A drag step: the terminal reports held-button motion while a drag is live.
Future<void> _dragTo(NoctermTester tester, int x) => tester.sendMouseEvent(
  MouseEvent(
    button: MouseButton.left,
    x: x,
    y: 0,
    pressed: true,
    isMotion: true,
  ),
);

void main() {
  group('PaneResizeHandle', () {
    test('leaves the column alone until the pointer reaches it', () async {
      await testNocterm('idle handle', (tester) async {
        await tester.pumpComponent(_handle((_) {}));
        await tester.hover(0, 0);

        expect(
          tester.terminalState.getCellAt(_handleColumn, 0)?.char,
          isNot(handleGlyph),
        );
      });
    });

    test('paints the handle down the full height while hovered', () async {
      await testNocterm('hovered handle', (tester) async {
        await tester.pumpComponent(_handle((_) {}));
        await tester.hover(_handleColumn, 0);

        for (var y = 0; y < _paneHeight; y++) {
          final cell = tester.terminalState.getCellAt(_handleColumn, y);
          expect(cell?.char, y == _centerRow ? grabGlyph : handleGlyph);
          expect(cell?.style.color, appThemeDefault.info);
        }
      });
    });

    test('marks the middle of the bar with a grab junction', () async {
      await testNocterm('grab junction', (tester) async {
        await tester.pumpComponent(_handle((_) {}));

        expect(
          tester.terminalState.getCellAt(_handleColumn, _centerRow)?.char,
          isNot(grabGlyph),
        );

        await tester.hover(_handleColumn, 0);

        expect(
          tester.terminalState.getCellAt(_handleColumn, _centerRow)?.char,
          grabGlyph,
        );
      });
    });

    test('clears the highlight when the pointer leaves the column', () async {
      await testNocterm('exited handle', (tester) async {
        await tester.pumpComponent(_handle((_) {}));
        await tester.hover(_handleColumn, 0);
        await tester.hover(0, 0);

        expect(
          tester.terminalState.getCellAt(_handleColumn, 0)?.char,
          isNot(handleGlyph),
        );
      });
    });

    test('reports widths as the handle is dragged', () async {
      await testNocterm('dragging handle', (tester) async {
        final widths = <int>[];
        await tester.pumpComponent(_handle(widths.add));

        await tester.press(_handleColumn, 0);
        await _dragTo(tester, _handleColumn + 4);
        await _dragTo(tester, _handleColumn + 8);

        expect(widths, [_paneWidth + 4, _paneWidth + 8]);
      });
    });

    test('switches to the drag colour once a drag begins', () async {
      await testNocterm('drag colour', (tester) async {
        await tester.pumpComponent(_handle((_) {}));

        await tester.press(_handleColumn, 0);
        await _dragTo(tester, _handleColumn + 4);

        final cell = tester.terminalState.getCellAt(_handleColumn, 0);
        expect(cell?.char, handleGlyph);
        expect(cell?.style.color, appThemeDefault.highVisibility);
      });
    });

    test('ignores a press away from the handle column', () async {
      await testNocterm('press off handle', (tester) async {
        final widths = <int>[];
        await tester.pumpComponent(_handle(widths.add));

        await tester.press(0, 0);
        await _dragTo(tester, 8);

        expect(widths, <int>[]);
      });
    });

    test('stops reporting once the button is released', () async {
      await testNocterm('release ends drag', (tester) async {
        final widths = <int>[];
        await tester.pumpComponent(_handle(widths.add));

        await tester.press(_handleColumn, 0);
        await _dragTo(tester, _handleColumn + 4);
        await tester.release(_handleColumn + 4, 0);
        await _dragTo(tester, _handleColumn + 8);

        expect(widths, [_paneWidth + 4]);
      });
    });

    test('repaints a live highlight when the theme changes', () async {
      await testNocterm('recoloured handle', (tester) async {
        final key = GlobalKey<_ThemeSwapState>();
        await tester.pumpComponent(_ThemeSwap(key: key));
        await tester.hover(_handleColumn, 0);
        key.currentState!.useHotCocoa();
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(_handleColumn, 0)?.style.color,
          hotCocoa.info,
        );
      });
    });

    test('ignores wheel ticks over the handle column', () async {
      await testNocterm('wheel over handle', (tester) async {
        final widths = <int>[];
        await tester.pumpComponent(_handle(widths.add));

        // SGR wheel events parse as pressed=true; a handler that reads that
        // as a press would capture and resize on the next motion.
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: _handleColumn,
            y: 0,
            pressed: true,
          ),
        );
        await _dragTo(tester, _handleColumn + 4);

        expect(widths, <int>[]);
      });
    });

    test('keeps the highlight when a drag ends back on the column', () async {
      await testNocterm('release on handle', (tester) async {
        await tester.pumpComponent(_handle((_) {}));

        await tester.press(_handleColumn, 0);
        await tester.release(_handleColumn, 0);

        final cell = tester.terminalState.getCellAt(_handleColumn, 0);
        expect(cell?.char, handleGlyph);
        expect(cell?.style.color, appThemeDefault.info);
      });
    });
  });
}
