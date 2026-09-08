import 'dart:async';

import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('gatedAvailability', () {
    Availability gate(int count) =>
        count > 0 ? const Available() : const Unavailable('none');

    test('seeds the current value on listen', () async {
      final changes = StreamController<int>();
      addTearDown(changes.close);

      final seen = <Availability>[];
      final sub = gatedAvailability(
        () => 0,
        changes.stream,
        gate,
      ).listen(seen.add);
      addTearDown(sub.cancel);
      await _pump();

      expect(seen.single, isA<Unavailable>());
      expect((seen.single as Unavailable).reason, 'none');
    });

    test('follows every change through the gate', () async {
      final changes = StreamController<int>();
      addTearDown(changes.close);

      final seen = <Availability>[];
      final sub = gatedAvailability(
        () => 0,
        changes.stream,
        gate,
      ).listen(seen.add);
      addTearDown(sub.cancel);
      await _pump();

      changes.add(2);
      await _pump();
      changes.add(0);
      await _pump();

      expect(seen, [
        isA<Unavailable>(),
        isA<Available>(),
        isA<Unavailable>(),
      ]);
    });

    test('reads the seed lazily for a late subscriber', () async {
      var count = 0;
      final changes = StreamController<int>.broadcast();
      addTearDown(changes.close);
      final stream = gatedAvailability(() => count, changes.stream, gate);

      final early = <Availability>[];
      final earlySub = stream.listen(early.add);
      addTearDown(earlySub.cancel);
      await _pump();
      expect(early.first, isA<Unavailable>());

      // State moves on after the stream was built but before the late listen.
      count = 3;
      final late = <Availability>[];
      final lateSub = stream.listen(late.add);
      addTearDown(lateSub.cancel);
      await _pump();

      expect(late.first, isA<Available>());
    });

    test('cancels the source subscription when the listener leaves', () async {
      var cancelled = false;
      final changes = StreamController<int>(onCancel: () => cancelled = true);

      final sub = gatedAvailability(
        () => 0,
        changes.stream,
        gate,
      ).listen((_) {});
      await _pump();
      await sub.cancel();

      expect(cancelled, isTrue);
    });
  });
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
