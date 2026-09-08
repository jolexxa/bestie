---
name: logic-blocks
description: Reference for Dart LogicBlocks — a statechart/state machine library ported from Chickensoft LogicBlocks for C#. Use when writing, debugging, or reviewing any LogicBlock state machine code in this Dart project. Covers state lifecycle, transitions, inputs, outputs, bindings, blackboard, async work, file organization, the LogicBloc adapter for nocterm, and pitfalls.
---

# Dart LogicBlocks

Hierarchical state machine (statechart) for Dart. Receives **inputs**, maintains a **single active state** (singleton instance per type), produces **outputs**.

| Statechart           | LogicBlocks                                |
| -------------------- | ------------------------------------------ |
| Event                | Input                                      |
| Action / Side effect | Output                                     |
| Internal transition  | `toSelf()`                                 |
| Guard                | Conditional logic inside `on<T>()` handler |
| Compound state       | Abstract parent state (inheritance)        |

## Defining a Logic Block

```dart
final class MyLogic extends LogicBlock<MyState> {
  MyLogic() {
    // Populate blackboard
    set(MyData());

    // Register singleton state instances
    set(IdleState());
    set(ActiveState());
  }

  @override
  Transition getInitialState() => to<IdleState>();
}
```

- `getInitialState()` is called lazily on `start()`.
- All concrete states must be registered via `set()` in the constructor.

## Inputs and Outputs

```dart
@model
sealed class MyInput {}

@model
final class Jump extends MyInput {}

@model
final class Move extends MyInput {
  Move({required this.direction});
  final Vector2 direction;
}

@model
sealed class MyOutput {}

@model
final class PlayAnimation extends MyOutput {
  const PlayAnimation(this.name);
  final String name;
}
```

- Inputs and outputs use `@model` annotation with `sealed` base + `final` concrete classes.
- Send inputs: `logic.input(Jump())`. Unhandled inputs silently resolve to `toSelf()`.
- Emit outputs from states: `output(PlayAnimation('jump'))`.

## States

States are `final class` types extending a `sealed` base that extends `StateLogic<TState>`.

```dart
@model
sealed class MyState extends StateLogic<MyState> {
  MyData get data => get<MyData>(); // convenience accessor
}
```

```dart
@model
final class IdleState extends MyState {
  IdleState() {
    onEnter(() => output(PlayAnimation('idle')));

    on<Jump>((_) => to<JumpingState>());
    on<Move>((input) {
      data.direction = input.direction;
      return to<MovingState>();
    });
  }
}
```

- `on<TInput>(handler)` declares handled inputs. Each returns a `Transition`.
- A state can register multiple `on<T>()` handlers.
- `onAny(handler)` provides a fallback for any unhandled input type.

### Hierarchical States

Inheritance creates compound states. Shared behavior goes in abstract parents:

```dart
@model
sealed class AliveState extends MyState {
  AliveState() {
    on<Killed>((_) => to<DeadState>());
  }
}

@model
sealed class GroundedState extends AliveState {
  GroundedState() {
    on<Jump>((_) => to<JumpingState>());
  }
}

@model
final class IdleState extends GroundedState { /* ... */ }

@model
final class MovingState extends GroundedState { /* ... */ }
```

### Shared Behavior with Mixins

Use `base mixin` on the state base to share handlers across non-sibling states:

```dart
base mixin Resettable on MyState {
  Transition onClear(Clear _) {
    data.reset();
    output(const StateUpdated());
    return to<ReadyState>();
  }
}

@model
final class ReadyState extends MyState with Resettable {
  ReadyState() {
    on<Clear>(onClear);
  }
}

@model
final class FailedState extends MyState with Resettable {
  FailedState() {
    on<Clear>(onClear);
  }
}
```

## Transitions

### `to<T>()` — change state type

Retrieves the singleton instance of `T`. Triggers lifecycle callbacks for hierarchy levels that **change**.

### `toSelf()` — stay in current state

No lifecycle callbacks fire. Use when handling an input without changing state.

### CRITICAL: States are singletons — `to<SameType>()` is a no-op

There is ONE instance per state type. `to<RenderingState>()` from within `RenderingState` returns the same instance — the framework sees no change and **skips all lifecycle callbacks**. Always use `toSelf()`. If you need per-iteration work, do it in `on<T>()`:

```dart
// WRONG — onEnter will NOT fire again:
on<Tick>((_) => to<RenderingState>());

// CORRECT:
on<Tick>((input) {
  doPerIterationWork();
  return toSelf();
});
```

## State Lifecycle Callbacks

Register in the state constructor:

| Callback                        | Fires when                                      | Use for                       |
| ------------------------------- | ----------------------------------------------- | ----------------------------- |
| `onEnter(callback)`             | Type hierarchy changes at this level (entering) | Business logic, emit outputs  |
| `onExit(callback)`              | Type hierarchy changes at this level (leaving)  | Cleanup, cancel subscriptions |
| `onEnterWithPrevious(callback)` | Same as onEnter, receives previous state        | Conditional enter logic       |
| `onExitWithNext(callback)`      | Same as onExit, receives next state             | Conditional exit logic        |

**onEnter/onExit only fire where the hierarchy diverges.** `IdleState -> MovingState` (both under `GroundedState`) only fires `IdleState.onExit` + `MovingState.onEnter` — parent callbacks are skipped.

**onEnter does NOT fire for the initial state.** Initialize defaults via `Data` property initializers.

## Blackboard: `set<T>()` and `get<T>()`

Shared key-value store keyed by type.

```dart
// Populate (logic block constructor):
set(MyData());
set(myDependency);

// Read (inside callbacks and on<T>() handlers ONLY):
final data = get<MyData>();
```

**`get<T>()`, `output()`, `input()` must NOT be called directly in a state constructor body** — wrap in `onEnter` or `on<T>()` handlers.

### Wrapper Types for Primitives

Wrap primitives so the blackboard can distinguish them by type:

```dart
@model
final class PrimarySeed {
  const PrimarySeed(this.value);
  final int value;
}

// In logic block constructor:
set(PrimarySeed(42));

// In state:
int get primarySeed => get<PrimarySeed>().value;
```

## Data Class

Shared mutable state across all states:

```dart
@model
final class MyData {
  int score = 0;
  String? error;
  Vector3 velocity = Vector3.zero;
}
```

## Async Work

Wrap futures and convert results/errors to inputs using `async()`:

```dart
@model
final class LoadingState extends MyState {
  LoadingState() {
    onEnter(() {
      async(fetchData())
        .input((result) => DataLoaded(result))
        .errorInput((error) => DataFailed(error.toString()));
    });

    on<DataLoaded>((input) {
      data.result = input.result;
      return to<ReadyState>();
    });

    on<DataFailed>((input) {
      data.error = input.error;
      return to<ErrorState>();
    });
  }
}
```

- `async<T>(Future<T>)` wraps a future.
- `.input(T -> TInput)` delivers success as an input.
- `.errorInput(Object -> TInput)` delivers failure as an input.
- Only the matching handler fires (success OR error, not both).
- Inputs still deliver even if the originating state has changed.
- `logic.task` returns a future that completes when all tracked async work is done.

## Bindings

External objects observe the logic block:

```dart
final binding = logic.bind();
binding
  ..onOutput<PlayAnimation>((output) => animPlayer.play(output.name))
  ..onState<DeadState>((state) => showGameOver());

// Also available:
binding.onInput<Jump>((input) { /* observe inputs */ });
binding.onError<Exception>((error) { /* handle errors */ });
```

- **Always dispose bindings** when done: `binding.dispose()`.

### Composing Logic Blocks

Bind a child logic block's outputs to the parent's inputs:

```dart
final class ParentLogic extends LogicBlock<ParentState> {
  ParentLogic() {
    final childLogic = ChildLogic();
    set(childLogic);

    _childBinding = childLogic.bind()
      ..onOutput<ChildResult>((output) {
        input(ChildCompleted(output.value));
      });
    childLogic.start();
  }

  late final LogicBlockBinding<ChildState> _childBinding;

  @override
  void onStop() {
    _childBinding.dispose();
    get<ChildLogic>().stop();
  }
}
```

## Start / Stop / Dispose

```dart
final logic = MyLogic();
logic.set(MyData());
final binding = logic.bind();
// ... register handlers ...
logic.start();   // enters initial state, onEnter does NOT fire

binding.dispose();
logic.stop();    // onExit fires
logic.dispose(); // permanent cleanup, cannot restart
```

- `start()` / `stop()` can be called multiple times.
- Once `dispose()` is called, the logic block cannot be reused.

## External Events -> Inputs

Subscribe to external streams/events at the **logic block level**, not inside states:

```dart
final class MyLogic extends LogicBlock<MyState> {
  MyLogic({required this.clock}) {
    set(MyData());
    set(IdleState());
    set(ActiveState());
  }

  final Clock clock;
  StreamSubscription<double>? _tickSub;

  @override
  void onStart() {
    _tickSub = clock.ticks.listen((delta) => input(TimePassed(delta)));
  }

  @override
  void onStop() {
    unawaited(_tickSub?.cancel());
    _tickSub = null;
  }

  @override
  Transition getInitialState() => to<IdleState>();
}
```

**Avoid subscribing to events inside states whenever possible (unless the event source is short-lived).** Ideally, states only react to inputs — the logic block bridges external events into the input stream.

## LogicBloc: Flutter Cubit Adapter

`LogicBloc<TState>` wraps a `LogicBlock` as a Flutter `BlocBase` (cubit), bridging state machines into `BlocProvider` / `BlocBuilder` / `BlocListener` widgets.

```dart
@viewModel
class MyCubit extends LogicBloc<MyState> {
  MyCubit({required MyLogic logic}) : super(logic) {
    // Add output handlers that drive cubit-level concerns
    binding
      ..onOutput<StateUpdated>((_) => emit(state))
      ..onOutput<MessageAccepted>((_) => onMessageAccepted?.call());
  }

  void Function()? onMessageAccepted;

  // Expose typed convenience methods for the UI
  MyData get data => get<MyData>();
  void submit(String text) => input(Submit(text));
  void cancel() => input(const Cancel());

  @override
  Future<void> close() async {
    if (isClosed) return;
    input(const Dispose());
    return super.close();
  }
}
```

**Key behavior:**

- `LogicBloc` starts the logic block in `super()` and binds state changes to `emit()`.
- It bypasses bloc's equality-based deduplication (logic blocks reuse singleton state objects).
- Output handlers on the binding decide **when** the cubit emits (e.g., only on `StateUpdated`).
- The cubit is a thin view-facing shell; all business logic lives in the `LogicBlock` + states.

### When to Use LogicBloc vs. Bare LogicBlock

| Use case                              | Pattern                                                |
| ------------------------------------- | ------------------------------------------------------ |
| View-facing state for Flutter widgets | `LogicBloc<TState>` (cubit adapter)                    |
| Domain/infrastructure component       | Bare `LogicBlock<TState>`                              |
| Nested child state machine            | Bare `LogicBlock<TState>`, bound to parent via binding |

Logic blocks are state machines that can slot anywhere into the architecture as implementation details for a component — they are not limited to view-layer usage.

## State Properties for the View

Override getters in the sealed base state to expose view-relevant data, with concrete states overriding as needed:

```dart
@model
sealed class ChatState extends StateLogic<ChatState> {
  // Defaults — concrete states override as needed
  bool get loading => false;
  bool get generating => false;
  String? get error => null;
  ChatPhase get phase;
}

@model
final class LoadingState extends ChatState {
  @override
  bool get loading => true;

  @override
  ChatPhase get phase => ChatPhase.loading;
}
```

## File Organization

```
feature/state/
  feature_logic.dart       (logic block + states + getInitialState)
  feature_cubit.dart       (LogicBloc adapter, if view-facing)
  feature_data.dart        (data class)
  feature_input.dart       (input classes)
  feature_output.dart      (output classes)
  models/                  (enums, value types used by state)
  child_feature/           (nested logic block for a sub-concern)
    child_logic.dart
    child_data.dart
    child_input.dart
    child_output.dart
```

States live in the same file as the logic block. Use `sealed` base + `final` concrete classes in a single file.

## Testing

### Integration-Style (Preferred)

Create the logic block with real or fake dependencies, send inputs, assert state types and data:

```dart
void main() {
  late FakeDownloadService downloadService;

  setUp(() {
    downloadService = FakeDownloadService();
  });

  test('download failure transitions to error state', () async {
    final logic = MyLogic(downloadService: downloadService)..start();

    logic.input(RequestDownload());
    expect(logic.value, isA<DownloadQueuedState>());

    downloadService.failWith(Exception('network error'));
    await Future<void>.delayed(Duration.zero);

    expect(logic.value, isA<ErrorState>());
    expect((logic.value as ErrorState).error, contains('network'));

    logic.dispose();
  });
}
```

### Isolated State Testing

Use `createFakeContext()` to test a state in isolation:

```dart
test('idle handles jump input', () {
  final state = IdleState();
  final fakeContext = state.createFakeContext();
  fakeContext.set(MyData());

  final transition = state.on(Jump());
  expect(transition.stateType, equals(JumpingState));
});
```

### Binding / Output Testing

```dart
test('emits PlayAnimation on enter', () async {
  final logic = MyLogic()..start();
  final outputs = <Object>[];
  final binding = logic.bind()
    ..onOutput<PlayAnimation>(outputs.add);

  logic.input(StartGame());
  await Future<void>.delayed(Duration.zero);

  expect(outputs, [isA<PlayAnimation>()]);

  binding.dispose();
  logic.dispose();
});
```

## Common Mistakes

1. **`to<SameType>()` instead of `toSelf()`.** Singleton states mean this is a no-op — lifecycle callbacks won't fire. Do per-cycle work in `on<T>()`.
2. **Expecting parent `onEnter` on sibling transitions.** Only the diverging hierarchy level fires.
3. **`get<T>()` / `output()` in state constructor body.** Must be inside `onEnter`, `on<T>()`, or other registered callbacks.
4. **Event subscriptions inside states.** Subscribe at the logic block level in `onStart()` / `onStop()`, not in states.
5. **Missing `set()` before `get<T>()`.** Populate blackboard before states run — register all state singletons and dependencies in the logic block constructor.
6. **Not disposing bindings.** Memory leaks.
7. **Using `to<T>()` for conditional no-change.** If a guard condition means "do nothing", return `toSelf()`, not `to<CurrentState>()`.
8. **Forgetting to register state instances.** Every concrete state type must be `set()` in the logic block constructor.
9. **Emitting from a cubit without `StateUpdated` output.** The `LogicBloc` adapter only calls `emit(state)` when an output handler tells it to — make sure states `output(const StateUpdated())` when the view should rebuild.
