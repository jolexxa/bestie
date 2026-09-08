import 'package:bestie_chat_view/src/state/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  group('SelectionPosition', () {
    test('value-equality: same itemIndex + subIndex compare equal', () {
      const a = SelectionPosition(itemIndex: 3, subIndex: 2);
      const b = SelectionPosition(itemIndex: 3, subIndex: 2);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('SelectionLogic initial state', () {
    test('starts in Unobserved at (0, 0)', () {
      final logic = SelectionLogic()..start();
      expect(logic.value, isA<Unobserved>());
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      expect(logic.value.followsTail, isFalse);
      logic.dispose();
    });
  });

  group('Unobserved', () {
    test('empty TimelineShapeChanged keeps state in Unobserved', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([]));
      expect(logic.value, isA<Unobserved>());
      logic.dispose();
    });

    test(
      'non-empty TimelineShapeChanged initializes position to tail and '
      'transitions to Observed',
      () {
        final logic = SelectionLogic()
          ..start()
          ..input(const TimelineShapeChanged([0, 0, 0]));
        expect(logic.value, isA<Observed>());
        expect(
          logic.value.position,
          equals(const SelectionPosition(itemIndex: 2, subIndex: 0)),
        );
        expect(logic.value.followsTail, isTrue);
        logic.dispose();
      },
    );

    test('MoveUp / MoveDown are silently ignored', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const MoveUp())
        ..input(const MoveDown());
      expect(logic.value, isA<Unobserved>());
      logic.dispose();
    });
  });

  group('Observed', () {
    SelectionLogic observed({List<int> counts = const [0, 0, 0]}) =>
        SelectionLogic()
          ..start()
          ..input(TimelineShapeChanged(counts));

    test('MoveUp from the tail moves the selection up one slot', () {
      final logic = observed()..input(const MoveUp()); // (2, 0) → (1, 0)
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
      logic.dispose();
    });

    test('MoveUp at the top is a no-op', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0]))
        ..input(const MoveUp());
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      logic.dispose();
    });

    test('MoveDown from not-tail moves down one slot', () {
      final logic = observed()
        ..input(const MoveUp()) // (1, 0)
        ..input(const MoveDown()); // (2, 0)
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 2, subIndex: 0)),
      );
      logic.dispose();
    });

    test('MoveDown at the tail is a no-op (nothing below)', () {
      final logic = observed(); // (2, 0) — tail
      final before = logic.value.position;
      logic.input(const MoveDown());
      expect(logic.value, isA<Observed>());
      expect(logic.value.position, equals(before));
      logic.dispose();
    });

    test('walks through child sub-slots before the previous item', () {
      final logic = observed(counts: [2, 0, 0])
        ..input(const MoveUp()) // → (1, 0)
        ..input(const MoveUp()); // → (0, 2): item 0's last child
      expect(logic.value.position.itemIndex, equals(0));
      expect(logic.value.position.subIndex, equals(2));
      logic.dispose();
    });

    test('ResetSelection transitions to Unobserved with fresh data', () {
      final logic = observed()..input(const ResetSelection());
      expect(logic.value, isA<Unobserved>());
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      logic.dispose();
    });
  });

  group('SelectItem', () {
    test('jumps the cursor to the item', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0]))
        ..input(const SelectItem(0));
      expect(logic.value, isA<Observed>());
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      logic.dispose();
    });

    test('clamps an out-of-range index to the last item', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0]))
        ..input(const SelectItem(99));
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 2, subIndex: 0)),
      );
      logic.dispose();
    });

    test('resets any sub-slot to 0 when landing on an item', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([2, 0, 0]))
        ..input(const MoveUp()) // → (1, 0)
        ..input(const MoveUp()); // → (0, 2): item 0's last child
      expect(logic.value.position.subIndex, greaterThan(0));
      logic.input(const SelectItem(0));
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      logic.dispose();
    });

    test('in Unobserved is a silent no-op', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const SelectItem(1));
      expect(logic.value, isA<Unobserved>());
      logic.dispose();
    });
  });

  group('FollowTail', () {
    test('snaps an anchored cursor back onto the tail and re-follows', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])) // (2, 0), following
        ..input(const MoveUp()) // (1, 0), off the tail
        ..input(const FollowTail());
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 2, subIndex: 0)),
      );
      expect(logic.value.followsTail, isTrue);
      logic.dispose();
    });

    test('after FollowTail, subsequent growth rides the tail', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0]))
        ..input(const SelectItem(0)) // anchored on the first item
        ..input(const FollowTail()) // re-engage following
        ..input(const TimelineShapeChanged([0, 0, 0, 0])); // grow
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 3, subIndex: 0)),
      );
      logic.dispose();
    });

    test('is a silent no-op in Unobserved', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const FollowTail());
      expect(logic.value, isA<Unobserved>());
      logic.dispose();
    });

    test('emits PositionChanged only when it actually moves the cursor', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])); // (2, 0) — tail
      final positions = <SelectionPosition>[];
      final binding = logic.bind()
        ..onOutput<PositionChanged>(
          (output) => positions.add(output.position),
        );

      logic.input(const FollowTail()); // already on the tail — no move
      expect(positions, isEmpty);

      logic
        ..input(const MoveUp()) // (1, 0) — off tail (emits)
        ..input(const FollowTail()); // back to (2, 0) — emits
      expect(
        positions,
        equals(const [
          SelectionPosition(itemIndex: 1, subIndex: 0),
          SelectionPosition(itemIndex: 2, subIndex: 0),
        ]),
      );

      binding.dispose();
      logic.dispose();
    });
  });

  group('Tail-follow auto-advance', () {
    test(
      'TimelineShapeChanged with longer list while at the tail advances',
      () {
        final logic = SelectionLogic()
          ..start()
          ..input(const TimelineShapeChanged([0, 0, 0])); // (2, 0)
        expect(logic.value.followsTail, isTrue);

        logic.input(const TimelineShapeChanged([0, 0, 0, 0]));
        expect(
          logic.value.position,
          equals(const SelectionPosition(itemIndex: 3, subIndex: 0)),
        );
        logic.dispose();
      },
    );

    test('TimelineShapeChanged while NOT at the tail keeps position', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])) // (2, 0)
        ..input(const MoveUp()) // → (1, 0), off the tail
        ..input(const TimelineShapeChanged([0, 0, 0, 0]));
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
      logic.dispose();
    });

    test('clicking a non-tail item then growth keeps it anchored', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])) // (2, 0)
        ..input(const SelectItem(1)) // click item 1, off the tail
        ..input(const TimelineShapeChanged([0, 0, 0, 0]));
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
      logic.dispose();
    });

    test('clicking the tail item re-engages tail following', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])) // (2, 0)
        ..input(const SelectItem(0)) // off the tail
        ..input(const SelectItem(2)) // click the current tail
        ..input(const TimelineShapeChanged([0, 0, 0, 0]));
      expect(
        logic.value.position,
        equals(const SelectionPosition(itemIndex: 3, subIndex: 0)),
      );
      logic.dispose();
    });

    test('TimelineShapeChanged shrinking the list clamps position', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0, 0, 0])) // (4, 0)
        ..input(const TimelineShapeChanged([0, 0, 0]));
      // Position was at (4, 0) — old tail — so it auto-advances to new
      // tail (2, 0).
      expect(logic.value.position.itemIndex, equals(2));
      logic.dispose();
    });

    test('TimelineShapeChanged to empty falls back to Unobserved', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0]))
        ..input(const TimelineShapeChanged([]));
      expect(logic.value, isA<Unobserved>());
      logic.dispose();
    });
  });

  group('Output binding', () {
    test('PositionChanged is emitted when position moves', () {
      final logic = SelectionLogic()..start();
      final positions = <SelectionPosition>[];
      final binding = logic.bind()
        ..onOutput<PositionChanged>(
          (output) => positions.add(output.position),
        );

      logic
        ..input(const TimelineShapeChanged([0, 0, 0])) // init to (2, 0)
        ..input(const MoveUp()) // → (1, 0)
        ..input(const MoveUp()); // → (0, 0)

      expect(positions, hasLength(3));
      expect(
        positions[0],
        equals(const SelectionPosition(itemIndex: 2, subIndex: 0)),
      );
      expect(
        positions[1],
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
      expect(
        positions[2],
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );

      binding.dispose();
      logic.dispose();
    });

    test('a no-op move does NOT emit PositionChanged', () {
      final logic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0])); // (2, 0) — tail
      final positions = <SelectionPosition>[];
      final binding = logic.bind()
        ..onOutput<PositionChanged>(
          (output) => positions.add(output.position),
        );

      logic.input(const MoveDown()); // nothing below the tail

      expect(positions, isEmpty);

      binding.dispose();
      logic.dispose();
    });
  });
}
