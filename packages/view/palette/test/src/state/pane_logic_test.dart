import 'dart:async';

import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

final class MockPane extends Mock implements Pane {}

PaletteLogic openOn(Pane pane, {List<Command> also = const []}) =>
    PaletteLogic(
        commands: [
          simpleCommand('models.installed', group: 'Local Models', pane: pane),
          ...also,
        ],
      )
      ..start()
      ..input(const OpenPalette())
      ..input(const Activate());

ViewingPaneState paneOf(PaletteLogic logic) => logic.value as ViewingPaneState;

PaneContent listing(List<List<PaneRow>> sections) => PaneContent([
  for (var index = 0; index < sections.length; index++)
    PaneSection(title: 'Section $index', rows: sections[index]),
]);

void main() {
  group('PaletteLogic panes', () {
    late DemoPane pane;

    setUp(() {
      pane = DemoPane(title: 'Installed');
      addTearDown(pane.close);
    });

    test('a pane command opens its pane and follows its streams', () async {
      final logic = openOn(pane);
      var state = paneOf(logic);
      expect(state, isA<NavigatingPaneState>());
      expect(state.paneTrail, ['Local Models', 'Installed']);
      expect(state.pane, same(pane));
      expect(state.loading, isTrue);
      expect(state.visibleRows, isEmpty);
      expect(state.selectedRow, isNull);
      expect(state.status, isNull);
      expect(state.hasQuery, isTrue);
      expect(pane.queries, ['']);
      expect(pane.watched, isTrue);
      expect(pane.statusWatched, isTrue);

      pane
        ..show(
          listing([
            [const PaneRow(id: 'a', label: 'Alpha')],
            [const PaneRow(id: 'b', label: 'Beta')],
          ]),
        )
        ..report(const PaneStatus(spans: [PaneSpan('ready')]));
      await settle();
      state = paneOf(logic);
      expect(state.loading, isFalse);
      expect(state.visibleSections.map((section) => section.title), [
        'Section 0',
        'Section 1',
      ]);
      expect(state.visibleRows.map((row) => row.id), ['a', 'b']);
      expect(state.selectedRow?.id, 'a');
      expect(state.status?.spans.single.text, 'ready');

      pane.report(null);
      await settle();
      expect(paneOf(logic).status, isNull);

      logic.dispose();
    });

    test('a fuzzy pane filters its own rows and keeps the keyboard on '
        'the query', () async {
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            const PaneRow(id: 'q', label: 'Qwen 3 8B'),
            const PaneRow(id: 'g', label: 'Gemma 4', keywords: 'gemma google'),
          ],
          [const PaneRow(id: 'l', label: 'Llama 3.2')],
        ]),
      );
      await settle();
      logic.input(const MoveSelection(1));
      expect(paneOf(logic).selectedIndex, 1);

      logic.input(const QueryChanged('google'));
      final state = paneOf(logic);
      expect(state, isA<FilteringPaneState>());
      expect(state.query, 'google');
      expect(state.selectedIndex, 0);
      expect(state.visibleSections.single.title, 'Section 0');
      expect(state.visibleRows.single.id, 'g');
      expect(pane.queries, [''], reason: 'the palette filters by itself');

      logic.input(const QueryChanged(''));
      expect(paneOf(logic).visibleRows, hasLength(3));

      logic.dispose();
    });

    test('a searching pane re-lists per query and drops stale '
        'answers', () async {
      final searching = MockPane();
      final answers = <String, StreamController<PaneContent>>{};
      when(() => searching.title).thenReturn('Download');
      when(() => searching.filter).thenReturn(PaneFilter.search);
      when(() => searching.status).thenAnswer((_) => const Stream.empty());
      when(() => searching.content(any())).thenAnswer((invocation) {
        final controller = StreamController<PaneContent>();
        addTearDown(controller.close);
        answers[invocation.positionalArguments.single as String] = controller;
        return controller.stream;
      });

      final logic = openOn(searching)..input(const QueryChanged('gemma'));
      verifyInOrder([
        () => searching.content(''),
        () => searching.content('gemma'),
      ]);

      answers['']!.add(
        listing([
          [const PaneRow(id: 'stale', label: 'Stale')],
        ]),
      );
      answers['gemma']!.add(
        listing([
          [const PaneRow(id: 'g', label: 'unrelated words')],
        ]),
      );
      await settle();
      expect(
        paneOf(logic).visibleRows.single.id,
        'g',
        reason: 'the pane, not the palette, decides what matches',
      );

      logic.dispose();
    });

    test('a pane without a query never hands the keyboard to one', () async {
      final fixed = DemoPane(title: 'Quant', filter: PaneFilter.none);
      addTearDown(fixed.close);
      final logic = openOn(fixed);
      fixed.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Details', key: const CharKey('i')),
              ],
            ),
          ],
        ]),
      );
      await settle();
      final state = paneOf(logic);
      expect(state.hasQuery, isFalse);
      expect(state.claimsKey('/'), isFalse);
      expect(state.offersFilterKey, isFalse);

      logic.input(const PaneKeyPressed('/'));
      expect(logic.value, isA<NavigatingPaneState>());

      logic.dispose();
    });

    test('moving clamps to the rows, and new content keeps the selection '
        'in range', () async {
      final logic = openOn(pane);
      final moves = <int>[];
      final binding = logic.bind()
        ..onOutput<CursorMoved>((output) => moves.add(output.index));
      addTearDown(binding.dispose);

      logic.input(const MoveSelection(1));
      expect(paneOf(logic).selectedIndex, 0, reason: 'nothing to move over');

      pane.show(
        listing([
          [
            const PaneRow(id: 'a', label: 'Alpha'),
            const PaneRow(id: 'b', label: 'Beta'),
            const PaneRow(id: 'c', label: 'Gamma'),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const QueryChanged(''))
        ..input(const MoveSelection(5));
      expect(logic.value, isA<NavigatingPaneState>());
      expect(paneOf(logic).selectedRow?.id, 'c');
      logic.input(const MoveSelection(-9));
      expect(paneOf(logic).selectedRow?.id, 'a');
      expect(moves, [0, 2, 0]);

      logic.input(const MoveSelection(2));
      pane.show(
        listing([
          [const PaneRow(id: 'a', label: 'Alpha')],
        ]),
      );
      await settle();
      expect(paneOf(logic).selectedIndex, 0);

      logic.dispose();
    });

    test('Enter runs the primary action; rejections show until the next '
        'action or query', () async {
      final runs = <String>[];
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction(runs, 'Use', result: const PaneRejected('busy')),
              ],
            ),
            PaneRow(
              id: 'b',
              label: 'Beta',
              actions: [demoAction(runs, 'Stay')],
            ),
            PaneRow(
              id: 'c',
              label: 'Gamma',
              actions: [
                PaneAction.primary(
                  label: 'Break',
                  invoke: () async => throw StateError('disk gone'),
                ),
              ],
            ),
            const PaneRow(id: 'd', label: 'Inert'),
          ],
        ]),
      );
      await settle();

      logic.input(const Activate());
      await settle();
      expect(runs, ['Use']);
      expect(paneOf(logic).error, 'busy');

      logic.input(const QueryChanged('x'));
      expect(paneOf(logic).error, isNull);
      logic
        ..input(const QueryChanged(''))
        ..input(const Activate());
      await settle();
      expect(paneOf(logic).error, 'busy');

      logic
        ..input(const MoveSelection(1))
        ..input(const Activate());
      expect(paneOf(logic).error, isNull, reason: 'a new action clears it');
      await settle();
      expect(runs, ['Use', 'Use', 'Stay']);
      expect(logic.value, isA<NavigatingPaneState>());

      logic
        ..input(const MoveSelection(1))
        ..input(const Activate());
      await settle();
      expect(paneOf(logic).error, contains('disk gone'));

      logic
        ..input(const MoveSelection(1))
        ..input(const Activate());
      await settle();
      expect(paneOf(logic).error, contains('disk gone'));
      expect(runs, hasLength(3), reason: 'a row without actions does nothing');

      logic.dispose();
    });

    test('row keys run while the list has the keyboard, and only '
        'then', () async {
      final runs = <String>[];
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction(runs, 'Delete', key: const CharKey('d')),
                demoAction(runs, 'Use'),
              ],
            ),
          ],
        ]),
      );
      await settle();

      var state = paneOf(logic);
      expect(state.liveActions.map((action) => action.label), [
        'Delete',
        'Use',
      ]);
      expect(state.offersFilterKey, isTrue);
      expect(state.claimsKey('d'), isTrue);
      expect(state.claimsKey('/'), isTrue);
      expect(state.claimsKey('q'), isFalse);

      logic.input(const PaneKeyPressed('d'));
      await settle();
      expect(runs, ['Delete']);

      logic.input(const PaneKeyPressed('q'));
      expect(logic.value, isA<NavigatingPaneState>());

      logic.input(const PaneKeyPressed('/'));
      state = paneOf(logic);
      expect(state, isA<FilteringPaneState>());
      expect(state.liveActions.single.label, 'Use');
      expect(state.offersFilterKey, isFalse);
      expect(state.claimsKey('d'), isFalse);

      logic.input(const PaneKeyPressed('d'));
      await settle();
      expect(runs, ['Delete'], reason: 'typing goes to the query');

      logic.dispose();
    });

    test('band keys run while the list has the keyboard, unless the row '
        'has the same key', () async {
      final runs = <String>[];
      final logic = openOn(pane);
      pane
        ..show(
          listing([
            [
              PaneRow(
                id: 'a',
                label: 'Alpha',
                actions: [demoAction(runs, 'Resume', key: const CharKey('r'))],
              ),
              const PaneRow(id: 'b', label: 'Beta'),
            ],
          ]),
        )
        ..report(
          PaneStatus(
            spans: const [PaneSpan('Failed')],
            actions: [demoAction(runs, 'Retry', key: const CharKey('r'))],
          ),
        );
      await settle();

      logic.input(const PaneKeyPressed('r'));
      await settle();
      expect(runs, ['Resume']);

      logic.input(const MoveSelection(1));
      var state = paneOf(logic);
      expect(state.liveActions, isEmpty);
      expect(state.bandActions.single.label, 'Retry');
      expect(state.offersFilterKey, isTrue);
      expect(state.claimsKey('r'), isTrue);
      logic.input(const PaneKeyPressed('r'));
      await settle();
      expect(runs, ['Resume', 'Retry']);

      logic.input(const PaneKeyPressed('/'));
      state = paneOf(logic);
      expect(state.bandActions, isEmpty);
      expect(state.claimsKey('r'), isFalse);

      logic.dispose();
    });

    test('a pushed pane nests under the breadcrumb and Esc comes back to '
        'where the user was', () async {
      final inner = DemoPane(title: 'gemma-4', filter: PaneFilter.none);
      addTearDown(inner.close);
      final moves = <int>[];
      final logic = openOn(pane);
      final binding = logic.bind()
        ..onOutput<CursorMoved>((output) => moves.add(output.index));
      addTearDown(binding.dispose);
      pane.show(
        listing([
          [
            const PaneRow(id: 'a', label: 'Alpha'),
            PaneRow(
              id: 'b',
              label: 'Beta',
              actions: [
                demoAction([], 'Open', result: PanePush(inner)),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const QueryChanged('Beta'))
        ..input(const Activate());
      await settle();

      var state = paneOf(logic);
      expect(state, isA<NavigatingPaneState>());
      expect(state.pane, same(inner));
      expect(state.paneTrail, ['Local Models', 'Installed', 'gemma-4']);
      expect(state.loading, isTrue);
      expect(state.query, '');
      expect(inner.watched, isTrue);
      expect(pane.watched, isFalse);
      expect(moves.last, 0);

      logic.input(const Back());
      state = paneOf(logic);
      expect(state.pane, same(pane));
      expect(state.query, 'Beta');
      expect(state.selectedRow?.id, 'b');
      expect(state.loading, isFalse, reason: 'the last listing stays');
      expect(inner.watched, isFalse);
      expect(pane.watched, isTrue);
      expect(pane.queries, ['', ''], reason: 'listened to again');

      logic.input(const Back());
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.paneTrail, isEmpty);
      expect(pane.watched, isFalse);
      expect(pane.statusWatched, isFalse);

      logic.dispose();
    });

    test('an action that pops goes back to the pane underneath, and from '
        'the only pane back to the commands', () async {
      final inner = DemoPane(title: 'Delete Gemma', filter: PaneFilter.none);
      addTearDown(inner.close);
      var closeRequests = 0;
      final logic = openOn(pane);
      final binding = logic.bind()
        ..onOutput<CloseRequested>((_) => closeRequests++);
      addTearDown(binding.dispose);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Open', result: PanePush(inner)),
                demoAction(
                  [],
                  'Leave',
                  key: const CharKey('l'),
                  result: const PanePop(),
                ),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      expect(paneOf(logic).pane, same(inner));

      final deletes = <String>[];
      inner.show(
        listing([
          [
            PaneRow(
              id: 'confirm',
              label: 'Delete',
              actions: [
                demoAction(deletes, 'Delete', result: const PanePop()),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      expect(deletes, ['Delete']);
      final state = paneOf(logic);
      expect(state, isA<NavigatingPaneState>());
      expect(state.pane, same(pane));
      expect(state.paneTrail, ['Local Models', 'Installed']);
      expect(inner.watched, isFalse);
      expect(pane.watched, isTrue);

      logic.input(const PaneKeyPressed('l'));
      await settle();
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.paneTrail, isEmpty);
      expect(pane.watched, isFalse);
      expect(closeRequests, 0, reason: 'popping never hides the palette');

      logic.dispose();
    });

    test('notes show with an empty query and leave with their section when '
        'nothing in it matches', () async {
      final logic = openOn(pane);
      pane.show(
        const PaneContent([
          PaneSection(
            notes: [
              PaneNote([PaneSpan('No local models yet.')]),
            ],
            rows: [],
          ),
          PaneSection(
            notes: [PaneNote.blank()],
            rows: [PaneRow(id: 'a', label: 'Alpha')],
          ),
        ]),
      );
      await settle();
      expect(paneOf(logic).visibleSections, hasLength(2));
      expect(paneOf(logic).selectedRow?.id, 'a');

      logic.input(const QueryChanged('alp'));
      final narrowed = paneOf(logic).visibleSections;
      expect(narrowed, hasLength(1));
      expect(narrowed.single.notes, hasLength(1));
      expect(narrowed.single.rows.single.id, 'a');

      logic.dispose();
    });

    test('closing from a pane asks the host to hide the palette', () async {
      var closeRequests = 0;
      final logic = openOn(pane);
      final binding = logic.bind()
        ..onOutput<CloseRequested>((_) => closeRequests++);
      addTearDown(binding.dispose);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Use', result: const PaneClose()),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      expect(closeRequests, 1);
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.paneTrail, isEmpty);
      expect(pane.watched, isFalse);

      logic.dispose();
    });

    test('a command opened from a pane collects, runs, and comes back to '
        'the pane', () async {
      const confirm = ParamKey<bool>('confirm');
      final results = <CommandResult>[
        const CommandRejected('in use'),
        const CommandRan(),
      ];
      var invoked = 0;
      var closeRequests = 0;
      final delete = simpleCommand(
        'Delete Gemma',
        next: (soFar) => soFar.maybe(confirm) == null
            ? const ConfirmParam(key: confirm, label: 'Sure?', danger: true)
            : null,
        invoke: (_) async => results[invoked++],
      );
      final logic = openOn(pane);
      final binding = logic.bind()
        ..onOutput<CloseRequested>((_) => closeRequests++);
      addTearDown(binding.dispose);
      pane.show(
        listing([
          [
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
        ]),
      );
      await settle();

      logic.input(const PaneKeyPressed('d'));
      await settle();
      final collecting = logic.value as CollectingState;
      expect(collecting.activeCommand, same(delete));
      expect(collecting.paneTrail, ['Local Models', 'Installed']);
      expect(pane.watched, isFalse);

      logic.input(const Back());
      expect(logic.value, isA<NavigatingPaneState>());
      expect(pane.watched, isTrue);

      logic.input(const PaneKeyPressed('d'));
      await settle();
      logic.input(const SubmitChoice());
      expect(logic.value, isA<InvokingState>());
      expect(logic.value.paneTrail, ['Local Models', 'Installed']);
      await settle();
      expect(logic.value, isA<NavigatingPaneState>());
      expect(paneOf(logic).error, 'in use');

      logic.input(const PaneKeyPressed('d'));
      await settle();
      logic.input(const SubmitChoice());
      await settle();
      expect(logic.value, isA<NavigatingPaneState>());
      expect(paneOf(logic).error, isNull);
      expect(closeRequests, 0, reason: 'the pane stays open');
      expect(invoked, 2);

      logic.dispose();
    });

    test('a parameterless command opened from a pane runs straight '
        'away', () async {
      var invoked = false;
      final refresh = simpleCommand(
        'Refresh',
        invoke: (_) async {
          invoked = true;
          return const CommandRan();
        },
      );
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Refresh', result: PaneOpenCommand(refresh)),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      await settle();
      expect(invoked, isTrue);
      expect(logic.value, isA<NavigatingPaneState>());

      logic.dispose();
    });

    test('hiding the palette from a pane forgets every pane', () async {
      final logic = openOn(pane)..input(const ClosePalette());
      expect(logic.value, isA<ClosedState>());
      expect(logic.value.paneTrail, isEmpty);
      expect(pane.watched, isFalse);
      expect(pane.statusWatched, isFalse);

      logic.input(const OpenPalette());
      expect(logic.value, isA<BrowsingState>());

      logic.dispose();
    });

    test('stopping cancels the pane subscriptions', () async {
      openOn(pane)
        ..stop()
        ..dispose();
      expect(pane.watched, isFalse);
      expect(pane.statusWatched, isFalse);
    });

    test('a late action result after the palette hid is ignored', () async {
      final finish = Completer<PaneActionResult>();
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                PaneAction.primary(label: 'Slow', invoke: () => finish.future),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const Activate())
        ..input(const ClosePalette());
      finish.complete(PanePush(DemoPane()));
      await settle();
      expect(logic.value, isA<ClosedState>());

      logic.dispose();
    });

    test('the selection follows its row when the content reorders, and keys '
        'act on that row', () async {
      final runs = <String>[];
      PaneRow row(String id) => PaneRow(
        id: id,
        label: id,
        actions: [demoAction(runs, id, key: const CharKey('d'))],
      );
      final logic = openOn(pane);
      pane.show(
        listing([
          [row('a'), row('b')],
          [row('c')],
        ]),
      );
      await settle();
      logic.input(const MoveSelection(1));
      expect(paneOf(logic).selectedRow?.id, 'b');

      pane.show(
        listing([
          [row('b')],
          [row('c'), row('a')],
        ]),
      );
      await settle();
      expect(paneOf(logic).selectedIndex, 0);
      expect(paneOf(logic).selectedRow?.id, 'b');

      logic.input(const PaneKeyPressed('d'));
      await settle();
      expect(runs, ['b'], reason: 'the key acts on the row, not the slot');

      pane.show(
        listing([
          [row('c'), row('a')],
        ]),
      );
      await settle();
      expect(
        paneOf(logic).selectedRow?.id,
        'c',
        reason: 'a vanished row leaves the cursor where it was',
      );

      logic.dispose();
    });

    test('the visible rows are worked out once per listing and '
        'query', () async {
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            const PaneRow(id: 'a', label: 'Alpha'),
            const PaneRow(id: 'b', label: 'Beta'),
          ],
        ]),
      );
      await settle();
      final state = paneOf(logic);
      final sections = state.visibleSections;
      expect(state.visibleSections, same(sections));

      logic.input(const QueryChanged('beta'));
      final narrowed = paneOf(logic).visibleSections;
      expect(narrowed, isNot(same(sections)));
      expect(narrowed.single.rows.single.id, 'b');
      expect(paneOf(logic).visibleSections, same(narrowed));

      logic.dispose();
    });

    test('a query the pane already has changes nothing', () async {
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            const PaneRow(id: 'a', label: 'Alpha'),
            const PaneRow(id: 'b', label: 'Alpine'),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const QueryChanged('al'))
        ..input(const MoveSelection(1))
        ..input(const QueryChanged('al'));
      final state = paneOf(logic);
      expect(state, isA<NavigatingPaneState>());
      expect(state.selectedRow?.id, 'b');

      logic.dispose();
    });

    test("a pane stream failure shows in that pane's error band", () async {
      final logic = openOn(pane);
      pane.failContent(StateError('catalog unreachable'));
      await settle();
      expect(paneOf(logic).error, contains('catalog unreachable'));

      logic.input(const QueryChanged('x'));
      expect(paneOf(logic).error, isNull);

      pane.failStatus(StateError('disk unreadable'));
      await settle();
      expect(paneOf(logic).error, contains('disk unreadable'));

      logic.input(const Back());
      expect(logic.value.error, isNull, reason: 'the command list is clean');

      logic.dispose();
    });

    test('an action runs once at a time', () async {
      final finish = Completer<PaneActionResult>();
      var runs = 0;
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                PaneAction.primary(
                  label: 'Download',
                  invoke: () {
                    runs++;
                    return finish.future;
                  },
                ),
                PaneAction(
                  key: const CharKey('d'),
                  label: 'Delete',
                  invoke: () async {
                    runs++;
                    return const PaneStay();
                  },
                ),
              ],
            ),
          ],
        ]),
      );
      await settle();

      logic
        ..input(const Activate())
        ..input(const Activate())
        ..input(const PaneKeyPressed('d'));
      expect(runs, 1);
      expect(paneOf(logic).pendingAction?.label, 'Download');
      expect(paneOf(logic).claimsKey('d'), isTrue, reason: 'never typed');

      finish.complete(const PaneStay());
      await settle();
      expect(paneOf(logic).pendingAction, isNull);

      logic.input(const Activate());
      await settle();
      expect(runs, 2);

      logic.dispose();
    });

    test('an action result for a pane that is gone is ignored', () async {
      final inner = DemoPane(title: 'gemma-4');
      addTearDown(inner.close);
      final finish = Completer<PaneActionResult>();
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Open', result: PanePush(inner)),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      inner.show(
        listing([
          [
            PaneRow(
              id: 'q4',
              label: 'Q4_K_M',
              actions: [
                PaneAction.primary(
                  label: 'Download',
                  invoke: () => finish.future,
                ),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const Activate())
        ..input(const Back());

      finish.complete(const PaneRejected('too late'));
      await settle();
      final state = paneOf(logic);
      expect(state.pane, same(pane));
      expect(state.error, isNull);
      expect(state.pendingAction, isNull);

      logic.dispose();
    });

    test('an action result after the pane was reopened is ignored', () async {
      final finish = Completer<PaneActionResult>();
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                PaneAction.primary(label: 'Slow', invoke: () => finish.future),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic
        ..input(const Activate())
        ..input(const ClosePalette())
        ..input(const OpenPalette())
        ..input(const Activate());

      finish.complete(PanePush(DemoPane()));
      await settle();
      final state = paneOf(logic);
      expect(state.pane, same(pane));
      expect(state.paneTrail, ['Local Models', 'Installed']);
      expect(state.pendingAction, isNull);

      logic.dispose();
    });

    test('a pane rejection stays with the pane, and the command list keeps '
        'its own error', () async {
      final logic =
          PaletteLogic(
              commands: [
                simpleCommand(
                  'models.installed',
                  group: 'Local Models',
                  pane: pane,
                ),
                simpleCommand(
                  'models.refresh',
                  invoke: (_) async => const CommandRejected('offline'),
                ),
              ],
            )
            ..start()
            ..input(const OpenPalette())
            ..input(const MoveSelection(1))
            ..input(const Activate());
      await settle();
      await settle();
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.error, 'offline');
      expect(logic.value.hasPanes, isFalse);

      logic
        ..input(const MoveSelection(-1))
        ..input(const Activate());
      expect(logic.value.hasPanes, isTrue);
      expect(paneOf(logic).error, isNull);

      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction([], 'Use', result: const PaneRejected('busy')),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      expect(paneOf(logic).error, 'busy');

      logic.input(const Back());
      expect(logic.value, isA<BrowsingState>());
      expect(logic.value.error, isNull);

      logic.dispose();
    });

    test('an action can open a pane command on top of the pane', () async {
      final inner = DemoPane(title: 'Downloads');
      addTearDown(inner.close);
      final logic = openOn(pane);
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [
                demoAction(
                  [],
                  'Downloads',
                  result: PaneOpenCommand(
                    simpleCommand('models.downloads', pane: inner),
                  ),
                ),
              ],
            ),
          ],
        ]),
      );
      await settle();
      logic.input(const Activate());
      await settle();
      final state = paneOf(logic);
      expect(state.pane, same(inner));
      expect(state.paneTrail, ['Local Models', 'Installed', 'Downloads']);

      logic.dispose();
    });
  });

  group('PaletteCubit panes', () {
    test('forwards pane keys', () async {
      final pane = DemoPane();
      addTearDown(pane.close);
      final runs = <String>[];
      final cubit = PaletteCubit(
        commands: catalogOf([simpleCommand('a.pane', pane: pane)]),
      )..openSession();
      addTearDown(cubit.close);
      cubit.activate();
      pane.show(
        listing([
          [
            PaneRow(
              id: 'a',
              label: 'Alpha',
              actions: [demoAction(runs, 'Info', key: const CharKey('i'))],
            ),
          ],
        ]),
      );
      await settle();
      cubit.pressPaneKey('i');
      await settle();
      expect(runs, ['Info']);
    });

    test('emits one update per pane transition', () async {
      final pane = DemoPane();
      addTearDown(pane.close);
      final cubit = PaletteCubit(
        commands: catalogOf([simpleCommand('a.pane', pane: pane)]),
      )..openSession();
      addTearDown(cubit.close);
      cubit.activate();
      pane.show(
        listing([
          [
            const PaneRow(id: 'a', label: 'Alpha'),
            const PaneRow(id: 'b', label: 'Alpine'),
          ],
        ]),
      );
      await settle();
      final updates = <PaletteState>[];
      final subscription = cubit.stream.listen(updates.add);
      addTearDown(subscription.cancel);

      cubit.queryChanged('al');
      await settle();
      expect(updates.single, isA<FilteringPaneState>());

      cubit.moveSelection(1);
      await settle();
      expect(updates, hasLength(2));
      expect(updates.last, isA<NavigatingPaneState>());

      cubit.moveSelection(-1);
      await settle();
      expect(updates, hasLength(3));
    });
  });
}
