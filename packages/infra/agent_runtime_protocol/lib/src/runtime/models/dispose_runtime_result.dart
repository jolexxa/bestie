/// Outcome of disposing the whole runtime.
sealed class DisposeRuntimeResult {
  const DisposeRuntimeResult();
}

final class DisposeRuntimeSucceeded extends DisposeRuntimeResult {
  const DisposeRuntimeSucceeded();
}

final class DisposeRuntimeFailed extends DisposeRuntimeResult {
  const DisposeRuntimeFailed({required this.message});

  final String message;
}
