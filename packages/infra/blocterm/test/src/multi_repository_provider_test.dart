// Not required for test files
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:bloc/bloc.dart';
import 'package:blocterm/blocterm.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

class _RepoA {
  const _RepoA(this.label);
  final String label;
}

class _RepoB {
  const _RepoB(this.label);
  final String label;
}

class _Counter extends Cubit<int> {
  _Counter([super.initialState = 0]);

  bool closed = false;

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}

class _ReadCounter extends StatelessComponent {
  const _ReadCounter();

  @override
  Component build(BuildContext context) {
    final cubit = BlocProvider.of<_Counter>(context, listen: false);
    return Text('count: ${cubit.state}');
  }
}

class _ReadAB extends StatelessComponent {
  const _ReadAB();

  @override
  Component build(BuildContext context) {
    final a = RepositoryProvider.of<_RepoA>(context);
    final b = RepositoryProvider.of<_RepoB>(context);
    return Text('a:${a.label} b:${b.label}');
  }
}

class _ReadA extends StatelessComponent {
  const _ReadA();

  @override
  Component build(BuildContext context) {
    final a = RepositoryProvider.of<_RepoA>(context);
    return Text('a:${a.label}');
  }
}

void main() {
  test('MultiRepositoryProvider exposes every provided value', () async {
    await testNocterm('multi exposure', (tester) async {
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<_RepoA>.value(
              value: const _RepoA('alpha'),
              child: SizedBox(),
            ),
            RepositoryProvider<_RepoB>.value(
              value: const _RepoB('beta'),
              child: SizedBox(),
            ),
          ],
          child: const _ReadAB(),
        ),
      );

      expect(tester.terminalState, containsText('a:alpha b:beta'));
    });
  });

  test('MultiRepositoryProvider hosts a BlocProvider.value', () async {
    await testNocterm('bloc value inside multi', (tester) async {
      final cubit = _Counter(11);
      try {
        await tester.pumpComponent(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<_RepoA>.value(
                value: const _RepoA('alpha'),
                child: SizedBox(),
              ),
              BlocProvider<_Counter>.value(
                value: cubit,
                child: SizedBox(),
              ),
            ],
            child: const _ReadCounter(),
          ),
        );

        expect(tester.terminalState, containsText('count: 11'));
      } finally {
        await cubit.close();
      }
    });
  });

  test('MultiRepositoryProvider hosts a BlocProvider.create', () async {
    await testNocterm('bloc create inside multi', (tester) async {
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            BlocProvider<_Counter>.create(create: (_) => _Counter(7)),
          ],
          child: const _ReadCounter(),
        ),
      );

      expect(tester.terminalState, containsText('count: 7'));
    });
  });

  test('Later providers shadow earlier providers of the same type', () async {
    await testNocterm('shadowing order', (tester) async {
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<_RepoA>.value(
              value: const _RepoA('outer'),
              child: SizedBox(),
            ),
            RepositoryProvider<_RepoA>.value(
              value: const _RepoA('inner'),
              child: SizedBox(),
            ),
          ],
          child: const _ReadA(),
        ),
      );

      // The provider later in the list is closer to the leaf, so it wins.
      expect(tester.terminalState, containsText('a:inner'));
    });
  });
}
