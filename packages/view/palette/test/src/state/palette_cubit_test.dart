import 'dart:async';

import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

import '../helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('PaletteCubit', () {
    test('forwards inputs and surfaces outputs through callbacks', () async {
      const name = ParamKey<String>('name');
      var invoked = false;
      var closeRequests = 0;
      final moves = <int>[];
      final cubit =
          PaletteCubit(
              commands: catalogOf([
                simpleCommand('a.one'),
                simpleCommand(
                  'b.text',
                  next: (soFar) => soFar.maybe(name) == null
                      ? const TextParam(key: name, label: 'Name')
                      : null,
                  invoke: (_) async {
                    invoked = true;
                    return const CommandRan();
                  },
                ),
              ]),
            )
            ..onCloseRequested = () {
              closeRequests++;
            }
            ..onCursorMoved = moves.add;
      expect(cubit.state, isA<ClosedState>());

      cubit.openSession();
      expect(cubit.state, isA<BrowsingState>());

      cubit.moveSelection(1);
      expect(moves, [1]);

      cubit.queryChanged('b.text');
      expect(cubit.state.rows.first.command.id, 'b.text');

      cubit.activate();
      expect(cubit.state, isA<CollectingState>());

      cubit.back();
      expect(cubit.state, isA<BrowsingState>());

      cubit
        ..activate()
        ..submitText('moo');
      await settle();
      expect(invoked, isTrue);
      expect(closeRequests, 1);

      cubit.requestClose();
      expect(closeRequests, 2);

      cubit.closeSession();
      expect(cubit.state, isA<ClosedState>());

      await cubit.close();
    });

    test('forwards choice picker inputs', () async {
      const pick = ParamKey<String>('pick');
      const files = ParamKey<List<String>>('files');
      Answers? received;
      final cubit =
          PaletteCubit(
              commands: catalogOf([
                simpleCommand(
                  'a.pickers',
                  next: (soFar) {
                    if (soFar.maybe(pick) == null) {
                      return ChoiceParam<String>.fixed(
                        key: pick,
                        label: 'Pick',
                        options: const [
                          Option(value: 'x', label: 'Ex'),
                          Option(value: 'y', label: 'Why'),
                        ],
                      );
                    }
                    if (soFar.maybe(files) == null) {
                      return MultiChoiceParam<String>.fixed(
                        key: files,
                        label: 'Files',
                        options: const [Option(value: 'a', label: 'a.md')],
                      );
                    }
                    return null;
                  },
                  invoke: (answers) async {
                    received = answers;
                    return const CommandRan();
                  },
                ),
              ]),
            )
            ..openSession()
            ..activate();
      await settle();
      cubit
        ..optionQueryChanged('why')
        ..submitChoice();
      await settle();

      cubit
        ..toggleOption()
        ..submitChoice();
      await settle();

      expect(received!.get(pick), 'y');
      expect(received!.get(files), ['a']);
      await cubit.close();
    });
  });
}
