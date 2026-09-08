import 'package:blocterm/blocterm.dart';

/// Thrown when a [BlocProvider] lookup fails in the component tree.
class BlocProviderNotFoundException implements Exception {
  /// Creates an exception for missing [BlocProvider] lookups.
  BlocProviderNotFoundException(this.type);

  /// The bloc type that failed to resolve from the component tree.
  final Type type;

  @override
  String toString() {
    return 'BlocProvider<$type> not found in the component tree.';
  }
}

/// Thrown when a [RepositoryProvider] lookup fails in the component tree.
class RepositoryProviderNotFoundException implements Exception {
  /// Creates an exception for missing [RepositoryProvider] lookups.
  RepositoryProviderNotFoundException(this.type);

  /// The repository type that failed to resolve from the component tree.
  final Type type;

  @override
  String toString() {
    return 'RepositoryProvider<$type> not found in the component tree. '
        'Wrap a parent component in RepositoryProvider<$type> or pass the '
        'repository explicitly.';
  }
}
