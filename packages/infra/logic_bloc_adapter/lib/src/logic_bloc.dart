import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// A [BlocBase] adapter that wraps a [LogicBlock].
///
/// Overrides [emit] and [stream] to bypass [BlocBase]'s equality-based
/// deduplication. Logic blocks reuse state objects, so identity checks
/// would suppress legitimate rebuilds from toSelf() transitions.
abstract class LogicBloc<TState extends StateLogic<TState>>
    extends BlocBase<TState> {
  /// Starts [logic] and wires its state changes through this bloc's
  /// [emit] (bypassing equality-based deduplication).
  LogicBloc(this.logic) : super(logic.start()) {
    binding = logic.bind()..onState<TState>(emit);
  }

  /// The wrapped logic block. Owned by this bloc — stopped and
  /// disposed in [close].
  final LogicBlock<TState> logic;

  /// The binding to the logic block. Subclasses can add output handlers.
  late final LogicBlockBinding<TState> binding;

  final StreamController<TState> _changes =
      StreamController<TState>.broadcast();

  StreamController<Object>? _outputs;

  @override
  Stream<TState> get stream => _changes.stream;

  /// Every output the logic block produces, in the order it produced them.
  ///
  /// The channel a view listens to for the signals a rebuild cannot carry —
  /// clear the input, scroll to the cursor, show a banner. A settable callback
  /// per signal is the same wiring with a mutable field to null out for each
  /// one, and binding the view straight to [logic] reaches past the view model
  /// that exists to stand between them.
  ///
  /// Wired on first listen, so a bloc whose outputs are all handled through
  /// [binding] pays nothing for having this.
  Stream<Object> get outputs => _openOutputs().stream;

  /// Just the outputs of type [TOutput] — a sealed output base, so a listener
  /// switches on it exhaustively, or one output when that is all it wants.
  Stream<TOutput> outputsOf<TOutput extends Object>() =>
      outputs.where((output) => output is TOutput).cast<TOutput>();

  StreamController<Object> _openOutputs() {
    final open = _outputs;
    if (open != null) return open;
    final opened = _outputs = StreamController<Object>.broadcast();
    binding.onOutput<Object>((output) {
      if (!opened.isClosed) opened.add(output);
    });
    return opened;
  }

  @override
  TState get state => logic.value;

  @override
  void emit(TState state) {
    if (!isClosed) _changes.add(state);
  }

  /// Sends an input to the underlying logic block.
  TState input<TInput extends Object>(TInput input) => logic.input(input);

  /// Gets a value from the logic block's blackboard.
  TData get<TData extends Object>() => logic.get<TData>();

  @override
  Future<void> close() async {
    binding.dispose();
    logic.stop();
    await _changes.close();
    await _outputs?.close();
    return super.close();
  }
}
