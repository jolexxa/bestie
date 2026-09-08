import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

KeyboardEvent _press(LogicalKey key) => KeyboardEvent(logicalKey: key);

void main() {
  group('SelectionInputController', () {
    test('tryHandle returns false when no handler is bound', () {
      final controller = SelectionInputController();
      expect(controller.hasHandler, isFalse);
      expect(controller.tryHandle(_press(LogicalKey.arrowUp)), isFalse);
    });

    test('bind installs a handler; tryHandle routes through it', () {
      final controller = SelectionInputController();
      final owner = Object();
      KeyboardEvent? seen;
      controller.bind(owner, (event) {
        seen = event;
        return true;
      });
      expect(controller.hasHandler, isTrue);
      final event = _press(LogicalKey.enter);
      expect(controller.tryHandle(event), isTrue);
      expect(seen, same(event));
    });

    test('unbind by the current owner releases the handler', () {
      final controller = SelectionInputController();
      final owner = Object();
      controller
        ..bind(owner, (_) => true)
        ..unbind(owner);
      expect(controller.hasHandler, isFalse);
      expect(controller.tryHandle(_press(LogicalKey.enter)), isFalse);
    });

    test(
      'unbind by a stale owner is a no-op when a new owner has bound',
      () {
        // Simulates a rebuild race where a new item binds before the old
        // item's dispose runs. The stale unbind must NOT clobber the
        // newer binding.
        final controller = SelectionInputController();
        final oldOwner = Object();
        final newOwner = Object();
        controller
          ..bind(oldOwner, (_) => false)
          ..bind(newOwner, (_) => true)
          // Old owner's dispose fires LAST — must not unbind the new one.
          ..unbind(oldOwner);

        expect(controller.hasHandler, isTrue);
        expect(controller.tryHandle(_press(LogicalKey.arrowDown)), isTrue);
      },
    );

    test('handler can choose not to consume the event', () {
      final controller = SelectionInputController()
        ..bind(Object(), (_) => false);
      expect(controller.tryHandle(_press(LogicalKey.escape)), isFalse);
    });
  });
}
