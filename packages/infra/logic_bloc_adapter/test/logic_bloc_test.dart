import 'dart:async';

import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:test/test.dart';

sealed class _TestState extends StateLogic<_TestState> {}

final class _IdleState extends _TestState {
  _IdleState() {
    on<_Bump>((_) {
      output(const _Bumped());
      return to<_ActiveState>();
    });
    on<_Stay>((_) {
      output(const _Stayed());
      return toSelf();
    });
  }
}

final class _ActiveState extends _TestState {
  _ActiveState() {
    on<_Stay>((_) {
      output(const _Stayed());
      return toSelf();
    });
  }
}

sealed class _TestOutput {
  const _TestOutput();
}

final class _Bumped extends _TestOutput {
  const _Bumped();
}

final class _Stayed extends _TestOutput {
  const _Stayed();
}

final class _Bump {
  const _Bump();
}

final class _Stay {
  const _Stay();
}

final class _Dep {
  const _Dep(this.value);
  final int value;
}

final class _TestLogic extends LogicBlock<_TestState> {
  _TestLogic() {
    set(const _Dep(42));
    set(_IdleState());
    set(_ActiveState());
  }

  @override
  Transition getInitialState() => to<_IdleState>();
}

class _TestBloc extends LogicBloc<_TestState> {
  _TestBloc() : super(_TestLogic());
}

void main() {
  group('LogicBloc', () {
    late _TestBloc bloc;

    setUp(() {
      bloc = _TestBloc();
    });

    test('exposes logic block state via state getter', () {
      expect(bloc.state, isA<_IdleState>());
    });

    test('forwards input to logic block and emits to stream', () async {
      final emitted = <_TestState>[];
      final sub = bloc.stream.listen(emitted.add);

      bloc.input(const _Bump());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<_ActiveState>());
      expect(emitted, hasLength(1));
      expect(emitted.single, isA<_ActiveState>());

      await sub.cancel();
    });

    test('reads values from the blackboard via get', () {
      expect(bloc.get<_Dep>().value, 42);
    });

    test('emit is a no-op after close', () async {
      await bloc.close();
      // Should not throw — emit early-returns when isClosed.
      bloc.emit(_IdleState());
    });

    test('close disposes the binding and closes the stream', () async {
      var done = false;
      bloc.stream.listen((_) {}, onDone: () => done = true);

      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    group('outputs', () {
      test('carries every output the logic block produces, in order', () async {
        final seen = <Object>[];
        final sub = bloc.outputs.listen(seen.add);

        bloc
          ..input(const _Stay())
          ..input(const _Bump());
        await Future<void>.delayed(Duration.zero);

        expect(seen, [isA<_Stayed>(), isA<_Bumped>()]);
        await sub.cancel();
      });

      test('outputsOf keeps only the type asked for', () async {
        final seen = <_TestOutput>[];
        final sub = bloc.outputsOf<_Bumped>().listen(seen.add);

        bloc
          ..input(const _Stay())
          ..input(const _Bump());
        await Future<void>.delayed(Duration.zero);

        expect(seen, [isA<_Bumped>()]);
        await sub.cancel();
      });

      // The point of wiring on first listen is that the handler is registered
      // once however many listeners there are, and never for a bloc whose
      // outputs are all handled through its binding.
      test('hands every listener the same channel', () async {
        final first = <Object>[];
        final second = <Object>[];
        final subs = [
          bloc.outputs.listen(first.add),
          bloc.outputs.listen(second.add),
        ];

        bloc.input(const _Bump());
        await Future<void>.delayed(Duration.zero);

        expect(first, hasLength(1));
        expect(second, hasLength(1));
        for (final sub in subs) {
          await sub.cancel();
        }
      });

      test('closes with the bloc', () async {
        var done = false;
        bloc.outputs.listen((_) {}, onDone: () => done = true);

        await bloc.close();
        await Future<void>.delayed(Duration.zero);

        expect(done, isTrue);
      });

      test('costs nothing when nobody listens', () async {
        // Closing must not trip over a channel that was never opened.
        bloc.input(const _Bump());
        await bloc.close();
      });
    });
  });
}
