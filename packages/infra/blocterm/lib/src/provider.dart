import 'package:blocterm/src/single_child_component.dart';
import 'package:nocterm/nocterm.dart';

/// A provider that supplies a value of type [T] to its descendants.
///
/// `Provider` is a [StatelessComponent] that wraps its [child] in an internal
/// inherited scope keyed by [T]. This indirection lets specialized providers
/// (e.g. `RepositoryProvider`) extend [Provider] while still resolving through
/// the same lookup type.
class Provider<T> extends StatelessComponent implements SingleChildComponent {
  /// Creates a [Provider] with the given [value] and [child].
  ///
  /// [child] is optional so this provider can sit inside a
  /// `MultiRepositoryProvider`'s `providers` list without a placeholder —
  /// `Nested` re-parents each entry around the next via [buildWithChild].
  const Provider({
    required this.value,
    this.child,
    super.key,
  });

  /// The value provided to descendants.
  final T value;

  /// The descendant subtree. May be `null` when this provider is hosted
  /// inside a `MultiRepositoryProvider` — `Nested` will substitute a real
  /// child via [buildWithChild] before this provider is ever rendered.
  final Component? child;

  /// Retrieves the nearest provider of type [T] from the [context].
  ///
  /// Set [listen] to `false` to read the value once without subscribing to
  /// updates. The default subscribes the calling element so it rebuilds
  /// whenever the provided value changes.
  static T of<T>(BuildContext context, {bool listen = true}) {
    _InheritedProviderScope<T>? scope;
    if (listen) {
      scope = context
          .dependOnInheritedComponentOfExactType<_InheritedProviderScope<T>>();
    } else {
      final element = context
          .getElementForInheritedComponentOfExactType<
            _InheritedProviderScope<T>
          >();
      scope = element?.component as _InheritedProviderScope<T>?;
    }
    if (scope == null) {
      throw ProviderNotFoundException(T);
    }
    return scope.value;
  }

  @override
  Component build(BuildContext context) => _InheritedProviderScope<T>(
    value: value,
    child: child ?? const SizedBox.shrink(),
  );

  @override
  Component buildWithChild(BuildContext context, Component newChild) =>
      Provider<T>(value: value, child: newChild, key: key);
}

class _InheritedProviderScope<T> extends InheritedComponent {
  const _InheritedProviderScope({
    required this.value,
    required super.child,
  });

  final T value;

  @override
  bool updateShouldNotify(_InheritedProviderScope<T> oldComponent) =>
      value != oldComponent.value;
}

/// Thrown when a [Provider] lookup fails in the component tree.
class ProviderNotFoundException implements Exception {
  /// Creates an exception for missing [Provider] lookups.
  ProviderNotFoundException(this.valueType);

  /// The value type that failed to resolve from the component tree.
  final Type valueType;

  @override
  String toString() {
    return 'Provider<$valueType> not found in the component tree.';
  }
}
