import 'dart:convert';

import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide RenderScrollbar;
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

ts.Screen _screenWith(
  String input, {
  int rows = 4,
  int cols = 8,
  int scrollbackBytes = 0,
}) {
  final s = ts.Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);
  VtParser(sink: s).advance(utf8.encode(input));
  s.snapshot();
  return s;
}

/// The `lineN` label opening the viewport's top row.
String _topLineLabel(ts.Screen screen) {
  final b = StringBuffer();
  for (var c = 0; c < screen.cols; c++) {
    final ch = screen.viewportCellAt(0, c).char;
    if (ch == ' ' || ch.isEmpty) break;
    b.write(ch);
  }
  return b.toString();
}

Future<void> _drag(
  NoctermTester tester, {
  required (int, int) from,
  required (int, int) to,
}) async {
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: from.$1, y: from.$2, pressed: true),
  );
  await tester.sendMouseEvent(
    MouseEvent(
      button: MouseButton.left,
      x: to.$1,
      y: to.$2,
      pressed: true,
      isMotion: true,
      buttons: const {MouseButton.left},
    ),
  );
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: to.$1, y: to.$2, pressed: false),
  );
}

/// Relayouts one [TerminalView] in place.
class _HoldHarness extends StatefulComponent {
  const _HoldHarness({required this.screen, super.key});

  final ts.Screen screen;

  @override
  State<_HoldHarness> createState() => _HoldHarnessState();
}

class _HoldHarnessState extends State<_HoldHarness> {
  bool _unbounded = false;

  void goUnbounded() => setState(() => _unbounded = true);

  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 12,
          height: _unbounded ? null : 6,
          child: TerminalView(screen: component.screen),
        ),
        const Text('MARK'),
      ],
    );
  }
}

void main() {
  group('TerminalView', () {
    test('renders the screen', () async {
      await testNocterm('render', (tester) async {
        final screen = _screenWith('hi');
        await tester.pumpComponent(
          _themed(
            SizedBox(width: 12, height: 6, child: TerminalView(screen: screen)),
          ),
        );
        expect(tester.terminalState, containsText('hi'));
      }, size: const Size(12, 6));
    });

    test('reports the laid-out size when it differs from the screen', () async {
      await testNocterm('resize', (tester) async {
        final screen = _screenWith('hi', rows: 2, cols: 4);
        int? gotRows;
        int? gotCols;
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 12,
              height: 6,
              child: TerminalView(
                screen: screen,
                onResize: ({required rows, required cols}) {
                  gotRows = rows;
                  gotCols = cols;
                },
              ),
            ),
          ),
        );
        // 12x6 box: the scrollbar takes one column → grid is 11x6. The
        // owner frames the view; there is no padding of its own anymore.
        expect(gotRows, 6);
        expect(gotCols, 11);
      }, size: const Size(12, 6));
    });

    test('does not report resize when the size already matches', () async {
      await testNocterm('no-resize', (tester) async {
        final screen = _screenWith('hi', rows: 6, cols: 11);
        var reported = false;
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 12,
              height: 6,
              child: TerminalView(
                screen: screen,
                onResize: ({required rows, required cols}) => reported = true,
              ),
            ),
          ),
        );
        expect(reported, isFalse);
      }, size: const Size(12, 6));
    });

    test('forwards a non-empty completed selection', () async {
      await testNocterm('select', (tester) async {
        final screen = _screenWith('abc');
        String? copied;
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 12,
              height: 6,
              child: TerminalView(
                screen: screen,
                onSelectionCompleted: (text) => copied = text,
              ),
            ),
          ),
        );
        // Content sits at the view's own origin now — no padding.
        await _drag(tester, from: (0, 0), to: (2, 0));
        expect(copied, isNotNull);
        expect(copied, contains('a'));
      }, size: const Size(12, 6));
    });

    test('ignores an empty completed selection', () async {
      await testNocterm('empty-select', (tester) async {
        final screen = _screenWith('abc');
        var called = false;
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 12,
              height: 6,
              child: TerminalView(
                screen: screen,
                onSelectionCompleted: (_) => called = true,
              ),
            ),
          ),
        );
        // A click with no drag collapses to an empty selection.
        await tester.press(5, 3);
        await tester.release(5, 3);
        expect(called, isFalse);
      }, size: const Size(12, 6));
    });

    test('a fresh screen shows the bare rail with no grip', () async {
      await testNocterm('no-grip', (tester) async {
        final screen = _screenWith('hi', rows: 6, cols: 11);
        await tester.pumpComponent(
          _themed(
            SizedBox(width: 12, height: 6, child: TerminalView(screen: screen)),
          ),
        );
        // No scrollback yet: every rail cell is the light glyph — a grip
        // here would promise scrolling that cannot happen.
        for (var y = 0; y < 6; y++) {
          expect(tester.terminalState.getCellAt(11, y)?.char, railGlyph);
        }
      }, size: const Size(12, 6));
    });

    test('dragging the grip scrolls into scrollback', () async {
      await testNocterm('grip', (tester) async {
        final screen = _screenWith(
          List.generate(20, (i) => 'row$i').join('\r\n'),
          scrollbackBytes: 40 * 4096,
        );
        expect(screen.viewOffset, 0);
        await tester.pumpComponent(
          _themed(
            SizedBox(width: 14, height: 8, child: TerminalView(screen: screen)),
          ),
        );

        // Rail column = width - 1 = 13; the track spans the full height with
        // the grip near the bottom at offset 0. Grab it and drag up.
        await tester.press(13, 6);
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.left,
            x: 13,
            y: 2,
            pressed: true,
            isMotion: true,
          ),
        );
        expect(screen.viewOffset, greaterThan(0));
      }, size: const Size(14, 8));
    });

    test('resyncs the scrollbar when the grid self-scrolls', () async {
      await testNocterm('grid-scroll', (tester) async {
        final gridKey = GlobalKey();
        final screen = _screenWith(
          List.generate(20, (i) => 'row$i').join('\r\n'),
          scrollbackBytes: 40 * 4096,
        );
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 14,
              height: 8,
              child: TerminalView(screen: screen, gridKey: gridKey),
            ),
          ),
        );

        // A selection dragged past the edge makes the grid move the viewport
        // itself and fire onScrolled; drive that directly on its render object.
        final render =
            (gridKey.currentContext! as Element).renderObject!
                as RenderTerminalGrid;
        expect(render.scrollSelectionBy(-1), isTrue);
        expect(screen.viewOffset, greaterThan(0));
      }, size: const Size(14, 8));
    });

    test(
      'keeps the re-wrap anchored when a scrolled view is resized',
      () async {
        await testNocterm('reflow-anchor', (tester) async {
          // Long lines, so narrowing actually re-wraps them.
          final screen =
              _screenWith(
                  [
                    for (var i = 0; i < 40; i++) 'line$i ${'x' * 18}',
                  ].join('\r\n'),
                  rows: 6,
                  cols: 20,
                  scrollbackBytes: 200 * 4096,
                )
                // Each of these lines wraps to two rows at 20 columns, so an
                // even offset puts a line's *start* at the top of the viewport.
                ..setViewOffset(16);

          // Row hands its children loose constraints, so the box can
          // actually narrow — under the root's tight ones it could not.
          Component sized(double width) => _themed(
            Row(
              children: [
                SizedBox(
                  width: width,
                  height: 6,
                  child: TerminalView(
                    screen: screen,
                    onResize: screen.resize,
                  ),
                ),
                const Spacer(),
              ],
            ),
          );

          // The scrollbar takes one column, so the grid is width - 1: a
          // 21-wide box lays the grid out at the screen's 20.
          await tester.pumpComponent(sized(21));
          expect(screen.viewOffset, 16);
          final lineBefore = _topLineLabel(screen);

          // Narrowing re-wraps; terminal_screen pins the row that was at the
          // top of the viewport, which lands the view deeper in the taller
          // scrollback. Settle so the controller's deferred metrics
          // notification is delivered too.
          await tester.pumpComponent(sized(13));
          // A second frame delivers the controller's deferred metrics
          // notification, which is where a stale echo would land.
          await tester.pump();
          await tester.pump();

          expect(screen.cols, 12);
          // The same line is still the one at the top of the viewport, which
          // is the whole point of the re-anchor — and reaching it took a
          // different offset, since the re-wrap made every line taller.
          expect(_topLineLabel(screen), lineBefore);
          expect(
            screen.viewOffset,
            isNot(16),
            reason: 'a stale scrollbar echo must not undo the re-anchor',
          );
        }, size: const Size(23, 7));
      },
    );

    // A remount can hand the view an unbounded constraint for one layout pass
    // (a Column measures a non-flex child with infinite height). Pixels can't
    // map to a cell grid then, so it must hold the screen's size, not crash on
    // `Infinity.toInt()`.
    test('survives an unbounded constraint without resizing', () async {
      final resizes = <(int, int)>[];
      await testNocterm('unbounded', (tester) async {
        final screen = _screenWith('hi');
        await tester.pumpComponent(
          _themed(
            Column(
              children: [
                TerminalView(
                  screen: screen,
                  onResize: ({required rows, required cols}) =>
                      resizes.add((rows, cols)),
                ),
              ],
            ),
          ),
        );

        expect(tester.terminalState, containsText('hi'));
        // No pixel size to honor, so no resize is reported off a bogus one.
        expect(resizes, hasLength(0));
      }, size: const Size(12, 6));
    });

    // The real failure: a settled shell lays out at the pane size, then a
    // `changes`-driven relayout hands the same view an unbounded height. It
    // must reflow toward the pane box it already knows, not balloon to its
    // full 20-row screen and spill onto whatever sits below the pane.
    test('holds its last finite box across an unbounded relayout', () async {
      final harness = GlobalKey<_HoldHarnessState>();
      await testNocterm('hold-box', (tester) async {
        // A 20-row screen: ballooning to its full height would push anything
        // below the pane off the 12-row surface.
        final screen = _screenWith(
          [for (var i = 0; i < 20; i++) 'R$i\r\n'].join(),
          rows: 20,
          cols: 40,
        );
        await tester.pumpComponent(
          _themed(_HoldHarness(key: harness, screen: screen)),
        );

        // Bounded first: the view learns its 6-row pane box.
        expect(tester.terminalState, containsText('MARK'));

        // Now relayout the same view (state kept by its GlobalKey) under an
        // unbounded height — the `changes`-driven relayout the app hits.
        harness.currentState!.goUnbounded();
        await tester.pump();

        // Held its 6-row box: the marker sits just under it rather than being
        // shoved off-surface by a terminal grown to its full 20 rows.
        expect(tester.terminalState, containsText('MARK'));
      }, size: const Size(12, 12));
    });

    test('disposes its scroll controller when unmounted', () async {
      await testNocterm('dispose', (tester) async {
        final screen = _screenWith('hi');
        await tester.pumpComponent(
          _themed(
            SizedBox(width: 12, height: 6, child: TerminalView(screen: screen)),
          ),
        );
        // Swap the child out so the view unmounts and its dispose runs.
        await tester.pumpComponent(
          _themed(const SizedBox(width: 12, height: 6)),
        );
      }, size: const Size(12, 6));
    });
  });
}
