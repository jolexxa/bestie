import 'package:meta/meta.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';

/// Whether a provider can serve models right now, as its own feature has
/// configured it.
@immutable
sealed class ProviderAvailability {
  const ProviderAvailability();
}

/// The provider has what it needs to list and load models.
final class ProviderReady extends ProviderAvailability {
  const ProviderReady();

  @override
  bool operator ==(Object other) => other is ProviderReady;

  @override
  int get hashCode => (ProviderReady).hashCode;

  @override
  String toString() => 'ProviderReady()';
}

/// The provider still needs something from the user; loading one of its
/// models fails with [failure] until it has it.
final class ProviderNotSetUp extends ProviderAvailability {
  const ProviderNotSetUp(this.failure);

  final ProviderFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ProviderNotSetUp && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'ProviderNotSetUp($failure)';
}
