import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _list(ScrollController controller) => ListView.builder(
  controller: controller,
  itemCount: 40,
  itemBuilder: (_, index) => Text('item $index'),
);

void main() {
  test('pages by a fraction of the viewport and stops at the ends', () {
    return testNocterm('paging', size: const Size(20, 8), (tester) async {
      final controller = ViewportListScrollController();
      addTearDown(controller.dispose);
      await tester.pumpComponent(_list(controller));

      // An auto-scrolling list opens on its tail.
      expect(controller.offset, 32);

      controller.pageBy(0.25, up: true);
      await tester.pump();
      expect(controller.offset, 30);

      controller.pageBy(0.25, up: false);
      await tester.pump();
      expect(controller.offset, 32);

      controller.pageBy(0.25, up: false);
      await tester.pump();
      expect(controller.offset, 32);
    });
  });

  test('reports which items the viewport shows', () {
    return testNocterm('visibility', size: const Size(20, 8), (tester) async {
      final controller = ViewportListScrollController();
      addTearDown(controller.dispose);
      await tester.pumpComponent(_list(controller));

      // Viewport covers rows 32..39.
      expect(controller.firstVisibleIndex(40), 32);
      expect(controller.lastVisibleIndex(40), 39);
      expect(controller.isItemVisible(31), isFalse);
      expect(controller.isItemVisible(32), isTrue);
      expect(controller.isItemVisible(39), isTrue);
      expect(controller.isItemVisible(40), isFalse);
      expect(controller.isItemStartVisible(31), isFalse);
      expect(controller.isItemStartVisible(32), isTrue);
      expect(controller.isItemStartVisible(39), isTrue);

      controller.scrollToStart();
      await tester.pump();
      expect(controller.firstVisibleIndex(40), 0);
      expect(controller.lastVisibleIndex(40), 7);
      expect(controller.isItemStartVisible(8), isFalse);
    });
  });

  test('distinguishes a visible start from a visible tail', () {
    return testNocterm('tall item', size: const Size(20, 8), (tester) async {
      final controller = ViewportListScrollController();
      addTearDown(controller.dispose);
      await tester.pumpComponent(
        ListView.builder(
          controller: controller,
          itemCount: 2,
          itemBuilder: (_, index) => SizedBox(
            height: index == 0 ? 12 : 1,
            child: Text('item $index'),
          ),
        ),
      );

      // Viewport covers rows 5..12: the tall item's tail and the short item.
      expect(controller.offset, 5);
      expect(controller.isItemVisible(0), isTrue);
      expect(controller.isItemStartVisible(0), isFalse);
      expect(controller.isItemStartVisible(1), isTrue);

      controller.scrollToStart();
      await tester.pump();
      expect(controller.isItemStartVisible(0), isTrue);
      expect(controller.isItemVisible(1), isFalse);
      expect(controller.lastVisibleIndex(2), 0);
    });
  });

  test('reports nothing before a viewport attaches', () {
    final controller = ViewportListScrollController();
    addTearDown(controller.dispose);
    expect(controller.isItemVisible(0), isFalse);
    expect(controller.isItemStartVisible(0), isFalse);
    expect(controller.firstVisibleIndex(3), isNull);
    expect(controller.lastVisibleIndex(3), isNull);
  });
}
