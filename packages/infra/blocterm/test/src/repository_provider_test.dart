// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:blocterm/blocterm.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

class _Repo {
  const _Repo(this.label);
  final String label;
}

class _ReadRepo extends StatelessComponent {
  const _ReadRepo();

  @override
  Component build(BuildContext context) {
    final repo = RepositoryProvider.of<_Repo>(context);
    return Text('repo: ${repo.label}');
  }
}

void main() {
  test('RepositoryProvider.value exposes value to descendants', () async {
    await testNocterm('repo value', (tester) async {
      await tester.pumpComponent(
        RepositoryProvider<_Repo>.value(
          value: const _Repo('users'),
          child: const _ReadRepo(),
        ),
      );

      expect(tester.terminalState, containsText('repo: users'));
    });
  });

  test(
    'RepositoryProvider.of throws RepositoryProviderNotFoundException',
    () async {
      final tester = await NoctermTester.create();
      final previous = NoctermError.onError;
      Object? captured;
      try {
        NoctermError.onError = (details) {
          captured = details.exception;
        };
        await tester.pumpComponent(const _ReadRepo());
        expect(captured, isA<RepositoryProviderNotFoundException>());
      } finally {
        NoctermError.onError = previous;
        tester.dispose();
      }

      expect(
        RepositoryProviderNotFoundException(_Repo).toString(),
        contains('RepositoryProvider<_Repo>'),
      );
    },
  );
}
