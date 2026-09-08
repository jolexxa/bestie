// Not required for test files
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:blocterm/blocterm.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  test('Nested folds children right-to-left around child', () async {
    await testNocterm('nested fold', (tester) async {
      await tester.pumpComponent(
        Nested(
          children: [
            Provider<String>(value: 'outer', child: SizedBox()),
            Provider<int>(value: 7, child: SizedBox()),
          ],
          child: Builder(
            builder: (context) {
              final s = Provider.of<String>(context);
              final n = Provider.of<int>(context);
              return Text('$s=$n');
            },
          ),
        ),
      );

      expect(tester.terminalState, containsText('outer=7'));
    });
  });
}
