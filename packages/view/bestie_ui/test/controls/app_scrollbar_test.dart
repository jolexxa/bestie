import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide RenderScrollbar;
import 'package:test/test.dart';

const _trackHeight = 8;
const _paneWidth = 20;
const int _railColumn = _paneWidth - 1;

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

Component _fittingContent(
  ScrollController controller, {
  required bool showRailWhenEmpty,
}) => _themed(
  SizedBox(
    width: 20,
    height: 5,
    child: AppScrollbar(
      controller: controller,
      thumbVisibility: true,
      showRailWhenEmpty: showRailWhenEmpty,
      child: SingleChildScrollView(
        controller: controller,
        child: const Text('one line, nothing to scroll'),
      ),
    ),
  ),
);

Component _overflowingContent(
  ScrollController controller, {
  bool reverse = false,
}) => _themed(
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: _paneWidth.toDouble(),
        height: _trackHeight.toDouble(),
        child: AppScrollbar(
          controller: controller,
          thumbVisibility: true,
          child: ListView.builder(
            controller: controller,
            reverse: reverse,
            itemCount: 60,
            itemBuilder: (context, index) => Text('row $index'),
          ),
        ),
      ),
      Expanded(child: const SizedBox()),
    ],
  ),
);

/// A drag arrives as a motion event with the left button held.
Future<void> _dragMotion(NoctermTester tester, int y) => tester.sendMouseEvent(
  MouseEvent(
    button: MouseButton.left,
    x: _railColumn,
    y: y,
    pressed: true,
    isMotion: true,
  ),
);

/// Swaps every restylable property at once, so the render object's update
/// path runs with a changed value for each of them.
class _Restyle extends StatefulComponent {
  const _Restyle({required this.controller, super.key});

  final ScrollController controller;

  @override
  State<_Restyle> createState() => _RestyleState();
}

class _RestyleState extends State<_Restyle> {
  AppThemeData _theme = appThemeDefault;
  Color _trackColor = appThemeDefault.mutedAccent;
  Color _thumbColor = appThemeDefault.scrollGrip;
  double _thickness = 1;
  bool _thumbVisibility = true;
  bool _showRailWhenEmpty = true;

  void restyle() => setState(() {
    _theme = hotCocoa;
    _trackColor = hotCocoa.mutedAccent;
    _thumbColor = hotCocoa.scrollGrip;
    _thickness = 2;
    _thumbVisibility = false;
    _showRailWhenEmpty = false;
  });

  @override
  Component build(BuildContext context) => AppTheme(
    data: _theme,
    child: TuiTheme(
      data: _theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _paneWidth.toDouble(),
            height: _trackHeight.toDouble(),
            child: AppScrollbar(
              controller: component.controller,
              thumbVisibility: _thumbVisibility,
              showRailWhenEmpty: _showRailWhenEmpty,
              thickness: _thickness,
              trackColor: _trackColor,
              thumbColor: _thumbColor,
              child: ListView.builder(
                controller: component.controller,
                itemCount: 60,
                itemBuilder: (context, index) => Text('row $index'),
              ),
            ),
          ),
          Expanded(child: const SizedBox()),
        ],
      ),
    ),
  );
}

/// Swaps the scroll controller under a live scrollbar.
class _ControllerSwap extends StatefulComponent {
  const _ControllerSwap({required this.first, required this.second, super.key});

  final ScrollController first;
  final ScrollController second;

  @override
  State<_ControllerSwap> createState() => _ControllerSwapState();
}

class _ControllerSwapState extends State<_ControllerSwap> {
  late ScrollController _active = component.first;

  void swap() => setState(() => _active = component.second);

  @override
  Component build(BuildContext context) => _themed(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _paneWidth.toDouble(),
          height: _trackHeight.toDouble(),
          child: AppScrollbar(
            controller: _active,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _active,
              itemCount: 60,
              itemBuilder: (context, index) => Text('row $index'),
            ),
          ),
        ),
        Expanded(child: const SizedBox()),
      ],
    ),
  );
}

int _gripHeight(NoctermTester tester) {
  var cells = 0;
  for (var y = 0; y < _trackHeight; y++) {
    if (tester.terminalState.getCellAt(_railColumn, y)?.char == gripGlyph) {
      cells++;
    }
  }
  return cells;
}

void main() {
  group('AppScrollbar', () {
    test('draws the rail as a divider even when content fits', () async {
      await testNocterm('rail when empty', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(
          _fittingContent(controller, showRailWhenEmpty: true),
        );
        expect(tester.terminalState, containsText(railGlyph));
        controller.dispose();
      });
    });

    test('keeps the grip one size for the whole scroll', () async {
      await testNocterm('steady grip', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        final atTop = _gripHeight(tester);
        expect(atTop, greaterThan(0));

        final heights = <int>{atTop};
        final max = controller.maxScrollExtent;
        for (var step = 1; step <= 20; step++) {
          controller.jumpTo(max * step / 20);
          await tester.pump();
          heights.add(_gripHeight(tester));
        }

        expect(heights, {atTop});
        controller.dispose();
      });
    });

    test('walks the grip from the top of the rail to the bottom', () async {
      await testNocterm('grip travel', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        expect(tester.terminalState.getCellAt(_railColumn, 0)?.char, gripGlyph);

        controller.jumpTo(controller.maxScrollExtent);
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(_railColumn, _trackHeight - 1)?.char,
          gripGlyph,
        );
        expect(tester.terminalState.getCellAt(_railColumn, 0)?.char, railGlyph);
        controller.dispose();
      });
    });

    test('hides the rail entirely when content fits and opted out', () async {
      await testNocterm('no rail when empty', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(
          _fittingContent(controller, showRailWhenEmpty: false),
        );
        expect(tester.terminalState, isNot(containsText(railGlyph)));
        controller.dispose();
      });
    });
  });

  // Geometry below: 60 rows in an 8-cell viewport gives maxScrollExtent 52,
  // a 2-cell grip and 6 cells of grip travel, so pointer rows map to offsets
  // as row / 6 * 52. At offset 0 the grip covers rows 0-1.
  group('AppScrollbar grip interaction', () {
    test('dragging the grip scrolls proportionally', () async {
      await testNocterm('grip drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        await tester.press(_railColumn, 0);
        await _dragMotion(tester, 3);

        expect(controller.offset, controller.maxScrollExtent / 2);
        controller.dispose();
      });
    });

    test('release ends the drag', () async {
      await testNocterm('grip release', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        await tester.press(_railColumn, 0);
        await _dragMotion(tester, 3);
        await tester.release(_railColumn, 3);

        final offset = controller.offset;
        await _dragMotion(tester, 5);

        expect(controller.offset, offset);
        controller.dispose();
      });
    });

    test('pressing the rail off the grip does not scroll', () async {
      await testNocterm('rail press', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        await tester.press(_railColumn, 5);
        await _dragMotion(tester, 7);

        expect(controller.offset, 0);
        controller.dispose();
      });
    });

    test('drag direction inverts on a reversed scrollable', () async {
      await testNocterm('reversed drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(
          _overflowingContent(controller, reverse: true),
        );

        // Reversed at offset 0: the grip sits at the bottom, rows 6-7.
        await tester.press(_railColumn, 7);
        await _dragMotion(tester, 4);

        expect(controller.offset, controller.maxScrollExtent / 2);
        controller.dispose();
      });
    });

    test('hover and drag thicken and recolor the grip', () async {
      await testNocterm('grip colors', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));
        Cell? gripCell() => tester.terminalState.getCellAt(_railColumn, 0);

        expect(gripCell()?.char, gripGlyph);
        expect(gripCell()?.style.color, appThemeDefault.scrollGrip);

        await tester.hover(_railColumn, 0);
        expect(gripCell()?.char, gripHotGlyph);
        expect(gripCell()?.style.color, appThemeDefault.info);

        await tester.hover(_railColumn, 5);
        expect(gripCell()?.char, gripGlyph);
        expect(gripCell()?.style.color, appThemeDefault.scrollGrip);

        await tester.press(_railColumn, 0);
        expect(gripCell()?.char, gripHotGlyph);
        expect(gripCell()?.style.color, appThemeDefault.highVisibility);

        await tester.release(_railColumn, 0);
        expect(gripCell()?.char, gripHotGlyph);
        expect(gripCell()?.style.color, appThemeDefault.info);
        controller.dispose();
      });
    });

    test('cools the grip when the pointer leaves the rail', () async {
      await testNocterm('grip exit', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        await tester.hover(_railColumn, 0);
        expect(
          tester.terminalState.getCellAt(_railColumn, 0)?.char,
          gripHotGlyph,
        );

        // Off the rail entirely: the annotation drops from the hit test
        // result and the tracker's exit pass cools the grip.
        await tester.hover(5, 0);
        expect(tester.terminalState.getCellAt(_railColumn, 0)?.char, gripGlyph);
        controller.dispose();
      });
    });

    test('restyles when its properties change', () async {
      await testNocterm('restyle', (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<_RestyleState>();
        await tester.pumpComponent(_Restyle(controller: controller, key: key));

        expect(
          tester.terminalState.getCellAt(_railColumn, 0)?.style.color,
          appThemeDefault.scrollGrip,
        );

        key.currentState!.restyle();
        await tester.pump();

        expect(tester.terminalState, isNot(containsText(gripGlyph)));
        controller.dispose();
      });
    });

    test('follows a swapped controller', () async {
      await testNocterm('controller swap', (tester) async {
        final first = ScrollController();
        final second = ScrollController();
        final key = GlobalKey<_ControllerSwapState>();
        await tester.pumpComponent(
          _ControllerSwap(first: first, second: second, key: key),
        );

        key.currentState!.swap();
        await tester.pump();

        second.jumpTo(second.maxScrollExtent);
        await tester.pump();

        expect(
          tester.terminalState.getCellAt(_railColumn, _trackHeight - 1)?.char,
          gripGlyph,
        );
        first.dispose();
        second.dispose();
      });
    });

    test('a wheel tick over the grip does not start a drag', () async {
      await testNocterm('wheel over grip', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_overflowingContent(controller));

        // SGR wheel events parse as pressed=true; a handler that reads that
        // as a press would capture and pin the offset to the pointer row.
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: _railColumn,
            y: 0,
            pressed: true,
          ),
        );
        await _dragMotion(tester, 3);

        expect(controller.offset, 0);
        controller.dispose();
      });
    });
  });

  group('RenderScrollbar', () {
    test('lays out to nothing without a child and tracks attachment', () {
      final renderObject = RenderScrollbar(
        thumbVisibility: true,
        showRailWhenEmpty: true,
        thickness: 1,
        trackColor: appThemeDefault.mutedAccent,
        thumbColor: appThemeDefault.scrollGrip,
        hoverColor: appThemeDefault.info,
        dragColor: appThemeDefault.highVisibility,
      );

      expect(renderObject.controller, null);
      expect(renderObject.trackColor, appThemeDefault.mutedAccent);
      expect(renderObject.thumbColor, appThemeDefault.scrollGrip);
      expect(renderObject.hoverColor, appThemeDefault.info);
      expect(renderObject.dragColor, appThemeDefault.highVisibility);
      expect(renderObject.showRailWhenEmpty, true);

      renderObject.layout(
        const BoxConstraints(maxWidth: 4, maxHeight: 4),
      );
      expect(renderObject.size, Size.zero);

      final owner = PipelineOwner();
      renderObject.attach(owner);
      expect(renderObject.annotation!.validForMouseTracker, true);

      renderObject.detach();
      expect(renderObject.annotation!.validForMouseTracker, false);

      renderObject.dispose();
    });
  });
}
