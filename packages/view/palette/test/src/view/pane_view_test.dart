import 'dart:async';

import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:bestie_palette_view/src/view/pane_parts.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// Room for the 80×29 pane card with its top border on row 1 and its left
/// border on column 10.
const _wide = Size(100, 31);

/// Too narrow for the pane card, so it falls back to the command width.
const _narrow = Size(70, 31);

const AppThemeData _theme = appThemeDefault;

extension on NoctermTester {
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await pump();
    await pump();
  }

  Cell? cell(int x, int y) => terminalState.getCellAt(x, y);

  String text() => terminalState.getText();
}

/// Opens the palette on [commands] and activates the first one.
Future<void> openPane(
  NoctermTester tester, {
  required List<Command> commands,
  VoidCallback? onCloseRequested,
}) async {
  final open = StreamController<bool>.broadcast();
  addTearDown(open.close);
  await tester.pumpComponent(
    RepositoryProvider<CommandsUseCase>.value(
      value: catalogOf(commands),
      child: PaletteComponent(
        paletteOpenChanges: open.stream,
        onCloseRequested: onCloseRequested ?? () {},
        child: const TuiTheme(
          data: _theme,
          child: AppTheme(data: _theme, child: PalettePageView()),
        ),
      ),
    ),
  );
  open.add(true);
  await tester.settle();
  await tester.sendEnter();
  await tester.settle();
}

Command installedCommand(Pane pane) =>
    simpleCommand('models.installed', group: 'Local Models', pane: pane);

const _downloading = PaneSection(
  title: 'Downloading',
  count: 1,
  rows: [
    PaneRow(
      id: 'gpt',
      glyph: '◐',
      glyphTone: PaneTone.loading,
      label: 'GPT-OSS 20B',
      trailing: [PaneSpan('MXFP4 · 11.28 GB', PaneTone.muted)],
      detail: [
        PaneSpan('5.64 GB of 11.28 GB'),
        PaneSpan(' · ', PaneTone.subtle),
        PaneSpan('48.3 MB/s', PaneTone.loading),
      ],
      progress: PaneFraction(0.5),
    ),
  ],
);

const _quants = PaneSection(
  columns: [
    PaneColumn(title: 'Quant', width: 8),
    PaneColumn(title: 'Size', width: 7, align: PaneAlign.end),
    PaneColumn(title: 'Fit'),
  ],
  rows: [
    PaneRow(
      id: 'q4',
      label: 'Q4_K_M',
      cells: [
        [PaneSpan('4.97 GB')],
        [PaneSpan('fits', PaneTone.success)],
      ],
    ),
    PaneRow(id: 'in-use', label: 'In use', tint: PaneTint.primary),
  ],
);

const _ready = PaneStatus(
  glyph: '●',
  glyphTone: PaneTone.success,
  spans: [PaneSpan('Qwen 3 8B', PaneTone.emphasis)],
  trailing: [PaneSpan('24 GB free', PaneTone.success)],
);

void main() {
  late DemoPane pane;

  test('ends band text too long for the card in an ellipsis inside its '
      'border', () async {
    await testNocterm('pane band overflow', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane
        ..report(
          const PaneStatus(
            glyph: '⚠',
            glyphTone: PaneTone.warning,
            spans: [
              PaneSpan(
                'Another bestie window is using local models (pid 67872). '
                'Close it to use them here.',
                PaneTone.warning,
              ),
            ],
          ),
        )
        ..show(const PaneContent.empty());
      await tester.settle();

      final band = tester.text().split('\n')[4];
      expect(band, contains('⚠ Another bestie window'));
      expect(band, matches(RegExp(r'Close it to use …\s*│\s*$')));
      expect(band, isNot(contains('them here')));
      expect(tester.cell(89, 4)?.char, '│');
      expect(tester.cell(band.indexOf('…'), 4)?.style.color, _theme.warning);
    }, size: _wide);
  });

  test('ellipsizes long band text before the free memory, keeping the '
      'figure whole', () async {
    await testNocterm('pane band trailing overflow', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane
        ..report(
          const PaneStatus(
            glyph: '●',
            glyphTone: PaneTone.success,
            spans: [
              PaneSpan('通義千問 Qwen3 0.6B Instruct', PaneTone.emphasis),
              PaneSpan(
                '  ready · ctx 40,960 · 1 of 3 agent slots in use',
                PaneTone.muted,
              ),
            ],
            trailing: [PaneSpan('16 GB free', PaneTone.success)],
          ),
        )
        ..show(const PaneContent.empty());
      await tester.settle();

      final band = tester.text().split('\n')[4];
      expect(band, contains('● 通義千問 Qwen3 0.6B Instruct  ready'));
      expect(band, contains('…16 GB free'));
      expect(band, isNot(contains('in use')));
      expect(UnicodeWidth.stringWidth(band), 100);
    }, size: _wide);
  });

  setUp(() {
    pane = DemoPane(title: 'Installed', placeholder: 'Filter models…');
    addTearDown(pane.close);
  });

  test('draws the header band, groups, rows and progress in an 80-wide '
      'card', () async {
    await testNocterm('pane layout', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      expect(tester.text(), contains('Loading…'));

      pane
        ..show(const PaneContent([_downloading, _quants]))
        ..report(_ready);
      await tester.settle();

      // The card spans columns 10-89 and rows 1-29, its footer split off by
      // a rule joined to the border.
      expect(tester.cell(10, 1)?.char, '┌');
      expect(tester.cell(89, 1)?.char, '┐');
      expect(tester.cell(10, 27)?.char, '├');
      expect(tester.cell(50, 27)?.char, '─');
      expect(tester.cell(89, 27)?.char, '┤');
      expect(tester.cell(10, 29)?.char, '└');

      // Breadcrumb: secondary parts, the last one bold, muted separators,
      // all on the surface band.
      final root = tester.cell(12, 2);
      expect(root?.char, 'L');
      expect(root?.style.color, _theme.secondary);
      expect(root?.style.fontWeight, isNot(FontWeight.bold));
      expect(root?.style.backgroundColor, _theme.surface);
      expect(tester.cell(25, 2)?.char, '›');
      expect(tester.cell(25, 2)?.style.color, _theme.muted);
      final leaf = tester.cell(27, 2);
      expect(leaf?.char, 'I');
      expect(leaf?.style.color, _theme.secondary);
      expect(leaf?.style.fontWeight, FontWeight.bold);
      expect(tester.text(), contains('Filter models…'));

      // Status band: glyph, emphasised text, trailing text at the far end.
      expect(tester.cell(12, 4)?.char, '●');
      expect(tester.cell(12, 4)?.style.color, _theme.success);
      expect(tester.cell(14, 4)?.char, 'Q');
      expect(tester.cell(14, 4)?.style.color, _theme.onBackground);
      expect(tester.cell(14, 4)?.style.fontWeight, FontWeight.bold);
      expect(tester.cell(87, 4)?.char, 'e');
      expect(tester.cell(87, 4)?.style.color, _theme.success);
      expect(tester.cell(12, 5)?.style.backgroundColor, _theme.surface);

      // Group header with its count, straight under the band.
      final header = tester.cell(13, 6);
      expect(header?.char, 'D');
      expect(header?.style.color, _theme.muted);
      expect(header?.style.fontWeight, FontWeight.bold);
      expect(tester.cell(25, 6)?.char, '1');
      expect(tester.cell(27, 6)?.char, '─');
      expect(tester.cell(27, 6)?.style.color, _theme.outline);

      // First line: cursor, glyph, label, right-aligned trailing text.
      expect(tester.cell(11, 7)?.char, '▸');
      expect(tester.cell(11, 7)?.style.color, _theme.info);
      expect(tester.cell(13, 7)?.char, '◐');
      expect(tester.cell(13, 7)?.style.color, _theme.loading);
      final label = tester.cell(15, 7);
      expect(label?.char, 'G');
      expect(label?.style.color, _theme.onBackground);
      expect(label?.style.fontWeight, FontWeight.bold);
      expect(label?.style.backgroundColor, _theme.surfaceAccent);
      expect(tester.cell(86, 7)?.char, 'B');
      expect(tester.cell(86, 7)?.style.color, _theme.muted);

      // Detail line, indented past the glyph, in its own tones.
      expect(tester.cell(15, 8)?.char, '5');
      expect(tester.cell(15, 8)?.style.color, _theme.onSurface);
      expect(tester.cell(35, 8)?.char, '·');
      expect(tester.cell(35, 8)?.style.color, _theme.outline);
      expect(tester.cell(37, 8)?.char, '4');
      expect(tester.cell(37, 8)?.style.color, _theme.loading);

      // Progress line: half of a 46-cell bar, then the percentage.
      expect(tester.cell(15, 9)?.char, '█');
      expect(tester.cell(15, 9)?.style.color, _theme.loading);
      expect(tester.cell(37, 9)?.char, '█');
      expect(tester.cell(38, 9)?.char, '░');
      expect(tester.cell(38, 9)?.style.color, _theme.muted);
      expect(tester.cell(60, 9)?.char, '░');
      expect(tester.cell(63, 9)?.char, '5');
      expect(tester.cell(63, 9)?.style.color, _theme.muted);

      // A table section: muted column titles over aligned cells, no glyph
      // column, each row a single line.
      expect(tester.cell(13, 10)?.char, 'Q');
      expect(tester.cell(13, 10)?.style.color, _theme.muted);
      expect(tester.cell(26, 10)?.char, 'S');
      expect(tester.cell(32, 10)?.char, 'F');
      expect(tester.cell(13, 11)?.char, 'Q');
      expect(tester.cell(13, 11)?.style.color, _theme.onSurface);
      expect(tester.cell(23, 11)?.char, '4');
      expect(tester.cell(32, 11)?.char, 'f');
      expect(tester.cell(32, 11)?.style.color, _theme.success);

      // A primary-tinted row at rest.
      final tinted = tester.cell(13, 12);
      expect(tinted?.char, 'I');
      expect(tinted?.style.backgroundColor, _theme.primaryTint);

      // The scroll rail runs down the right edge of the list.
      expect(tester.cell(88, 7)?.char, isNot(' '));

      // The footer: standard hints when the row has no actions.
      expect(tester.cell(12, 28)?.char, '[');
      expect(tester.cell(12, 28)?.style.color, _theme.secondary);
      expect(tester.cell(18, 28)?.char, 'M');
      expect(tester.cell(18, 28)?.style.color, _theme.muted);
      expect(tester.text(), contains('[▴/▾] Move   [esc] Back'));
    }, size: _wide);
  });

  test('a selected primary-tinted row deepens its tint', () async {
    await testNocterm('pane tint', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(const PaneContent([_quants]));
      await tester.settle();
      await tester.sendArrowDown();
      await tester.settle();
      expect(
        tester.cell(13, 7)?.style.backgroundColor,
        _theme.primaryTintSelected,
      );
      expect(tester.cell(11, 7)?.char, '▸');
    }, size: _wide);
  });

  test('footer hints follow the selected row and who has the '
      'keyboard', () async {
    final runs = <String>[];
    await testNocterm('pane hints', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [
                  demoAction(
                    runs,
                    'Delete',
                    key: const CharKey('d'),
                    danger: true,
                  ),
                  demoAction(runs, 'Use'),
                ],
              ),
              const PaneRow(id: 'b', label: 'Beta'),
            ],
          ),
        ]),
      );
      await tester.settle();

      expect(
        tester.text(),
        contains('[↵] Use   [d] Delete   [▴/▾] Move   [/] Filter   [esc] Back'),
      );
      expect(tester.cell(16, 28)?.char, 'U');
      expect(tester.cell(16, 28)?.style.color, _theme.muted);
      expect(tester.cell(26, 28)?.char, 'D');
      expect(tester.cell(26, 28)?.style.color, _theme.error);

      // A row key runs its action instead of typing.
      await tester.enterText('d');
      await tester.settle();
      expect(runs, ['Delete']);
      expect(tester.text(), contains('Filter models…'));

      // Enter runs the primary action.
      await tester.sendEnter();
      await tester.settle();
      expect(runs, ['Delete', 'Use']);

      // `/` hands the keyboard to the query, and then letters type.
      await tester.enterText('/');
      await tester.settle();
      expect(tester.text(), contains('[↵] Use   [▴/▾] Move   [esc] Back'));
      await tester.enterText('d');
      await tester.settle();
      expect(runs, ['Delete', 'Use']);
      expect(tester.text(), contains('Nothing to show.'));

      // Moving gives the keyboard back to the list.
      await tester.sendBackspace();
      await tester.settle();
      await tester.sendArrowDown();
      await tester.sendArrowUp();
      await tester.settle();
      expect(tester.text(), contains('[d] Delete'));
    }, size: _wide);
  });

  test('typing an unclaimed letter filters the pane', () async {
    await testNocterm('pane filter', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(const PaneContent([_quants]));
      await tester.settle();
      await tester.enterText('q4');
      await tester.settle();
      expect(tester.text(), contains('Q4_K_M'));
      expect(tester.text(), isNot(contains('In use')));
    }, size: _wide);
  });

  test('a rejected action shows its reason in the header band', () async {
    await testNocterm('pane rejected', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [
                  demoAction([], 'Use', result: const PaneRejected('busy')),
                ],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      await tester.sendEnter();
      await tester.settle();
      expect(tester.cell(12, 4)?.char, '⚠');
      expect(tester.cell(12, 4)?.style.color, _theme.error);
      expect(tester.text(), contains('⚠ busy'));
    }, size: _wide);
  });

  test(
    'a pushed pane extends the breadcrumb, and Esc walks back out',
    () async {
      final inner = DemoPane(title: 'gemma-4', filter: PaneFilter.none);
      addTearDown(inner.close);
      var closeRequests = 0;
      await testNocterm('pane push', (tester) async {
        await openPane(
          tester,
          commands: [installedCommand(pane), simpleCommand('other.command')],
          onCloseRequested: () => closeRequests++,
        );
        pane.show(
          PaneContent([
            PaneSection(
              rows: [
                PaneRow(
                  id: 'a',
                  label: 'Alpha',
                  actions: [
                    demoAction([], 'Open', result: PanePush(inner)),
                  ],
                ),
              ],
            ),
          ]),
        );
        await tester.settle();
        await tester.enterText('al');
        await tester.settle();
        await tester.sendEnter();
        await tester.settle();
        inner
          ..report(
            const PaneStatus(
              glyph: '◑',
              glyphTone: PaneTone.loading,
              spans: [PaneSpan('Loading')],
              progress: PaneFraction(0.25, label: '25% · ctx 32,768'),
            ),
          )
          ..show(const PaneContent.empty());
        await tester.settle();

        expect(tester.text(), contains('Local Models › Installed › gemma-4'));
        // No query field: the status band sits right under the breadcrumb,
        // with a 28-cell bar after its text.
        expect(tester.cell(12, 3)?.char, '◑');
        expect(tester.cell(23, 3)?.char, '█');
        expect(tester.cell(30, 3)?.char, '░');
        expect(tester.text(), contains('25% · ctx 32,768'));
        expect(tester.text(), contains('Nothing to show.'));

        await tester.sendEscape();
        await tester.settle();
        expect(tester.text(), contains('Local Models › Installed'));
        expect(tester.text(), isNot(contains('gemma-4')));
        expect(tester.text(), contains(' al'), reason: 'the query comes back');

        await tester.sendEscape();
        await tester.settle();
        expect(tester.text(), contains('other.command'));
        expect(tester.cell(18, 1)?.char, '┌', reason: 'back to 64 wide');
        expect(closeRequests, 0);
      }, size: _wide);
    },
  );

  test('a band offers its actions on a line of their own, their keys run '
      'them, and the footer says where Esc goes', () async {
    final runs = <String>[];
    final failing = DemoPane(
      title: 'Installed',
      filter: PaneFilter.none,
      backLabel: 'Back to results',
    );
    addTearDown(failing.close);
    await testNocterm('pane band actions', (tester) async {
      await openPane(tester, commands: [installedCommand(failing)]);
      failing
        ..report(
          PaneStatus(
            glyph: '✕',
            glyphTone: PaneTone.danger,
            spans: const [PaneSpan("Couldn't load", PaneTone.danger)],
            actions: [demoAction(runs, 'Retry', key: const CharKey('r'))],
          ),
        )
        ..show(const PaneContent.empty());
      await tester.settle();

      expect(tester.cell(12, 3)?.char, '✕');
      expect(tester.cell(14, 4)?.char, '[');
      expect(tester.text(), contains('[r] Retry'));
      expect(tester.text(), contains('[▴/▾] Move   [esc] Back to results'));

      await tester.enterText('r');
      await tester.settle();
      expect(runs, ['Retry']);
    }, size: _wide);
  });

  test('rows can show work with no measurable end', () async {
    await testNocterm('pane indeterminate', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        const PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                glyph: '◉',
                label: 'Gemma 4 E2B',
                progress: PaneIndeterminate(label: 'Verifying checksum…'),
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      expect(tester.cell(15, 5)?.char, 'G');
      expect(tester.text(), contains('Verifying checksum…'));
      expect(tester.cell(17, 6)?.char, 'V');
      expect(tester.cell(17, 6)?.style.color, _theme.muted);
    }, size: _wide);
  });

  test('falls back to the command width on narrow terminals', () async {
    final plain = DemoPane();
    addTearDown(plain.close);
    await testNocterm('pane narrow', (tester) async {
      await openPane(tester, commands: [installedCommand(plain)]);
      plain.show(
        const PaneContent([
          PaneSection(
            columns: [
              PaneColumn(width: 6),
              PaneColumn(width: 9),
            ],
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                cells: [
                  [PaneSpan('notable', PaneTone.highlight)],
                ],
                trailing: [PaneSpan('end', PaneTone.warning)],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      expect(tester.cell(3, 1)?.char, '┌');
      expect(tester.cell(66, 1)?.char, '┐');
      expect(tester.cell(3, 27)?.char, '├');
      expect(tester.cell(66, 27)?.char, '┤');
      expect(tester.text(), contains('Filter…'));

      // Fixed-width columns leave the rest of the line before the trailing
      // text empty.
      expect(tester.cell(6, 5)?.char, 'A');
      expect(tester.cell(14, 5)?.char, 'n');
      expect(tester.cell(14, 5)?.style.color, _theme.highVisibility);
      expect(tester.cell(63, 5)?.char, 'd');
      expect(tester.cell(63, 5)?.style.color, _theme.warning);
      expect(tester.text(), contains('[esc] Back'));
    }, size: _narrow);
  });

  test('a search pane invites a search, and the mouse picks rows', () async {
    final searching = DemoPane(
      title: 'Download',
      filter: PaneFilter.search,
    );
    addTearDown(searching.close);
    final runs = <String>[];
    await testNocterm('pane search', (tester) async {
      await openPane(tester, commands: [installedCommand(searching)]);
      searching.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [demoAction(runs, 'First')],
              ),
              PaneRow(
                id: 'b',
                label: 'Beta',
                actions: [demoAction(runs, 'Second')],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      expect(tester.text(), contains('Search…'));

      await tester.tap(20, 6);
      await tester.settle();
      expect(tester.cell(11, 6)?.char, '▸');
      expect(runs, hasLength(0));

      await tester.tap(20, 6);
      await tester.tap(20, 6);
      await tester.settle();
      expect(runs, ['Second']);

      await tester.enterText('gem');
      await tester.settle();
      expect(searching.queries.last, 'gem');
    }, size: _wide);
  });

  test('a command opened from a pane collects in the wide card under the '
      'pane breadcrumb, then returns', () async {
    const confirm = ParamKey<bool>('confirm');
    var deleted = false;
    final delete = simpleCommand(
      'Delete Gemma',
      next: (soFar) => soFar.maybe(confirm) == null
          ? const ConfirmParam(key: confirm, label: 'Sure?', danger: true)
          : null,
      invoke: (_) async {
        deleted = true;
        return const CommandRan();
      },
    );
    await testNocterm('pane command', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [
                  demoAction(
                    [],
                    'Delete',
                    key: const CharKey('d'),
                    result: PaneOpenCommand(delete),
                  ),
                ],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      await tester.enterText('d');
      await tester.settle();
      expect(
        tester.text(),
        contains('Local Models › Installed › Delete Gemma › Sure?'),
      );
      expect(tester.cell(10, 1)?.char, '┌');

      await tester.sendEnter();
      await tester.settle();
      expect(deleted, isTrue);
      expect(tester.text(), contains('Alpha'));
      expect(tester.text(), contains('[d] Delete'));
    }, size: _wide);
  });

  test('a running action shows in the header band and its hints step '
      'aside', () async {
    final finish = Completer<PaneActionResult>();
    await testNocterm('pane pending', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [
                  PaneAction.primary(
                    label: 'Download',
                    invoke: () => finish.future,
                  ),
                ],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      expect(tester.text(), contains('[↵] Download'));

      await tester.sendEnter();
      await tester.settle();
      expect(tester.text(), contains('Download…'));
      expect(tester.text(), isNot(contains('[↵] Download')));
      expect(tester.text(), contains('[▴/▾] Move   [esc] Back'));

      finish.complete(const PaneStay());
      await tester.settle();
      expect(tester.text(), isNot(contains('Download…')));
      expect(tester.text(), contains('[↵] Download'));
    }, size: _wide);
  });

  test('coming back to a pane keeps its selection and the keyboard on the '
      'list', () async {
    final inner = DemoPane(title: 'gemma-4');
    addTearDown(inner.close);
    await testNocterm('pane return', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      PaneAction delete() => demoAction([], 'Delete', key: const CharKey('d'));
      pane.show(
        PaneContent([
          PaneSection(
            rows: [
              PaneRow(id: 'a', label: 'Alpha', actions: [delete()]),
              PaneRow(
                id: 'b',
                label: 'Alpine',
                actions: [
                  demoAction([], 'Open', result: PanePush(inner)),
                  delete(),
                ],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();
      await tester.enterText('al');
      await tester.settle();
      await tester.sendArrowDown();
      await tester.settle();
      await tester.sendEnter();
      await tester.settle();
      inner.show(const PaneContent.empty());
      await tester.settle();
      expect(tester.text(), contains('Local Models › Installed › gemma-4'));

      await tester.sendEscape();
      await tester.settle();
      final selected = tester
          .text()
          .split('\n')
          .firstWhere(
            (line) => line.contains('▸'),
          );
      expect(selected, contains('Alpine'));
      expect(tester.text(), contains('[/] Filter'));
    }, size: _wide);
  });

  test('notes sit above the rows in the gutter, unselectable', () async {
    final runs = <String>[];
    await testNocterm('pane notes', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        PaneContent([
          PaneSection(
            notes: const [
              PaneNote([PaneSpan('No local models yet.', PaneTone.emphasis)]),
              PaneNote.blank(),
              PaneNote([PaneSpan('Add a folder', PaneTone.muted)]),
            ],
            rows: [
              PaneRow(
                id: 'download',
                glyph: '↓',
                label: 'Download a model',
                actions: [demoAction(runs, 'Open')],
              ),
            ],
          ),
        ]),
      );
      await tester.settle();

      final note = tester.cell(13, 5);
      expect(note?.char, 'N');
      expect(note?.style.color, _theme.onBackground);
      expect(note?.style.fontWeight, FontWeight.bold);
      expect(tester.cell(12, 5)?.char, ' ');
      expect(tester.cell(13, 6)?.char, ' ', reason: 'a blank note');
      expect(tester.cell(13, 7)?.char, 'A');
      expect(tester.cell(13, 7)?.style.color, _theme.muted);

      // The first row under the notes holds the selection.
      expect(tester.cell(11, 8)?.char, '▸');
      expect(tester.cell(15, 8)?.char, 'D');
      await tester.sendEnter();
      await tester.settle();
      expect(runs, ['Open']);
    }, size: _wide);
  });

  test('a section of notes alone is shown, not the empty state', () async {
    await testNocterm('pane notes only', (tester) async {
      await openPane(tester, commands: [installedCommand(pane)]);
      pane.show(
        const PaneContent([
          PaneSection(
            title: 'Hugging Face',
            notes: [
              PaneNote([PaneSpan('No GGUF repos match.')]),
            ],
            rows: [],
          ),
        ]),
      );
      await tester.settle();
      expect(tester.text(), contains('No GGUF repos match.'));
      expect(tester.text(), isNot(contains('Nothing to show.')));
      expect(tester.cell(13, 6)?.char, 'N');
      expect(tester.cell(13, 6)?.style.color, _theme.onSurface);
    }, size: _wide);
  });

  test('progress captions fall back to the percentage done', () {
    expect(PaneProgressBar.captionOf(const PaneFraction(0.5)), '50%');
    expect(PaneProgressBar.captionOf(const PaneFraction(-1)), '0%');
    expect(
      PaneProgressBar.captionOf(const PaneFraction(0.5, label: 'half')),
      'half',
    );
    expect(PaneProgressBar.captionOf(const PaneIndeterminate()), '');
    expect(
      PaneProgressBar.captionOf(const PaneIndeterminate(label: 'Reading')),
      'Reading',
    );
  });
}
