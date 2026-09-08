import 'package:nocterm/nocterm.dart';

/// Marker for components that wrap a single descendant.
///
/// Implementers expose [buildWithChild] so a [Nested] tree can fold a list
/// of providers around a single leaf without requiring the leaf to know
/// about the wrapping providers.
///
/// This is the nocterm port of `package:nested`'s `SingleChildWidget`.
// ignore: one_member_abstracts
abstract class SingleChildComponent {
  /// Returns a copy of this component that wraps [child] instead of
  /// whatever child it was originally constructed with.
  Component buildWithChild(BuildContext context, Component child);
}

/// Folds a list of [SingleChildComponent]s around a single [child], producing
/// a linear ancestor chain.
///
/// The first provider in [children] becomes the outermost ancestor; the last
/// provider in [children] is the closest ancestor of [child]. Providers later
/// in the list shadow earlier providers of the same type, matching
/// `package:nested`'s ordering semantics.
class Nested extends StatelessComponent {
  /// Creates a [Nested] that wraps [child] with every provider in [children].
  const Nested({
    required this.children,
    required this.child,
    super.key,
  });

  /// The providers that wrap [child]. Order matches ancestor depth: index 0
  /// is the outermost wrapper, the last entry is the closest to [child].
  final List<SingleChildComponent> children;

  /// The leaf component that every provider in [children] wraps.
  final Component child;

  @override
  Component build(BuildContext context) {
    var current = child;
    for (final provider in children.reversed) {
      current = provider.buildWithChild(context, current);
    }
    return current;
  }
}
