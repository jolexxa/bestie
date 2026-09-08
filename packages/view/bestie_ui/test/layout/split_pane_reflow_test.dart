import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const int _terminalWidth = 80;
const int _terminalHeight = 12;

/// Where the divider starts out: two thirds of the terminal, rounded.
final int _defaultBoundary = (_terminalWidth * 2 / 3).round();

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

/// The chat page's shape: a scrollable list of wrapping text rows on the
/// left of a [SplitPane]. Each row is one line in the wide pane and wraps
/// to more as the pane narrows, so dragging the divider reflows the list.
Component _chatShaped(ScrollController controller) => _themed(
  SplitPane(
    left: ScrollableListShell(
      controller: controller,
      itemCount: 30,
      enableSelection: true,
      itemBuilder: (context, index) =>
          Text('m$index ${'x' * 40}', style: const TextStyle()),
    ),
    right: const SizedBox.expand(child: Text('details')),
  ),
);

String _topLine(NoctermTester tester) =>
    (tester.terminalState.getTextAt(0, 0, length: 3) ?? '').trim();

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

/// A real drag: one motion event and one frame per column, the gesture that
/// compounds any per-step anchoring error into a visible slide.
Future<void> _dragBoundarySteps(
  NoctermTester tester, {
  required int from,
  required int to,
}) async {
  await tester.press(from - 1, 0);
  final step = to > from ? 1 : -1;
  for (var x = from + step; x != to + step; x += step) {
    await tester.sendMouseEvent(
      MouseEvent(
        button: MouseButton.left,
        x: x - 1,
        y: 0,
        pressed: true,
        isMotion: true,
      ),
    );
    await tester.pump();
  }
  await tester.release(to - 1, 0);
}

/// Sixty numbered four-column words: a message whose wrapped rows identify
/// exactly which slice of the text they carry.
final String _prose = List.generate(
  60,
  (index) => 'w${index.toString().padLeft(2, '0')}',
).join(' ');

/// A scrape-shaped wall: 120 words whose lengths change halfway through,
/// so wrap growth is non-uniform across the text.
final String _wall = List.generate(120, (index) {
  final word = 'v${index.toString().padLeft(3, '0')}';
  return index < 60 ? word : '${word}xxxxxx';
}).join(' ');

/// One giant unstructured item trailed by short filler rows, the details
/// pane's web-fetch shape.
Component _wallMessage(ScrollController controller) => _themed(
  SplitPane(
    left: ScrollableListShell(
      controller: controller,
      itemCount: 16,
      enableSelection: true,
      itemBuilder: (context, index) => index == 0
          ? Text(_wall, style: const TextStyle())
          : Text('m$index', style: const TextStyle()),
    ),
    right: const SizedBox.expand(child: Text('details')),
  ),
);

/// One long wrapping message trailed by short filler rows.
Component _tallMessage(ScrollController controller) => _themed(
  SplitPane(
    left: ScrollableListShell(
      controller: controller,
      itemCount: 16,
      enableSelection: true,
      itemBuilder: (context, index) => index == 0
          ? Text(_prose, style: const TextStyle())
          : Text('m$index', style: const TextStyle()),
    ),
    right: const SizedBox.expand(child: Text('details')),
  ),
);

/// The word index leading terminal row [y], or -1 when the row is not prose.
/// Wrapped rows may carry a leading space from the swallowed break.
int _leadingWord(NoctermTester tester, int y) {
  final text = tester.terminalState.getTextAt(0, y, length: 5) ?? '';
  final match = RegExp(r'^\s?w(\d\d)').firstMatch(text);
  return match == null ? -1 : int.parse(match.group(1)!);
}

void main() {
  group('SplitPane reflow', () {
    test('holds the scrolled-to row while the divider drags', () async {
      await testNocterm('mid-scroll drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_chatShaped(controller));

        controller.jumpTo(7);
        await tester.pump();
        expect(_topLine(tester), 'm7');

        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 30);
        await tester.pump();

        expect(_topLine(tester), 'm7');
        controller.dispose();
      }, size: const Size(80, 12));
    });

    test('holds the row back through a widening drag too', () async {
      await testNocterm('widen drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_chatShaped(controller));

        controller.jumpTo(7);
        await tester.pump();

        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 30);
        await tester.pump();
        await _dragBoundaryTo(tester, from: 30, to: _defaultBoundary);
        await tester.pump();

        expect(_topLine(tester), 'm7');
        expect(controller.offset, 7);
        controller.dispose();
      }, size: const Size(80, 12));
    });

    test('keeps the same words on top inside a wrapped message', () async {
      // The chat's real shape and the real gesture: the viewport top sits
      // mid-message, inside prose that re-wraps from five rows to nine as
      // the divider drags over one column at a time. The anchored words
      // must still be on the top row — exactly, not approximately: the
      // anchor holds a character offset, and characters don't slide.
      await testNocterm('mid-message drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_tallMessage(controller));

        controller.jumpTo(3);
        await tester.pump();
        final before = _leadingWord(tester, 0);
        expect(before, greaterThan(0));

        await _dragBoundarySteps(tester, from: _defaultBoundary, to: 30);
        await tester.pump();

        // Re-packing may pull an earlier word onto the top row, but the
        // anchored word itself must still be on it.
        final topRow = tester.terminalState.getTextAt(0, 0, length: 30) ?? '';
        expect(topRow, contains('w${before.toString().padLeft(2, '0')}'));
        controller.dispose();
      }, size: const Size(80, 12));
    });

    test('holds a wall of text exactly through a stepped drag', () async {
      // The details pane's field case: one item is a giant unstructured
      // scrape whose wrap growth is non-uniform. Deep inside it, a
      // column-by-column drag in and back out must keep the anchored words
      // on the top row both ways.
      await testNocterm('wall drag', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(_wallMessage(controller));

        controller.jumpTo(9);
        await tester.pump();
        final word = RegExp(r'v\d\d\d')
            .firstMatch(
              tester.terminalState.getTextAt(0, 0, length: 40) ?? '',
            )
            ?.group(0);
        expect(word, isNotNull);

        await _dragBoundarySteps(tester, from: _defaultBoundary, to: 30);
        await tester.pump();
        expect(
          tester.terminalState.getTextAt(0, 0, length: 40),
          contains(word),
        );

        await _dragBoundarySteps(tester, from: 30, to: _defaultBoundary);
        await tester.pump();
        expect(
          tester.terminalState.getTextAt(0, 0, length: 40),
          contains(word),
        );
        controller.dispose();
      }, size: const Size(80, 12));
    });

    test('keeps the tail pinned while dragging at the bottom', () async {
      await testNocterm('bottom drag', (tester) async {
        final controller = AutoScrollController();
        await tester.pumpComponent(_chatShaped(controller));

        controller.jumpTo(controller.maxScrollExtent);
        await tester.pump();

        // The bottom pin corrects within the drag's own frame — no
        // catch-up pump, no one-frame dance of the scrollbar.
        await _dragBoundaryTo(tester, from: _defaultBoundary, to: 30);
        await tester.pump();

        expect(controller.offset, controller.maxScrollExtent);
        expect(
          tester.terminalState.getTextAt(0, _terminalHeight - 1, length: 3),
          isNot('m29'),
        );
        expect(tester.terminalState, containsText('m29'));
        controller.dispose();
      }, size: const Size(80, 12));
    });
  });
}
