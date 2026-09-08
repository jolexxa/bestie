/// Outcome of disposing the whole provider (tearing down its runtime).
sealed class DisposeProviderResult {
  const DisposeProviderResult();
}

final class DisposeProviderSucceeded extends DisposeProviderResult {
  const DisposeProviderSucceeded();
}

final class DisposeProviderFailed extends DisposeProviderResult {
  const DisposeProviderFailed({required this.message});

  final String message;
}
