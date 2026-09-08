import 'dart:async';

import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

import '../helpers.dart';

extension on NoctermTester {
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await pump();
    await pump();
  }
}

Future<void> pumpPalette(
  NoctermTester tester, {
  required CommandsUseCase commands,
  required Stream<bool> openChanges,
  required VoidCallback onCloseRequested,
}) async {
  await tester.pumpComponent(
    RepositoryProvider<CommandsUseCase>.value(
      value: commands,
      child: PaletteComponent(
        paletteOpenChanges: openChanges,
        onCloseRequested: onCloseRequested,
        child: const TuiTheme(
          data: appThemeDefault,
          child: AppTheme(
            data: appThemeDefault,
            child: PalettePageView(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('opens from the router stream, lists and gates commands', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    var closeRequests = 0;
    var invoked = false;
    final commands = catalogOf([
      simpleCommand(
        'tools.stopJobs',
        group: 'Tools',
        description: 'Cancel every job',
        invoke: (_) async {
          invoked = true;
          return const CommandRan();
        },
      ),
      simpleCommand(
        'models.download',
        group: 'Models',
        description: 'Fetch a model',
        availability: Stream.value(const Unavailable('offline')),
      ),
    ]);

    await testNocterm('palette browse', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () => closeRequests++,
      );
      expect(tester.terminalState.getText(), isNot(contains('tools.stopJobs')));

      open.add(true);
      await tester.settle();
      final text = tester.terminalState.getText();
      expect(text, contains('tools.stopJobs'));
      expect(text, contains('Cancel every job'));
      expect(text, contains('models.download'));
      expect(text, contains('offline'));
      expect(text, isNot(contains('Fetch a model')));

      // Filtering to garbage empties the list.
      await tester.enterText('qqqq');
      await tester.settle();
      expect(tester.terminalState.getText(), contains('No matching commands.'));

      for (var i = 0; i < 4; i++) {
        await tester.sendBackspace();
      }
      await tester.settle();

      // Enter runs the selected (available) command and requests close.
      await tester.sendEnter();
      await tester.settle();
      expect(invoked, isTrue);
      expect(closeRequests, 1);

      // Escape also requests close.
      await tester.sendEscape();
      await tester.settle();
      expect(closeRequests, 2);

      // The router hiding the palette lands back on the closed state.
      open.add(false);
      await tester.settle();
      expect(
        tester.terminalState.getText(),
        isNot(contains('tools.stopJobs')),
      );
    });
  });

  test('primary commands lead, unavailable commands sink', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    final commands = catalogOf([
      simpleCommand('z.normal', description: 'Plain'),
      simpleCommand(
        'y.gated',
        availability: Stream.value(const Unavailable('busy')),
      ),
      simpleCommand(
        'a.key',
        tier: CommandTier.primary,
        description: 'Key',
        glyph: '◆',
        shortcut: 'Ctrl+K',
      ),
      simpleCommand('b.key', tier: CommandTier.primary, description: 'Key'),
    ]);

    await testNocterm('palette ranking', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      final text = tester.terminalState.getText();
      expect(text.indexOf('a.key'), lessThan(text.indexOf('z.normal')));
      expect(text.indexOf('z.normal'), lessThan(text.indexOf('y.gated')));
      expect(text.indexOf('y.gated'), lessThan(text.indexOf('busy')));
      // Border row 0, padded header rows 1-3, a blank row 4, the group
      // header on row 5, then two-row commands from row 6: the selected
      // primary row, an
      // idle primary row, a plain row. Titles start after the two-cell
      // cursor gutter and the two-cell glyph column.
      final header = tester.terminalState.getCellAt(11, 5);
      expect(header?.char, 'T');
      expect(header?.style.color, appThemeDefault.muted);
      expect(tester.terminalState.getCellAt(16, 5)?.char, '─');
      final glyph = tester.terminalState.getCellAt(11, 6);
      expect(glyph?.char, '◆');
      expect(glyph?.style.color, appThemeDefault.primary);
      final selected = tester.terminalState.getCellAt(13, 6);
      expect(selected?.char, 'a');
      expect(selected?.style.color, appThemeDefault.onBackground);
      expect(
        selected?.style.backgroundColor,
        appThemeDefault.primaryTintSelected,
      );
      // The shortcut chip ends a cell short of the scrollbar rail, muted,
      // and no group tag rides along while the header names the group.
      final shortcut = tester.terminalState.getCellAt(68, 6);
      expect(shortcut?.char, 'K');
      expect(shortcut?.style.color, appThemeDefault.muted);
      expect(text.indexOf('Test'), text.lastIndexOf('Test'));
      final idle = tester.terminalState.getCellAt(13, 8);
      expect(idle?.style.color, appThemeDefault.primary);
      expect(idle?.style.backgroundColor, appThemeDefault.primaryTint);
      final plain = tester.terminalState.getCellAt(13, 10);
      expect(plain?.style.color, appThemeDefault.onSurface);
      expect(plain?.style.backgroundColor, isNot(appThemeDefault.primaryTint));
      expect(
        tester.terminalState.getCellAt(9, 1)?.style.backgroundColor,
        appThemeDefault.surface,
      );

      // Typing filters the list without disturbing it: the header still
      // opens the group and no group tag rides along on a row.
      await tester.enterText('key');
      await tester.settle();
      final filtered = tester.terminalState.getText();
      expect(filtered, isNot(contains('z.normal')));
      expect(tester.terminalState.getCellAt(11, 5)?.char, 'T');
      expect(tester.terminalState.getCellAt(13, 6)?.char, 'a');
      expect(filtered.indexOf('Test'), filtered.lastIndexOf('Test'));
      final chip = tester.terminalState.getCellAt(68, 6);
      expect(chip?.char, 'K');
      expect(chip?.style.color, appThemeDefault.muted);
    });
  });

  test('unavailable commands cannot be run and rejections surface', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    var gatedRan = false;
    final commands = catalogOf([
      simpleCommand(
        'a.rejects',
        invoke: (_) async => const CommandRejected('stale'),
      ),
      simpleCommand(
        'b.gated',
        availability: Stream.value(const Unavailable('busy')),
        invoke: (_) async {
          gatedRan = true;
          return const CommandRan();
        },
      ),
    ]);

    await testNocterm('palette gating', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      await tester.sendArrowDown();
      await tester.sendEnter();
      await tester.settle();
      expect(gatedRan, isFalse);

      await tester.sendArrowUp();
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('⚠ stale'));
    });
  });

  test('collects text and number params through pickers', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    const name = ParamKey<String>('name');
    const threads = ParamKey<int>('threads');
    const scale = ParamKey<double>('scale');
    const budget = ParamKey<num>('budget');
    const free = ParamKey<num>('free');
    Answers? received;
    final commands = catalogOf([
      simpleCommand(
        'models.rename',
        next: (soFar) {
          if (soFar.maybe(name) == null) {
            return TextParam(
              key: name,
              label: 'Name',
              hint: 'model name',
              validate: (value) => value.isEmpty ? 'required' : null,
            );
          }
          if (soFar.maybe(threads) == null) {
            return const NumberParam<int>(
              key: threads,
              label: 'Threads',
              min: 1,
              max: 32,
            );
          }
          if (soFar.maybe(scale) == null) {
            return const NumberParam<double>(
              key: scale,
              label: 'Scale',
              min: 0,
            );
          }
          if (soFar.maybe(budget) == null) {
            return const NumberParam<num>(key: budget, label: 'Budget', max: 9);
          }
          if (soFar.maybe(free) == null) {
            return const NumberParam<num>(key: free, label: 'Free');
          }
          return null;
        },
        invoke: (answers) async {
          received = answers;
          return const CommandRan();
        },
      ),
    ]);

    await testNocterm('palette text/number pickers', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      await tester.sendEnter();
      await tester.settle();
      var text = tester.terminalState.getText();
      expect(text, contains('models.rename › Name'));
      expect(text, contains('model name'));

      // Validation failure keeps the step and shows the problem.
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('⚠ required'));

      await tester.enterText('bessie');
      await tester.sendEnter();
      await tester.settle();
      text = tester.terminalState.getText();
      expect(text, contains('models.rename › Threads'));
      expect(text, contains('1 – 32'));

      // Esc steps back one param.
      await tester.sendEscape();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('models.rename › Name'));
      await tester.enterText('bessie');
      await tester.sendEnter();
      await tester.settle();

      await tester.enterText('8');
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('≥ 0'));

      await tester.enterText('1.5');
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('≤ 9'));

      await tester.enterText('3');
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('models.rename › Free'));

      await tester.enterText('7');
      await tester.sendEnter();
      await tester.settle();

      expect(received!.get(name), 'bessie');
      expect(received!.get(threads), 8);
      expect(received!.get(scale), 1.5);
      expect(received!.get(budget), 3);
      expect(received!.get(free), 7);
    });
  });

  test('collects dependent choice and multi-choice params', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    const model = ParamKey<String>('model');
    const files = ParamKey<List<String>>('files');
    Answers? received;
    final commands = catalogOf([
      simpleCommand(
        'models.download',
        next: (soFar) {
          final chosen = soFar.maybe(model);
          if (chosen == null) {
            return ChoiceParam<String>.fixed(
              key: model,
              label: 'Model',
              options: const [
                Option(value: 'llama', label: 'Llama', detail: 'Meta'),
                Option(value: 'mistral', label: 'Mistral'),
              ],
            );
          }
          if (soFar.maybe(files) == null) {
            return MultiChoiceParam<String>.fixed(
              key: files,
              label: 'Files for $chosen',
              min: 1,
              options: const [
                Option(value: 'a', label: 'a.md'),
                Option(value: 'b', label: 'b.md'),
              ],
            );
          }
          return null;
        },
        invoke: (answers) async {
          received = answers;
          return const CommandRan();
        },
      ),
    ]);

    await testNocterm('palette choice pickers', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      await tester.sendEnter();
      await tester.settle();
      var text = tester.terminalState.getText();
      expect(text, contains('models.download › Model'));
      expect(text, contains('Llama'));
      expect(text, contains('Meta'));
      expect(text, contains('Mistral'));

      await tester.enterText('mis');
      await tester.settle();
      expect(tester.terminalState.getText(), isNot(contains('Llama')));

      await tester.sendEnter();
      await tester.settle();
      text = tester.terminalState.getText();
      expect(text, contains('Files for mistral'));
      expect(text, contains('[ ]'));

      // Enter without any toggles violates min.
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('⚠ Pick at least 1'));

      await tester.sendKey(LogicalKey.space);
      await tester.settle();
      expect(tester.terminalState.getText(), contains('[x]'));

      await tester.sendEnter();
      await tester.settle();

      expect(received!.get(model), 'mistral');
      expect(received!.get(files), ['a']);
    });
  });

  test(
    'confirm picker renders, backs out on Esc, and fires on Enter',
    () async {
      final open = StreamController<bool>.broadcast();
      addTearDown(open.close);
      const confirm = ParamKey<bool>('confirm');
      var invoked = false;
      Answers? received;
      final commands = catalogOf([
        simpleCommand(
          'models.delete',
          group: 'Models',
          next: (soFar) => soFar.maybe(confirm) == null
              ? const ConfirmParam(
                  key: confirm,
                  label: 'Delete Bessie?',
                  danger: true,
                )
              : null,
          invoke: (answers) async {
            invoked = true;
            received = answers;
            return const CommandRan();
          },
        ),
      ]);

      await testNocterm('palette confirm picker', (tester) async {
        await pumpPalette(
          tester,
          commands: commands,
          openChanges: open.stream,
          onCloseRequested: () {},
        );
        open.add(true);
        await tester.settle();

        await tester.sendEnter();
        await tester.settle();
        final text = tester.terminalState.getText();
        expect(text, contains('models.delete › Delete Bessie?'));
        expect(text, contains('Enter to confirm'));

        // Esc backs out of the confirm without running the command.
        await tester.sendEscape();
        await tester.settle();
        expect(tester.terminalState.getText(), contains('models.delete'));
        expect(invoked, isFalse);

        // Enter confirms and collects true.
        await tester.sendEnter();
        await tester.settle();
        await tester.sendEnter();
        await tester.settle();
        expect(invoked, isTrue);
        expect(received!.get(confirm), isTrue);
      });
    },
  );

  test('mouse selects and activates command rows', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    var invokedSecond = false;
    final commands = catalogOf([
      simpleCommand('a.first'),
      simpleCommand(
        'b.second',
        invoke: (_) async {
          invokedSecond = true;
          return const CommandRan();
        },
      ),
    ]);

    await testNocterm('palette mouse rows', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      // The card fills the 24-row test terminal: the padded query header
      // takes rows 1-3, a blank row and the group header rows 4-5, then
      // two-row commands from row 6, so the second title sits on row 8.
      await tester.tap(20, 8);
      await tester.settle();
      expect(invokedSecond, isFalse);

      await tester.tap(20, 8);
      await tester.tap(20, 8);
      await tester.settle();
      expect(invokedSecond, isTrue);

      // Closing with a typed query clears the field for next open.
      await tester.enterText('abc');
      await tester.settle();
      open.add(false);
      await tester.settle();
      open.add(true);
      await tester.settle();
      expect(tester.terminalState.getText(), contains('a.first'));
    });
  });

  test(
    'a searchable choice invites a search and lists what it finds',
    () async {
      final open = StreamController<bool>.broadcast();
      addTearDown(open.close);
      const find = ParamKey<String>('find');
      final commands = catalogOf([
        simpleCommand(
          'c.search',
          next: (soFar) => soFar.maybe(find) == null
              ? ChoiceParam<String>.searchable(
                  key: find,
                  label: 'Find',
                  search: (query) => Stream.value(const [
                    Option(value: 'one', label: 'Found one'),
                  ]),
                )
              : null,
          invoke: (_) async => const CommandRan(),
        ),
      ]);

      await testNocterm('palette searchable choice', (tester) async {
        await pumpPalette(
          tester,
          commands: commands,
          openChanges: open.stream,
          onCloseRequested: () {},
        );
        open.add(true);
        await tester.settle();
        await tester.sendEnter();
        await tester.settle();

        expect(tester.terminalState, containsText('Search…'));
        expect(tester.terminalState, containsText('Found one'));
      });
    },
  );

  test('mouse and arrows drive the option pickers', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    const pick = ParamKey<String>('pick');
    const extras = ParamKey<List<String>>('extras');
    Answers? received;
    final commands = catalogOf([
      simpleCommand(
        'c.pickers',
        next: (soFar) {
          if (soFar.maybe(pick) == null) {
            return ChoiceParam<String>.fixed(
              key: pick,
              label: 'Pick',
              options: const [
                Option(value: 'one', label: 'One'),
                Option(value: 'two', label: 'Two'),
              ],
            );
          }
          if (soFar.maybe(extras) == null) {
            return MultiChoiceParam<String>.fixed(
              key: extras,
              label: 'Extras',
              options: const [
                Option(value: 'x', label: 'Ex'),
                Option(value: 'y', label: 'Why'),
              ],
            );
          }
          return null;
        },
        invoke: (answers) async {
          received = answers;
          return const CommandRan();
        },
      ),
    ]);

    await testNocterm('palette mouse pickers', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();
      await tester.sendEnter();
      await tester.settle();

      // Choice picker: padded header (title row 2, filter row 3) ends on
      // row 4; options are one row each from row 5.
      await tester.sendArrowDown();
      await tester.sendArrowUp();
      await tester.settle();
      await tester.tap(20, 6);
      await tester.tap(20, 6);
      await tester.settle();
      expect(tester.terminalState.getText(), contains('Extras'));

      // Multi picker: padded header (title row 2) ends on row 3; options
      // from row 4; double-click toggles.
      await tester.tap(20, 4);
      await tester.tap(20, 4);
      await tester.settle();
      expect(tester.terminalState.getText(), contains('[x]'));
      await tester.sendEnter();
      await tester.settle();

      expect(received!.get(pick), 'two');
      expect(received!.get(extras), ['x']);
    });
  });

  test('a choice param with no options reports it', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    const pick = ParamKey<String>('pick');
    final commands = catalogOf([
      simpleCommand(
        'd.empty',
        next: (soFar) => soFar.maybe(pick) == null
            ? ChoiceParam<String>(
                key: pick,
                label: 'Pick',
                filter: const NoFilter(),
                options: Stream.value(const []),
              )
            : null,
      ),
    ]);

    await testNocterm('palette empty options', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();
      await tester.sendEnter();
      await tester.settle();

      expect(tester.terminalState.getText(), contains('No options.'));

      // Enter has nothing to select; Esc returns to browsing.
      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('No options.'));
      await tester.sendEscape();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('d.empty'));
    });
  });

  test("shows a command's own words while it runs, when it has them", () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    final gate = Completer<CommandResult>();
    final commands = catalogOf([
      simpleCommand(
        'a.slow',
        running: 'Resetting. Please be patient.',
        invoke: (_) => gate.future,
      ),
    ]);

    await testNocterm('palette invoking with words', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      await tester.sendEnter();
      await tester.settle();
      expect(
        tester.terminalState.getText(),
        contains('Resetting. Please be patient.'),
      );
      expect(tester.terminalState.getText(), isNot(contains('Running…')));

      gate.complete(const CommandRan());
      await tester.settle();
      await tester.pumpComponent(const SizedBox());
    });
  });

  test('shows progress while a command runs', () async {
    final open = StreamController<bool>.broadcast();
    addTearDown(open.close);
    final gate = Completer<CommandResult>();
    final commands = catalogOf([
      simpleCommand('a.slow', invoke: (_) => gate.future),
    ]);

    await testNocterm('palette invoking', (tester) async {
      await pumpPalette(
        tester,
        commands: commands,
        openChanges: open.stream,
        onCloseRequested: () {},
      );
      open.add(true);
      await tester.settle();

      await tester.sendEnter();
      await tester.settle();
      expect(tester.terminalState.getText(), contains('Running…'));

      gate.complete(const CommandRan());
      await tester.settle();
      expect(tester.terminalState.getText(), isNot(contains('Running…')));

      // Swap the tree out to exercise unmount/dispose.
      await tester.pumpComponent(const SizedBox());
    });
  });
}
