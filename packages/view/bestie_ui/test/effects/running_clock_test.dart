import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

class _Counter extends StatefulComponent {
  const _Counter({required this.running, required this.builds});

  final bool running;
  final List<int> builds;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with RunningClock {
  int _built = 0;

  @override
  Duration get runningClockInterval => const Duration(milliseconds: 10);

  @override
  void initState() {
    super.initState();
    syncRunningClock(running: component.running);
  }

  @override
  void didUpdateComponent(_Counter oldComponent) {
    super.didUpdateComponent(oldComponent);
    syncRunningClock(running: component.running);
  }

  @override
  Component build(BuildContext context) {
    component.builds.add(++_built);
    return Text('$tick');
  }
}

class _SlowCounter extends StatefulComponent {
  const _SlowCounter({required this.builds});

  final List<int> builds;

  @override
  State<_SlowCounter> createState() => _SlowCounterState();
}

class _SlowCounterState extends State<_SlowCounter> with RunningClock {
  int _built = 0;

  @override
  void initState() {
    super.initState();
    syncRunningClock(running: true);
  }

  @override
  Component build(BuildContext context) {
    component.builds.add(++_built);
    return Text('$_built');
  }
}

void main() {
  test('beats once a second by default', () async {
    await testNocterm('slow clock', size: const Size(10, 1), (tester) async {
      final builds = <int>[];
      await tester.pumpComponent(_SlowCounter(builds: builds));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(builds, hasLength(1));
    });
  });

  test('holds still until told it is running, then beats', () async {
    await testNocterm('running clock', size: const Size(10, 1), (tester) async {
      final builds = <int>[];
      await tester.pumpComponent(_Counter(running: false, builds: builds));
      await tester.pump(const Duration(milliseconds: 50));
      expect(builds, hasLength(1));
      expect(tester.terminalState.getText().trim(), '0');

      await tester.pumpComponent(_Counter(running: true, builds: builds));
      await tester.pump(const Duration(milliseconds: 55));
      await tester.pump();
      final whileRunning = builds.length;
      expect(whileRunning, greaterThan(2));
      final ticked = int.parse(tester.terminalState.getText().trim());
      expect(ticked, greaterThan(1));

      await tester.pumpComponent(_Counter(running: false, builds: builds));
      await tester.pump();
      final stopped = builds.length;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(builds.length, stopped);
    });
  });
}
