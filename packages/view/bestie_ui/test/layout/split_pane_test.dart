import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const int _terminalWidth = 80;

const double _narrowWidth = 30;

const double _defaultFraction = 2 / 3;

const int _minPaneWidth = 20;

const int _wideRightMinimum = 26;
const String _panesOpen = '\u2500\u25ba';
const String _panesClosed = '\u25c4\u2500';

final int _defaultBoundary = (_terminalWidth * _defaultFraction).round();
final int _narrowBoundary = (_narrowWidth / 2).round();

int _toggleColumnFor(int boundary) => boundary - 3;

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

Component _split() => _themed(
  const SplitPane(
    left: SizedBox.expand(child: Text('L')),
    right: SizedBox.expand(child: Text('R')),
  ),
);

Component _splitWithWideRight() => _themed(
  const SplitPane(
    left: SizedBox.expand(child: Text('L')),
    right: SizedBox.expand(child: Text('R')),
    minRightWidth: _wideRightMinimum,
  ),
);

String? _toggleGlyphsAt(NoctermTester tester, int boundary) =>
    tester.terminalState.getTextAt(_toggleColumnFor(boundary), 0, length: 2);

int _boundaryOf(NoctermTester tester) =>
    tester.terminalState.getTextAt(0, 0, length: _terminalWidth)!.indexOf('R');

Future<void> _dragBoundaryTo(
  NoctermTester tester, {
  required int from,
  required int to,
}) async {
  await tester.press(from - 1, 0);
  await tester.sendMouseEvent(
    MouseEvent(
      button: MouseButton.left,
      x: to - 1,
      y: 0,
      pressed: true,
      isMotion: true,
    ),
  );
  await tester.release(to - 1, 0);
}

void main() {
  group('SplitPane', () {
    test('fits only at or above the breakpoint', () {
      const breakpoint = SplitPane.breakpoint;

      expect(
        SplitPane.fits(const BoxConstraints(maxWidth: breakpoint)),
        isTrue,
      );
      expect(
        SplitPane.fits(const BoxConstraints(maxWidth: breakpoint - 1)),
        isFalse,
      );
    });

    test('splits two to one by default', () async {
      await testNocterm('default split', (tester) async {
        await tester.pumpComponent(_split());

        expect(_boundaryOf(tester), _defaultBoundary);
      });
    });

    test('widens the left pane when dragged right', () async {
      await testNocterm('drag right', (tester) async {
        await tester.pumpComponent(_split());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 60);

        expect(_boundaryOf(tester), 60);
      });
    });

    test('narrows the left pane when dragged left', () async {
      await testNocterm('drag left', (tester) async {
        await tester.pumpComponent(_split());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 31);

        expect(_boundaryOf(tester), 31);
      });
    });

    test('holds the left pane at its minimum width', () async {
      await testNocterm('clamp left', (tester) async {
        await tester.pumpComponent(_split());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 4);

        expect(_boundaryOf(tester), _minPaneWidth);
      });
    });

    test('holds the right pane at its minimum width', () async {
      await testNocterm('clamp right', (tester) async {
        await tester.pumpComponent(_split());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 78);

        expect(_boundaryOf(tester), _terminalWidth - _minPaneWidth);
      });
    });

    test('holds the right pane at a wider minimum when given one', () async {
      await testNocterm('clamp wide right', (tester) async {
        await tester.pumpComponent(_splitWithWideRight());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 78);

        expect(_boundaryOf(tester), _terminalWidth - _wideRightMinimum);
      });
    });

    test('floats the collapse toggle just clear of the divider', () async {
      await testNocterm('toggle position', (tester) async {
        await tester.pumpComponent(_split());

        expect(_toggleGlyphsAt(tester, _defaultBoundary), _panesOpen);
      });
    });

    test('lifts the toggle out of muted when hovered', () async {
      await testNocterm('toggle hover', (tester) async {
        await tester.pumpComponent(_split());
        final column = _toggleColumnFor(_defaultBoundary);

        expect(
          tester.terminalState.getCellAt(column, 0)?.style.color,
          appThemeDefault.muted,
        );

        await tester.hover(column, 0);

        expect(
          tester.terminalState.getCellAt(column, 0)?.style.color,
          appThemeDefault.primary,
        );
      });
    });

    test('hides the right pane when the toggle is clicked', () async {
      await testNocterm('collapse', (tester) async {
        await tester.pumpComponent(_split());
        await tester.tap(_toggleColumnFor(_defaultBoundary), 0);

        expect(_boundaryOf(tester), -1);
        expect(_toggleGlyphsAt(tester, _terminalWidth), _panesClosed);
      });
    });

    test('brings the right pane back at the width it left', () async {
      await testNocterm('expand', (tester) async {
        const dragged = 60;
        await tester.pumpComponent(_split());
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: dragged);
        await tester.tap(_toggleColumnFor(dragged), 0);
        await tester.tap(_toggleColumnFor(_terminalWidth), 0);

        expect(_boundaryOf(tester), dragged);
      });
    });

    test('cannot be resized while collapsed', () async {
      await testNocterm('collapsed drag', (tester) async {
        await tester.pumpComponent(_split());
        await tester.tap(_toggleColumnFor(_defaultBoundary), 0);
        await _dragBoundaryTo(tester, from: _terminalWidth, to: 40);

        expect(_boundaryOf(tester), -1);
      });
    });

    test('splits evenly when neither pane can meet its minimum', () async {
      await testNocterm('narrow split', (tester) async {
        await tester.pumpComponent(_split());

        expect(_boundaryOf(tester), _narrowBoundary);
      }, size: const Size(_narrowWidth, 5));
    });
  });
}
