import 'dart:async';

import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

import '../helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('PaletteLogic', () {
    test('starts closed and opens into browsing with the catalog', () async {
      final logic = PaletteLogic(
        commands: [simpleCommand('a.one'), simpleCommand('b.two')],
      )..start();
      expect(logic.value, isA<ClosedState>());
      expect(logic.value.open, isFalse);

      logic.input(const OpenPalette());
      final state = logic.value;
      expect(state, isA<BrowsingState>());
      expect(state.open, isTrue);
      expect(state.rows.map((r) => r.command.id), ['a.one', 'b.two']);
      expect(state.rows.first.availability, isA<Available>());

      logic.dispose();
    });

    test(
      'a searching param re-lists per query and drops stale answers',
      () async {
        const pick = ParamKey<String>('pick');
        final queries = <String>[];
        final answers = <String, StreamController<List<Option<String>>>>{};
        Stream<List<Option<String>>> search(String query) {
          queries.add(query);
          final controller = StreamController<List<Option<String>>>();
          addTearDown(controller.close);
          answers[query] = controller;
          return controller.stream;
        }

        final logic =
            PaletteLogic(
                commands: [
                  simpleCommand(
                    'c.search',
                    next: (soFar) => soFar.maybe(pick) == null
                        ? ChoiceParam<String>.searchable(
                            key: pick,
                            label: 'Pick',
                            search: search,
                          )
                        : null,
                  ),
                ],
              )
              ..start()
              ..input(const OpenPalette())
              ..input(const Activate());
        await settle();
        expect(queries, ['']);

        answers['']!.add(const [
          Option(value: 'a', label: 'Alpha'),
          Option(value: 'b', label: 'Beta'),
        ]);
        await settle();
        var state = logic.value as CollectingState;
        expect(state.visibleOptions.map((o) => o.option.label), [
          'Alpha',
          'Beta',
        ]);

        logic.input(const OptionQueryChanged('zzz'));
        expect(queries, ['', 'zzz']);

        answers['']!.add(const [Option(value: 'stale', label: 'Stale')]);
        answers['zzz']!.add(const [Option(value: 'b', label: 'Beta')]);
        await settle();
        state = logic.value as CollectingState;
        expect(state.visibleOptions.single.option.label, 'Beta');
        expect(state.visibleOptions.single.index, 0);

        logic.input(const SubmitChoice());
        await settle();
        expect(logic.value, isA<BrowsingState>());

        logic.dispose();
      },
    );

    test('availability streams gate rows live', () async {
      final gate = StreamController<Availability>.broadcast();
      addTearDown(gate.close);
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand('tools.stop', availability: gate.stream),
              ],
            )
            ..start()
            ..input(const OpenPalette());

      gate.add(const Unavailable('no active jobs'));
      await settle();
      final unavailable = logic.value.rows.single.availability;
      expect(unavailable, isA<Unavailable>());
      expect((unavailable as Unavailable).reason, 'no active jobs');

      gate.add(const Available());
      await settle();
      expect(logic.value.rows.single.availability, isA<Available>());

      logic
        ..stop()
        ..dispose();
    });

    test('stop cancels availability subscriptions', () async {
      final gate = StreamController<Availability>.broadcast();
      addTearDown(gate.close);
      final logic =
          PaletteLogic(
              commands: [simpleCommand('a.one', availability: gate.stream)],
            )
            ..start()
            ..input(const OpenPalette())
            ..stop();
      expect(gate.hasListener, isFalse);
      logic.dispose();
    });

    test('query filters and ranks; selection moves and clamps', () {
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand('models.download'),
                simpleCommand('tools.stop'),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const QueryChanged('stop'));
      expect(logic.value.query, 'stop');
      expect(logic.value.rows.first.command.id, 'tools.stop');

      logic.input(const QueryChanged('zzz'));
      expect(logic.value.rows, isEmpty);
      logic.input(const MoveSelection(1));
      expect(logic.value.selectedIndex, 0);

      logic
        ..input(const QueryChanged(''))
        ..input(const MoveSelection(1))
        ..input(const MoveSelection(5));
      expect(logic.value.selectedIndex, 1);
      logic.input(const MoveSelection(-9));
      expect(logic.value.selectedIndex, 0);

      logic.dispose();
    });

    test(
      'rows stay grouped, primary first and unavailable last within each '
      'group; a query filters them without disturbing the layout',
      () async {
        final logic =
            PaletteLogic(
                commands: [
                  simpleCommand(
                    'a.gated',
                    availability: Stream.value(const Unavailable('busy')),
                  ),
                  simpleCommand('b.plain'),
                  simpleCommand('d.other', group: 'Other'),
                  simpleCommand('c.key', tier: CommandTier.primary),
                ],
              )
              ..start()
              ..input(const OpenPalette());
        await settle();
        expect(logic.value.rows.map((row) => row.command.id), [
          'c.key',
          'b.plain',
          'a.gated',
          'd.other',
        ]);

        logic.input(const QueryChanged('test'));
        expect(logic.value.rows.map((row) => row.command.id), [
          'c.key',
          'b.plain',
          'a.gated',
        ]);

        logic.dispose();
      },
    );

    test('activate ignores empty lists and unavailable commands', () async {
      var invoked = false;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.gated',
                  availability: Stream.value(const Unavailable('nope')),
                  invoke: (_) async {
                    invoked = true;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const QueryChanged('zzz'))
            ..input(const Activate());
      expect(logic.value, isA<BrowsingState>());

      logic.input(const QueryChanged(''));
      await settle();
      logic.input(const Activate());
      expect(logic.value, isA<BrowsingState>());
      expect(invoked, isFalse);

      logic.dispose();
    });

    test('zero-param command invokes and requests close', () async {
      final outputs = <PaletteOutput>[];
      Answers? received;
      final logic = PaletteLogic(
        commands: [
          simpleCommand(
            'tools.stop',
            invoke: (answers) async {
              received = answers;
              return const CommandRan();
            },
          ),
        ],
      )..start();
      final binding = logic.bind()..onOutput<CloseRequested>(outputs.add);
      logic
        ..input(const OpenPalette())
        ..input(const Activate());
      await settle();
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.error, isNull);
      expect(received!.isEmpty, isTrue);
      expect(outputs, [isA<CloseRequested>()]);

      logic.input(const ClosePalette());
      expect(logic.value, isA<ClosedState>());

      binding.dispose();
      logic.dispose();
    });

    test('rejection surfaces its reason while browsing', () async {
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.rejects',
                  invoke: (_) async => const CommandRejected('stale'),
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      await settle();
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.error, 'stale');

      logic.input(const QueryChanged('a'));
      expect(logic.value.error, isNull);

      logic.dispose();
    });

    test('a throwing invoke becomes a rejection', () async {
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.throws',
                  invoke: (_) async => throw StateError('boom'),
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      await settle();
      expect(logic.value.error, contains('boom'));
      logic.dispose();
    });

    test('text param validates and collects', () async {
      const name = ParamKey<String>('name');
      Answers? received;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.text',
                  next: (soFar) => soFar.maybe(name) == null
                      ? TextParam(
                          key: name,
                          label: 'Name',
                          validate: (value) =>
                              value.isEmpty ? 'required' : null,
                        )
                      : null,
                  invoke: (answers) async {
                    received = answers;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      expect(logic.value, isA<CollectingState>());
      expect(logic.value.currentParam, isA<TextParam>());
      expect(logic.value.activeCommand!.id, 'a.text');

      logic.input(const SubmitText(''));
      expect(logic.value, isA<CollectingState>());
      expect(logic.value.editError, 'required');

      logic.input(const SubmitText('bessie'));
      await settle();
      expect(received!.get(name), 'bessie');
      logic.dispose();
    });

    test('confirm param collects true on submit, then invokes', () async {
      const confirm = ParamKey<bool>('confirm');
      Answers? received;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.delete',
                  next: (soFar) => soFar.maybe(confirm) == null
                      ? const ConfirmParam(
                          key: confirm,
                          label: 'Delete?',
                          danger: true,
                        )
                      : null,
                  invoke: (answers) async {
                    received = answers;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      expect(logic.value, isA<CollectingState>());
      expect(logic.value.currentParam, isA<ConfirmParam>());

      logic.input(const SubmitChoice());
      await settle();
      expect(received!.get(confirm), isTrue);
      logic.dispose();
    });

    test('confirm param backs out without invoking on Back', () async {
      const confirm = ParamKey<bool>('confirm');
      var invoked = false;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.delete',
                  next: (soFar) => soFar.maybe(confirm) == null
                      ? const ConfirmParam(key: confirm, label: 'Delete?')
                      : null,
                  invoke: (_) async {
                    invoked = true;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      expect(logic.value, isA<CollectingState>());

      logic.input(const Back());
      await settle();
      expect(logic.value, isA<BrowsingState>());
      expect(invoked, isFalse);
      logic.dispose();
    });

    test('number params parse, bound, and stay typed', () async {
      const threads = ParamKey<int>('threads');
      const scale = ParamKey<double>('scale');
      const anyNum = ParamKey<num>('anyNum');
      Answers? received;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.numbers',
                  next: (soFar) {
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
                      );
                    }
                    if (soFar.maybe(anyNum) == null) {
                      return const NumberParam<num>(key: anyNum, label: 'Any');
                    }
                    return null;
                  },
                  invoke: (answers) async {
                    received = answers;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate())
            ..input(const SubmitText('abc'));
      expect(logic.value.editError, 'Enter a number');
      logic.input(const SubmitText('0'));
      expect(logic.value.editError, 'Must be at least 1');
      logic.input(const SubmitText('99'));
      expect(logic.value.editError, 'Must be at most 32');
      logic.input(const SubmitText(' 8 '));
      expect(logic.value.editError, isNull);
      expect(logic.value.currentParam, isA<NumberParam<double>>());

      logic.input(const SubmitText('1.5'));
      expect(logic.value.currentParam, isA<NumberParam<num>>());

      logic.input(const SubmitText('3'));
      await settle();
      expect(received!.get(threads), 8);
      expect(received!.get(scale), 1.5);
      expect(received!.get(anyNum), 3);
      logic.dispose();
    });

    test('dependent choice flow: options, filter, select, back', () async {
      const model = ParamKey<String>('model');
      const quant = ParamKey<String>('quant');
      Answers? received;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'models.download',
                  next: (soFar) {
                    final chosen = soFar.maybe(model);
                    if (chosen == null) {
                      return ChoiceParam<String>.fixed(
                        key: model,
                        label: 'Model',
                        options: const [
                          Option(
                            value: 'llama',
                            label: 'Llama',
                            keywords: 'Custom endpoint Llama',
                          ),
                          Option(value: 'mistral', label: 'Mistral'),
                        ],
                      );
                    }
                    if (soFar.maybe(quant) == null) {
                      return ChoiceParam<String>.fixed(
                        key: quant,
                        label: 'Quant for $chosen',
                        options: const [
                          Option(value: 'q4', label: 'Q4_K_M'),
                          Option(value: 'q8', label: 'Q8_0'),
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
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      await settle();
      var state = logic.value as CollectingState;
      expect(state.visibleOptions.map((o) => o.option.label), [
        'Llama',
        'Mistral',
      ]);

      logic.input(const OptionQueryChanged('custom'));
      state = logic.value as CollectingState;
      expect(state.visibleOptions.single.option.label, 'Llama');
      expect(state.visibleOptions.single.index, 0);

      logic.input(const OptionQueryChanged('mis'));
      state = logic.value as CollectingState;
      expect(state.visibleOptions.single.option.label, 'Mistral');
      expect(state.visibleOptions.single.index, 1);

      logic.input(const SubmitChoice());
      await settle();
      state = logic.value as CollectingState;
      expect(state.currentParam!.label, 'Quant for mistral');
      expect(state.visibleOptions, hasLength(2));

      logic
        ..input(const MoveSelection(1))
        ..input(const Back());
      await settle();
      state = logic.value as CollectingState;
      expect(state.currentParam!.label, 'Model');
      expect(state.visibleOptions, hasLength(2));

      logic.input(const Back());
      expect(logic.value, isA<BrowsingState>());

      logic.input(const Activate());
      await settle();
      logic.input(const SubmitChoice());
      await settle();
      logic
        ..input(const MoveSelection(1))
        ..input(const SubmitChoice());
      await settle();
      expect(received!.get(model), 'llama');
      expect(received!.get(quant), 'q8');
      logic.dispose();
    });

    test('multi-choice toggles, enforces bounds, and stays typed', () async {
      const files = ParamKey<List<String>>('files');
      Answers? received;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.multi',
                  next: (soFar) => soFar.maybe(files) == null
                      ? MultiChoiceParam<String>.fixed(
                          key: files,
                          label: 'Files',
                          min: 1,
                          max: 2,
                          options: const [
                            Option(value: 'a', label: 'a.md'),
                            Option(value: 'b', label: 'b.md'),
                            Option(value: 'c', label: 'c.md'),
                          ],
                        )
                      : null,
                  invoke: (answers) async {
                    received = answers;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      await settle();

      logic.input(const SubmitChoice());
      expect(logic.value.editError, 'Pick at least 1');

      logic
        ..input(const ToggleOption())
        ..input(const MoveSelection(1))
        ..input(const ToggleOption())
        ..input(const MoveSelection(1))
        ..input(const ToggleOption())
        ..input(const SubmitChoice());
      expect(logic.value.editError, 'Pick at most 2');

      logic
        ..input(const ToggleOption())
        ..input(const SubmitChoice());
      await settle();
      expect(received!.get(files), ['a', 'b']);
      logic.dispose();
    });

    test('toggle and choice submissions no-op on mismatched params', () async {
      const name = ParamKey<String>('name');
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.text',
                  next: (soFar) => soFar.maybe(name) == null
                      ? const TextParam(key: name, label: 'Name')
                      : null,
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate())
            ..input(const ToggleOption())
            ..input(const SubmitChoice());
      expect(logic.value, isA<CollectingState>());
      expect(logic.value.editError, isNull);
      logic.dispose();
    });

    test('text submissions no-op on choice params', () async {
      const pick = ParamKey<String>('pick');
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.choice',
                  next: (soFar) => soFar.maybe(pick) == null
                      ? ChoiceParam<String>.fixed(
                          key: pick,
                          label: 'Pick',
                          options: const [Option(value: 'x', label: 'X')],
                        )
                      : null,
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate())
            ..input(const SubmitText('hello'));
      expect(logic.value, isA<CollectingState>());

      logic
        ..input(const OptionQueryChanged('zzz'))
        ..input(const MoveSelection(1))
        ..input(const ToggleOption())
        ..input(const SubmitChoice());
      expect(logic.value, isA<CollectingState>());
      logic.dispose();
    });

    test('loaded options clamp a selection that ran past the end', () async {
      const pick = ParamKey<String>('pick');
      final options = StreamController<List<Option<String>>>.broadcast();
      addTearDown(options.close);
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.choice',
                  next: (soFar) => soFar.maybe(pick) == null
                      ? ChoiceParam<String>(
                          key: pick,
                          label: 'Pick',
                          options: options.stream,
                        )
                      : null,
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      options.add(const [
        Option(value: 'a', label: 'A'),
        Option(value: 'b', label: 'B'),
        Option(value: 'c', label: 'C'),
      ]);
      await settle();
      logic.input(const MoveSelection(2));
      expect(logic.value.selectedIndex, 2);

      options.add(const [Option(value: 'a', label: 'A')]);
      await settle();
      expect(logic.value.selectedIndex, 0);
      logic.dispose();
    });

    test('closing mid-collection cancels the option watcher', () async {
      const pick = ParamKey<String>('pick');
      final options = StreamController<List<Option<String>>>.broadcast();
      addTearDown(options.close);
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.choice',
                  next: (soFar) => soFar.maybe(pick) == null
                      ? ChoiceParam<String>(
                          key: pick,
                          label: 'Pick',
                          options: options.stream,
                        )
                      : null,
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const QueryChanged('choice'))
            ..input(const Activate());
      expect(options.hasListener, isTrue);

      logic.input(const ClosePalette());
      expect(logic.value, isA<ClosedState>());
      expect(options.hasListener, isFalse);

      logic.input(const OpenPalette());
      expect(logic.value.query, '');
      logic.dispose();
    });

    test('backing into a flow that dried up invokes', () async {
      const first = ParamKey<String>('first');
      var extraStep = true;
      var invoked = false;
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'a.impure',
                  next: (soFar) {
                    if (!extraStep) return null;
                    return soFar.maybe(first) == null
                        ? ChoiceParam<String>.fixed(
                            key: first,
                            label: 'First',
                            options: const [Option(value: 'x', label: 'X')],
                          )
                        : ChoiceParam<String>.fixed(
                            key: const ParamKey('second'),
                            label: 'Second',
                            options: const [Option(value: 'y', label: 'Y')],
                          );
                  },
                  invoke: (_) async {
                    invoked = true;
                    return const CommandRan();
                  },
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const Activate());
      await settle();
      logic.input(const SubmitChoice());
      await settle();
      expect(logic.value.currentParam!.label, 'Second');

      extraStep = false;
      logic.input(const Back());
      await settle();
      expect(invoked, isTrue);
      logic.dispose();
    });

    test('cursor output fires as the selection moves', () {
      final moves = <int>[];
      final logic = PaletteLogic(
        commands: [simpleCommand('a.one'), simpleCommand('b.two')],
      )..start();
      final binding = logic.bind()
        ..onOutput<CursorMoved>((output) => moves.add(output.index));
      logic
        ..input(const OpenPalette())
        ..input(const MoveSelection(1))
        ..input(const MoveSelection(-1));
      expect(moves, [1, 0]);
      binding.dispose();
      logic.dispose();
    });

    test('request close emits without changing state', () {
      final outputs = <PaletteOutput>[];
      final logic = PaletteLogic(commands: [simpleCommand('a.one')])..start();
      final binding = logic.bind()..onOutput<CloseRequested>(outputs.add);
      logic
        ..input(const OpenPalette())
        ..input(const RequestClose());
      expect(logic.value, isA<BrowsingState>());
      expect(outputs, hasLength(1));
      binding.dispose();
      logic.dispose();
    });
  });
}
