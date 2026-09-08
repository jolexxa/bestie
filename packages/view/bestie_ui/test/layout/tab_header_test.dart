import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

// Row 0 is the tab lid, row 1 the tabs.
//
// (left padding 2)
// one:   bar + " ONE " + bar     → cols 2..8    (width 7)
// (spacer 9)
// two:   bar + " TWO " + bar     → cols 10..16  (width 7)
// (spacer 17)
// three: bar + " THREE " + bar   → cols 18..26  (width 9)
const _tabs = ['ONE', 'TWO', 'THREE'];

const _capRow = 0;
const _tabRow = 1;

const _oneStartX = 2;
const _twoStartX = 10;

Component _header({
  required String selected,
  void Function(String tab)? onSelect,
}) => _themed(
  SizedBox(
    width: 60,
    height: 4,
    child: TabHeader<String>(
      tabs: _tabs,
      selected: selected,
      label: (tab) => tab,
      onSelect: onSelect,
    ),
  ),
);

void main() {
  group('TabHeader', () {
    test('renders every tab label', () async {
      await testNocterm('labels', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(tester.terminalState, containsText('ONE'));
        expect(tester.terminalState, containsText('TWO'));
        expect(tester.terminalState, containsText('THREE'));
      }, size: const Size(60, 4));
    });

    test('lids the active tab with a cornered top border', () async {
      await testNocterm('top-border', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(tester.terminalState.getCellAt(_oneStartX, _capRow)?.char, '┏');
        for (var x = _oneStartX + 1; x < _oneStartX + 6; x++) {
          expect(
            tester.terminalState.getCellAt(x, _capRow)?.char,
            '━',
            reason: 'column $x should be the active tab lid',
          );
        }
        expect(
          tester.terminalState.getCellAt(_oneStartX + 6, _capRow)?.char,
          '┓',
        );
      }, size: const Size(60, 4));
    });

    test('tops idle tabs with a low line rather than a lid', () async {
      await testNocterm('idle-low-line', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        for (var x = _twoStartX + 1; x < _twoStartX + 6; x++) {
          expect(
            tester.terminalState.getCellAt(x, _capRow)?.char,
            '▁',
            reason: 'column $x sits above an idle tab',
          );
        }
        for (var x = _twoStartX; x < _twoStartX + 7; x++) {
          expect(
            tester.terminalState.getCellAt(x, _capRow)?.style.backgroundColor,
            appThemeDefault.tabBarBackground,
            reason: 'an idle tab must not claim the lid row and grow taller',
          );
        }
        expect(
          tester.terminalState.getCellAt(_twoStartX + 1, _capRow)?.style.color,
          appThemeDefault.outlineVariant,
          reason: 'the low line matches the side bars it tops',
        );
      }, size: const Size(60, 4));
    });

    test('insets the idle line clear of the centred side bars', () async {
      await testNocterm('idle-line-inset', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // A full-width line would overhang the bars below its ends, which sit
        // centred in their cells.
        expect(tester.terminalState.getCellAt(_twoStartX, _capRow)?.char, ' ');
        expect(
          tester.terminalState.getCellAt(_twoStartX + 6, _capRow)?.char,
          ' ',
        );
      }, size: const Size(60, 4));
    });

    test('weighs idle tab sides to match the line across their top', () async {
      await testNocterm('idle-stroke-weight', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(
          tester.terminalState.getCellAt(_twoStartX + 1, _capRow)?.char,
          '▁',
        );
        expect(tester.terminalState.getCellAt(_twoStartX, _tabRow)?.char, '┛');
        expect(
          tester.terminalState.getCellAt(_twoStartX + 6, _tabRow)?.char,
          '┗',
        );
      }, size: const Size(60, 4));
    });

    test('turns idle tab walls out to join the baseline', () async {
      await testNocterm('idle-joins', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Feet, not plain verticals, so the wall and the rule read as one
        // drawing rather than two strokes that happen to meet.
        expect(tester.terminalState.getCellAt(_twoStartX, _tabRow)?.char, '┛');
        expect(
          tester.terminalState.getCellAt(_twoStartX + 6, _tabRow)?.char,
          '┗',
        );
        // The rule runs on past the idle tab on both sides.
        expect(
          tester.terminalState.getCellAt(_twoStartX - 1, _tabRow)?.char,
          '━',
        );
        expect(
          tester.terminalState.getCellAt(_twoStartX + 7, _tabRow)?.char,
          '━',
        );
      }, size: const Size(60, 4));
    });

    test('joins the active tab to the rule like any other', () async {
      await testNocterm('active-joins', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Feet turn away from the interior, so the active tab still opens into
        // the content below while its walls meet the rule on both sides. A
        // foot with no rule beside it would read as a dangling stub.
        expect(tester.terminalState.getCellAt(_oneStartX, _tabRow)?.char, '┛');
        expect(
          tester.terminalState.getCellAt(_oneStartX + 6, _tabRow)?.char,
          '┗',
        );
        expect(
          tester.terminalState.getCellAt(_oneStartX - 1, _tabRow)?.char,
          '━',
        );
        expect(
          tester.terminalState.getCellAt(_oneStartX + 7, _tabRow)?.char,
          '━',
        );
      }, size: const Size(60, 4));
    });

    test('leaves no unjoined stroke anywhere along the rule', () async {
      await testNocterm('no-dangling-strokes', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Whichever way a glyph reaches its cell edge, the neighbour it points
        // at has to reach back. A foot pointing into blank space is the defect
        // this guards: it promises a rule that is not there.
        const reachesRight = {'━', '┗'};
        const reachesLeft = {'━', '┛'};

        String at(int x) =>
            tester.terminalState.getCellAt(x, _tabRow)?.char ?? ' ';

        for (var x = 0; x < 60; x++) {
          if (reachesLeft.contains(at(x)) && x > 0) {
            expect(
              reachesRight.contains(at(x - 1)),
              isTrue,
              reason: '${at(x)} at column $x points left at ${at(x - 1)}',
            );
          }
          if (reachesRight.contains(at(x)) && x < 59) {
            expect(
              reachesLeft.contains(at(x + 1)),
              isTrue,
              reason: '${at(x)} at column $x points right at ${at(x + 1)}',
            );
          }
        }
      }, size: const Size(60, 4));
    });

    test('never lets an idle tab out-weigh the active one', () async {
      await testNocterm('active-stroke-weight', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Heavy rules on both, so the active tab reads at least as solid as
        // its neighbours rather than thinner.
        expect(tester.terminalState.getCellAt(_oneStartX, _capRow)?.char, '┏');
        expect(tester.terminalState.getCellAt(_oneStartX, _tabRow)?.char, '┛');
        expect(
          tester.terminalState.getCellAt(_oneStartX + 6, _tabRow)?.char,
          '┗',
        );
      }, size: const Size(60, 4));
    });

    test('draws the active lid in the same ink as the bars it joins', () async {
      await testNocterm('border-matches', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        final lid = tester.terminalState.getCellAt(_oneStartX, _capRow)?.style;
        final side = tester.terminalState.getCellAt(_oneStartX, _tabRow)?.style;
        expect(lid?.color, side?.color);
        expect(
          lid?.backgroundColor,
          side?.backgroundColor,
          reason: 'a lid on a different ground reads as a different color',
        );
      }, size: const Size(60, 4));
    });

    test(
      'draws the active edge in the same outline shade as idle tabs',
      () async {
        await testNocterm('outline-ink', (tester) async {
          await tester.pumpComponent(_header(selected: 'ONE'));
          expect(
            tester.terminalState.getCellAt(_oneStartX, _capRow)?.style.color,
            appThemeDefault.outlineVariant,
            reason:
                'the active tab reads by its lid and height, not a '
                'brighter edge',
          );
          expect(
            tester.terminalState.getCellAt(_twoStartX, _tabRow)?.style.color,
            appThemeDefault.outlineVariant,
            reason: 'idle edges sit in the same outline shade',
          );
        }, size: const Size(60, 4));
      },
    );

    test('keeps idle labels readable above their edges', () async {
      await testNocterm('idle-label-contrast', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // The label does not follow the edge down to the outline shade, which
        // would drop the text below comfortable reading contrast.
        expect(
          tester.terminalState.getCellAt(_twoStartX + 2, _tabRow)?.style.color,
          appThemeDefault.muted,
        );
      }, size: const Size(60, 4));
    });

    test(
      'keeps every tab edge in the outline shade regardless of selection',
      () async {
        await testNocterm('ink-follows-selection', (tester) async {
          await tester.pumpComponent(_header(selected: 'TWO'));
          expect(
            tester.terminalState.getCellAt(_oneStartX, _tabRow)?.style.color,
            appThemeDefault.outlineVariant,
          );
          expect(
            tester.terminalState.getCellAt(_twoStartX, _capRow)?.style.color,
            appThemeDefault.outlineVariant,
          );
        }, size: const Size(60, 4));
      },
    );

    test('fills the selected tab with the page background', () async {
      await testNocterm('selected-fill', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Every cell of the chip carries the fill, edge bars included, so the
        // tab reads as continuous with the content below.
        for (var x = _oneStartX; x < _oneStartX + 7; x++) {
          expect(
            tester.terminalState.getCellAt(x, _tabRow)?.style.backgroundColor,
            appThemeDefault.background,
            reason: 'column $x of the selected tab should be filled',
          );
        }
        expect(
          tester.terminalState.getCellAt(_oneStartX + 2, _tabRow)?.style.color,
          appThemeDefault.onBackground,
          reason: 'the active label reads as plain page ink',
        );
      }, size: const Size(60, 4));
    });

    test('carries the page background up through the lid row', () async {
      await testNocterm('cap-background', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(
          tester.terminalState
              .getCellAt(_oneStartX, _capRow)
              ?.style
              .backgroundColor,
          appThemeDefault.background,
        );
      }, size: const Size(60, 4));
    });

    test('leaves an unselected tab unfilled', () async {
      await testNocterm('unselected-fill', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(
          tester.terminalState
              .getCellAt(_twoStartX + 2, _tabRow)
              ?.style
              .backgroundColor,
          appThemeDefault.tabUnselectedBackground,
        );
      }, size: const Size(60, 4));
    });

    test('runs the baseline the full width of the strip', () async {
      await testNocterm('baseline-full-width', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Past the last tab (which ends at column 26) out to the last column.
        for (final x in [27, 40, 59]) {
          expect(
            tester.terminalState.getCellAt(x, _tabRow)?.char,
            '━',
            reason: 'column $x should carry the baseline',
          );
        }
      }, size: const Size(60, 4));
    });

    test('runs a baseline beside and between the tabs', () async {
      await testNocterm('baseline', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        // Column 0 of the leading inset and the gap at 17 between the two idle
        // tabs; 1 and 9 flank the active tab and are covered by its break.
        for (final x in [0, 17]) {
          expect(
            tester.terminalState.getCellAt(x, _tabRow)?.char,
            '━',
            reason: 'column $x should carry the baseline',
          );
          expect(
            tester.terminalState.getCellAt(x, _tabRow)?.style.color,
            appThemeDefault.outlineVariant,
            reason: 'the rule matches the idle feet that turn into it',
          );
        }
      }, size: const Size(60, 4));
    });

    test('keeps the baseline clear of the lid row', () async {
      await testNocterm('baseline-row', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        for (final x in [0, 1, 9, 17]) {
          expect(
            tester.terminalState.getCellAt(x, _capRow)?.char,
            ' ',
            reason: 'column $x of the lid row should stay empty',
          );
        }
      }, size: const Size(60, 4));
    });

    test('previews selection on hover in muted ink', () async {
      await testNocterm('hover-preview', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        expect(
          tester.terminalState.getCellAt(_twoStartX, _capRow)?.char,
          ' ',
          reason: 'the idle tab starts unlidded',
        );

        await tester.hover(_twoStartX + 2, _tabRow);

        // Same lidded shape as the active tab...
        expect(tester.terminalState.getCellAt(_twoStartX, _capRow)?.char, '┏');
        expect(
          tester.terminalState.getCellAt(_twoStartX + 6, _capRow)?.char,
          '┓',
        );
        // ...but muted rather than primary.
        expect(
          tester.terminalState.getCellAt(_twoStartX, _capRow)?.style.color,
          appThemeDefault.muted,
        );
        expect(
          tester.terminalState.getCellAt(_twoStartX + 2, _tabRow)?.style.color,
          appThemeDefault.muted,
        );
      }, size: const Size(60, 4));
    });

    test('leaves the hovered label unbolded', () async {
      await testNocterm('hover-weight', (tester) async {
        await tester.pumpComponent(_header(selected: 'ONE'));
        await tester.hover(_twoStartX + 2, _tabRow);

        final hoveredLabel = tester.terminalState
            .getCellAt(_twoStartX + 2, _tabRow)
            ?.style;
        final activeLabel = tester.terminalState
            .getCellAt(_oneStartX + 2, _tabRow)
            ?.style;
        expect(activeLabel?.fontWeight, FontWeight.bold);
        expect(hoveredLabel?.fontWeight, isNot(FontWeight.bold));
      }, size: const Size(60, 4));
    });

    test('reports the clicked tab', () async {
      await testNocterm('select', (tester) async {
        final selected = <String>[];
        await tester.pumpComponent(
          _header(selected: 'ONE', onSelect: selected.add),
        );
        await tester.tap(4, _tabRow); // inside " ONE "
        await tester.tap(12, _tabRow); // inside " TWO "
        expect(selected, ['ONE', 'TWO']);
      }, size: const Size(60, 4));
    });

    test('counts the lid row as part of the tab hit target', () async {
      await testNocterm('lid-clickable', (tester) async {
        final selected = <String>[];
        await tester.pumpComponent(
          _header(selected: 'ONE', onSelect: selected.add),
        );
        await tester.tap(12, _capRow); // the cap slot above " TWO "
        expect(selected, ['TWO']);
      }, size: const Size(60, 4));
    });

    test('sizes a tab by display width, not code units', () async {
      await testNocterm('wide-label', (tester) async {
        // "中ONE" is 4 code units but 5 cells wide, so the lid must span
        // bar + " 中ONE " + bar → 9 cells.
        await tester.pumpComponent(
          _themed(
            SizedBox(
              width: 60,
              height: 4,
              child: TabHeader<String>(
                tabs: const ['中ONE', 'TWO'],
                selected: '中ONE',
                label: (tab) => tab,
              ),
            ),
          ),
        );
        expect(tester.terminalState.getCellAt(_oneStartX, _capRow)?.char, '┏');
        expect(
          tester.terminalState.getCellAt(_oneStartX + 8, _capRow)?.char,
          '┓',
        );
        expect(tester.terminalState.getCellAt(_oneStartX, _tabRow)?.char, '┛');
        expect(
          tester.terminalState.getCellAt(_oneStartX + 8, _tabRow)?.char,
          '┗',
        );
      }, size: const Size(60, 4));
    });
  });
}
