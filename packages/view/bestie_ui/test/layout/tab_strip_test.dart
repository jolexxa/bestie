import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

// details: bar + " Details " + bar         → cols 0..10   (width 11)
// (spacer 11)
// a:       bar + " sh a " + "× " + bar      → cols 12..21  (width 10)
// (spacer 22)
// b:       bar + " sh b " + "× " + bar      → cols 23..32  (width 10)
// (spacer 33)
// stub:    " + "                            → cols 34..36
const _tabs = [
  TabStripItem(id: 'details', label: 'Details', closable: false),
  TabStripItem(id: 'a', label: 'sh a'),
  TabStripItem(id: 'b', label: 'sh b'),
];

const _aCloseX = 19;
const _bCloseX = 30;
const _stubX = 35;

void _noop() {}

void main() {
  group('TabStrip', () {
    test('renders every tab label', () async {
      await testNocterm('labels', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Details'));
        expect(tester.terminalState, containsText('sh a'));
        expect(tester.terminalState, containsText('sh b'));
      }, size: const Size(60, 4));
    });

    test('shows the × on the active tab and hides it on idle tabs', () async {
      await testNocterm('active-close', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        // Active 'a' shows its ×; idle 'b' shows a blank slot.
        expect(tester.terminalState.getCellAt(_aCloseX, 0)?.char, '×');
        expect(tester.terminalState.getCellAt(_bCloseX, 0)?.char, ' ');
      }, size: const Size(60, 4));
    });

    test('reveals the × on hover of an idle tab', () async {
      await testNocterm('hover-close', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        expect(tester.terminalState.getCellAt(_bCloseX, 0)?.char, ' ');
        await tester.hover(25, 0);
        expect(tester.terminalState.getCellAt(_bCloseX, 0)?.char, '×');
      }, size: const Size(60, 4));
    });

    test('reports the clicked tab body', () async {
      await testNocterm('select', (tester) async {
        final selected = <String>[];
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(
                tabs: _tabs,
                activeId: 'a',
                onSelect: selected.add,
              ),
            ),
          ),
        );
        await tester.tap(5, 0); // inside " Details "
        await tester.tap(15, 0); // inside " sh a "
        expect(selected, ['details', 'a']);
      }, size: const Size(60, 4));
    });

    test('pressing a tab and dragging off it selects nothing', () async {
      await testNocterm('select-cancel', (tester) async {
        final selected = <String>[];
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(
                tabs: _tabs,
                activeId: 'a',
                onSelect: selected.add,
              ),
            ),
          ),
        );

        await tester.press(5, 0); // inside " Details "
        expect(selected, isEmpty, reason: 'the press alone selects nothing');

        // Drag onto a different tab and let go there.
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.left,
            x: 15,
            y: 0,
            pressed: true,
            isMotion: true,
          ),
        );
        await tester.release(15, 0);

        expect(
          selected,
          isEmpty,
          reason:
              'dragging off the pressed tab takes the click back, and the '
              'tab released over never owned the gesture',
        );
      }, size: const Size(60, 4));
    });

    test('hovering the × highlights it distinctly from the tab body', () async {
      await testNocterm('close-hover', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        // Hovering the body shows the × in the plain foreground…
        await tester.hover(15, 0);
        expect(
          tester.terminalState.getCellAt(_aCloseX, 0)?.style.color,
          isNot(appThemeDefault.error),
        );
        // …and hovering the × turns it into the danger color, with the
        // whole three-cell button tinted by the dimmed danger background.
        await tester.hover(_aCloseX, 0);
        expect(
          tester.terminalState.getCellAt(_aCloseX, 0)?.style.color,
          appThemeDefault.error,
        );
        for (final x in [_aCloseX - 1, _aCloseX, _aCloseX + 1]) {
          expect(
            tester.terminalState.getCellAt(x, 0)?.style.backgroundColor,
            appThemeDefault.errorHover,
          );
        }
      }, size: const Size(60, 4));
    });

    test('reports a close when a closable tab × is clicked', () async {
      await testNocterm('close', (tester) async {
        final closed = <String>[];
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a', onClose: closed.add),
            ),
          ),
        );
        await tester.hover(25, 0);
        await tester.tap(_bCloseX, 0);
        expect(closed, ['b']);
      }, size: const Size(60, 4));
    });

    test('shows the "+" stub and reports new-tab clicks', () async {
      await testNocterm('new', (tester) async {
        var created = 0;
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(
                tabs: _tabs,
                activeId: 'a',
                onNew: () => created++,
              ),
            ),
          ),
        );
        expect(tester.terminalState.getCellAt(_stubX, 0)?.char, '+');
        await tester.hover(_stubX, 0);
        await tester.tap(_stubX, 0);
        expect(created, 1);
      }, size: const Size(60, 4));
    });

    test(
      'paints idle tabs and the stub in muted, not the background',
      () async {
        await testNocterm('idle-color', (tester) async {
          await tester.pumpComponent(
            _themed(
              SizedBox(
                width: 60,
                height: 4,
                child: TabStrip(tabs: _tabs, activeId: 'a', onNew: () {}),
              ),
            ),
          );
          // 'b' is idle: bar at 23, label "sh b" starts at 25.
          expect(
            tester.terminalState.getCellAt(25, 0)?.style.color,
            appThemeDefault.muted,
          );
          expect(
            tester.terminalState.getCellAt(_stubX, 0)?.style.color,
            appThemeDefault.muted,
          );
        }, size: const Size(60, 4));
      },
    );

    test('hides the stub when onNew is null', () async {
      await testNocterm('no-new', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        expect(tester.terminalState.getCellAt(_stubX, 0)?.char, isNot('+'));
      }, size: const Size(60, 4));
    });

    test('is inert when all callbacks are null', () async {
      await testNocterm('inert', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 60,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        // No callbacks wired: taps resolve to nothing and must not throw.
        await tester.tap(15, 0);
        await tester.tap(_aCloseX, 0);
        expect(tester.terminalState, containsText('sh a'));
      }, size: const Size(60, 4));
    });

    test('measures wide characters in cells, not code units', () async {
      await testNocterm('wide', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 40,
              height: 4,
              child: TabStrip(
                tabs: [
                  TabStripItem(
                    id: 'details',
                    label: 'Details',
                    closable: false,
                  ),
                  TabStripItem(id: 'w', label: 'ビム'),
                ],
                activeId: 'w',
              ),
            ),
          ),
        );
        // bar + " ビム " (6 cells) + × slot + bar → 10 cells at x 12..21.
        // Code-unit math would size it 8 and land the bar at x 19.
        expect(tester.terminalState.getCellAt(21, 0)?.char, '│');
      }, size: const Size(40, 4));
    });

    test('clips a long label to 18 cells with an ellipsis', () async {
      await testNocterm('clip', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 40,
              height: 4,
              child: TabStrip(
                tabs: [
                  TabStripItem(id: 'long', label: 'a-very-long-session-title'),
                ],
                activeId: 'long',
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('a-very-long-sessi…'));
        expect(tester.terminalState, isNot(containsText('session-title')));
      }, size: const Size(40, 4));
    });

    test('wraps onto a second row when the tabs overflow', () async {
      await testNocterm('wrap', (tester) async {
        await tester.pumpComponent(
          _themed(
            const SizedBox(
              width: 20,
              height: 4,
              child: TabStrip(tabs: _tabs, activeId: 'a'),
            ),
          ),
        );
        // 11 + 1 + 10 = 22 > 20, so the third tab drops to the second tab
        // row, under the first row's rule slot.
        expect(tester.terminalState.getCellAt(0, 2)?.char, '│');
      }, size: const Size(20, 4));
    });

    test(
      'rules under the strip with joins and opens under the active tab',
      () async {
        await testNocterm('rule', (tester) async {
          await tester.pumpComponent(
            _themed(
              const Align(
                alignment: Alignment.topLeft,
                child: TabStrip(tabs: _tabs, activeId: 'a', onNew: _noop),
              ),
            ),
          );
          final cells = tester.terminalState;
          final rule = appThemeDefault.tabSelectedBorder;
          for (final x in [5, 11, 22, 26, 34, 36, 59]) {
            expect(cells.getCellAt(x, 1)?.char, '─', reason: 'rule at $x');
            expect(cells.getCellAt(x, 1)?.style.color, rule);
          }
          // Idle tabs' bars land on the rule.
          for (final x in [0, 10, 23, 32]) {
            expect(cells.getCellAt(x, 1)?.char, '┴', reason: 'join at $x');
            expect(
              cells.getCellAt(x, 1)?.style.color,
              appThemeDefault.tabUnselectedBorder,
            );
          }
          // The active tab's bars turn away and leave its floor open.
          expect(cells.getCellAt(12, 1)?.char, '┘');
          expect(cells.getCellAt(21, 1)?.char, '└');
          expect(cells.getCellAt(12, 1)?.style.color, rule);
          for (final x in [13, 16, 20]) {
            expect(cells.getCellAt(x, 1)?.char, ' ', reason: 'notch at $x');
            expect(
              cells.getCellAt(x, 1)?.style.backgroundColor,
              appThemeDefault.background,
            );
          }
          expect(cells.getCellAt(0, 2)?.char, isNot('─'));
        }, size: const Size(60, 4));
      },
    );
  });
}
