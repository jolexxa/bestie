import 'package:blocterm/src/single_child_component.dart';

/// Folds a list of [SingleChildComponent] providers around a single [child].
///
/// Order matches ancestor depth: providers earlier in the list are higher in
/// the tree, providers later in the list are closer to [child] and will
/// shadow earlier providers of the same type.
class MultiRepositoryProvider extends Nested {
  /// Creates a [MultiRepositoryProvider] that wraps [child] with every
  /// provider in [providers].
  const MultiRepositoryProvider({
    required List<SingleChildComponent> providers,
    required super.child,
    super.key,
  }) : super(children: providers);
}
