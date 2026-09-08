// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:blocterm/blocterm.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

class _ReadValue extends StatelessComponent {
  const _ReadValue({this.listen = true});

  final bool listen;

  @override
  Component build(BuildContext context) {
    return Text('value: ${Provider.of<int>(context, listen: listen)}');
  }
}

class _SwapRoot extends StatefulComponent {
  const _SwapRoot();

  @override
  State<_SwapRoot> createState() => _SwapRootState();
}

class _SwapRootState extends State<_SwapRoot> {
  int _value = 1;

  void swap(int next) {
    setState(() {
      _value = next;
    });
  }

  @override
  Component build(BuildContext context) {
    return Provider<int>(
      value: _value,
      child: const _ReadValue(),
    );
  }
}

class _ListenFalseRoot extends StatefulComponent {
  const _ListenFalseRoot();

  @override
  State<_ListenFalseRoot> createState() => _ListenFalseRootState();
}

class _ListenFalseRootState extends State<_ListenFalseRoot> {
  int _value = 1;

  void swap(int next) {
    setState(() {
      _value = next;
    });
  }

  @override
  Component build(BuildContext context) {
    return Provider<int>(
      value: _value,
      child: const _ReadValue(listen: false),
    );
  }
}

void main() {
  test('Provider exposes value to descendants', () async {
    await testNocterm('provides value', (tester) async {
      await tester.pumpComponent(
        Provider<int>(value: 7, child: const _ReadValue()),
      );

      expect(tester.terminalState, containsText('value: 7'));
    });
  });

  test('Provider rebuilds listening descendants when value changes', () async {
    await testNocterm('value swap propagates', (tester) async {
      await tester.pumpComponent(const _SwapRoot());
      expect(tester.terminalState, containsText('value: 1'));

      tester.findState<_SwapRootState>().swap(42);
      await tester.pump();

      expect(tester.terminalState, containsText('value: 42'));
    });
  });

  test(
    'Provider.of with listen:false reads once without subscribing',
    () async {
      await testNocterm('non-listening read', (tester) async {
        await tester.pumpComponent(const _ListenFalseRoot());
        final state = tester.findState<_ListenFalseRootState>();
        // Initial render captures the current value via a non-listening read.
        expect(tester.terminalState, containsText('value: 1'));

        // Swapping the value updates the inherited scope but the leaf did NOT
        // subscribe, so it is not notified. Since the leaf is a const child,
        // the framework's identity check also skips the rebuild — the screen
        // still shows the original value.
        state.swap(99);
        await tester.pump();
        expect(tester.terminalState, containsText('value: 1'));
      });
    },
  );

  test('Provider.of throws ProviderNotFoundException when missing', () async {
    final tester = await NoctermTester.create();
    final previous = NoctermError.onError;
    Object? captured;
    try {
      NoctermError.onError = (details) {
        captured = details.exception;
      };
      await tester.pumpComponent(const _ReadValue());
      expect(captured, isA<ProviderNotFoundException>());
    } finally {
      NoctermError.onError = previous;
      tester.dispose();
    }

    expect(
      ProviderNotFoundException(int).toString(),
      contains('Provider<int>'),
    );
  });
}
