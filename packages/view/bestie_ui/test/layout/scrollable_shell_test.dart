import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:test/test.dart';

Future<void> _drag(
  NoctermTester tester, {
  required int fromX,
  required int toX,
}) async {
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: fromX, y: 0, pressed: true),
  );
  await tester.sendMouseEvent(
    MouseEvent(
      button: MouseButton.left,
      x: toX,
      y: 0,
      pressed: true,
      isMotion: true,
      buttons: const {MouseButton.left},
    ),
  );
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: toX, y: 0, pressed: false),
  );
  await tester.pump();
}

Future<List<String>> _pumpShell(
  NoctermTester tester, {
  bool showRailWhenEmpty = true,
}) async {
  final completed = <String>[];
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpComponent(
    TuiTheme(
      data: appThemeDefault,
      child: AppTheme(
        data: appThemeDefault,
        child: ScrollableShell(
          controller: controller,
          enableSelection: true,
          onSelectionCompleted: completed.add,
          showRailWhenEmpty: showRailWhenEmpty,
          child: SingleChildScrollView(
            controller: controller,
            child: const Text('hello world'),
          ),
        ),
      ),
    ),
  );
  return completed;
}

void main() {
  test('reports a dragged selection', () async {
    await testNocterm('shell drag', size: const Size(20, 3), (tester) async {
      final completed = await _pumpShell(tester);
      await _drag(tester, fromX: 0, toX: 4);
      expect(completed, ['hell']);
    });
  });

  test('a click that selects nothing reports nothing', () async {
    await testNocterm('shell click', size: const Size(20, 3), (tester) async {
      final completed = await _pumpShell(tester);
      await tester.tap(2, 0);
      await tester.pump();
      expect(completed, isEmpty);
    });
  });

  test('draws the rail beside content that fits', () async {
    await testNocterm('shell rail', size: const Size(20, 3), (tester) async {
      await _pumpShell(tester);
      expect(tester.terminalState.getCellAt(19, 0)?.char, railGlyph);
    });
  });

  test('hides the rail beside content that fits when asked', () async {
    await testNocterm('shell no rail', size: const Size(20, 3), (tester) async {
      await _pumpShell(tester, showRailWhenEmpty: false);
      expect(tester.terminalState.getCellAt(19, 0)?.char, isNot(railGlyph));
    });
  });
}
