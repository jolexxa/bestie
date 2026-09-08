import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const int _terminalWidth = 80;
const int _terminalHeight = 24;

// SplitPane opens at two thirds: left pane columns 0-52, so the column both
// the scrollbar rail and the resize handle live on is 52.
final int _defaultBoundary = (_terminalWidth * 2 / 3).round();
final int _sharedColumn = _defaultBoundary - 1;
const int _centerRow = _terminalHeight ~/ 2;

// 60 rows in a 24-cell viewport: maxScrollExtent 36, a 10-cell grip and 14
// cells of grip travel. At offset 0 the grip covers rows 0-9.
const int _offGripRow = 15;

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

Component _split(ScrollController controller) => _themed(
  SplitPane(
    left: AppScrollbar(
      controller: controller,
      thumbVisibility: true,
      child: ListView.builder(
        controller: controller,
        itemCount: 60,
        itemBuilder: (context, index) => Text('row $index'),
      ),
    ),
    right: const SizedBox.expand(child: Text('R')),
  ),
);

int _boundaryOf(NoctermTester tester) =>
    tester.terminalState.getTextAt(0, 0, length: _terminalWidth)!.indexOf('R');

/// A drag step: the terminal reports held-button motion while a drag is live.
Future<void> _motion(NoctermTester tester, int x, int y) =>
    tester.sendMouseEvent(
      MouseEvent(
        button: MouseButton.left,
        x: x,
        y: y,
        pressed: true,
        isMotion: true,
      ),
    );

void main() {
  group('SplitPane with a scrollable left pane', () {
    test('dragging the grip scrolls without resizing', () async {
      await testNocterm('grip drag in split', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_split(controller));

        await tester.press(_sharedColumn, 0);
        await _motion(tester, _sharedColumn, 7);
        await tester.release(_sharedColumn, 7);

        expect(controller.offset, controller.maxScrollExtent / 2);
        expect(_boundaryOf(tester), _defaultBoundary);
        controller.dispose();
      });
    });

    test('dragging the rail off the grip resizes without scrolling', () async {
      await testNocterm('rail drag in split', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_split(controller));

        await tester.press(_sharedColumn, _offGripRow);
        await _motion(tester, 40, _offGripRow);
        await tester.release(40, _offGripRow);

        expect(_boundaryOf(tester), 41);
        expect(controller.offset, 0);
        controller.dispose();
      });
    });

    test('the grip defers nothing while the handle drags across it', () async {
      await testNocterm('handle drag over grip rows', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_split(controller));

        // A captured resize drag passing through grip rows stays a resize:
        // capture bypasses hit testing, so the grip cannot steal it.
        await tester.press(_sharedColumn, _offGripRow);
        await _motion(tester, 45, 5);
        await tester.release(45, 5);

        expect(_boundaryOf(tester), 46);
        expect(controller.offset, 0);
        controller.dispose();
      });
    });

    test('hovering the grip suppresses the handle highlight', () async {
      await testNocterm('hover precedence', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_split(controller));

        Cell? cellAt(int y) => tester.terminalState.getCellAt(_sharedColumn, y);

        // Off the grip the handle highlights the whole column.
        await tester.hover(_sharedColumn, _offGripRow);
        expect(cellAt(_centerRow)?.char, grabGlyph);

        // Sliding onto the grip drops the handle from the hit test result,
        // so its highlight exits and the grip goes hot instead.
        await tester.hover(_sharedColumn, 5);
        expect(cellAt(_centerRow)?.char, isNot(grabGlyph));
        expect(cellAt(_offGripRow)?.char, railGlyph);
        expect(cellAt(5)?.char, gripHotGlyph);
        expect(cellAt(5)?.style.color, appThemeDefault.info);
        controller.dispose();
      });
    });
  });
}
