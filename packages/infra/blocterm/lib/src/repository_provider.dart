import 'package:blocterm/src/errors.dart';
import 'package:blocterm/src/provider.dart';
import 'package:nocterm/nocterm.dart';

/// A [Provider] flavor for repositories — domain objects whose value never
/// changes for the lifetime of the subtree.
///
/// `RepositoryProvider.of<T>` defaults to `listen: false` because repositories
/// are read-only from the view layer; callers do not want to rebuild when the
/// repository's internal state changes.
class RepositoryProvider<T> extends Provider<T> {
  /// Creates a [RepositoryProvider] that exposes [value] to descendants.
  ///
  /// [child] is optional so this provider composes cleanly inside a
  /// `MultiRepositoryProvider` — see [Provider] for the underlying mechanism.
  const RepositoryProvider.value({
    required super.value,
    super.child,
    super.key,
  });

  /// Retrieves the nearest [RepositoryProvider] of type [T].
  static T of<T>(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } on ProviderNotFoundException catch (e) {
      if (e.valueType != T) rethrow;
      throw RepositoryProviderNotFoundException(T);
    }
  }
}
