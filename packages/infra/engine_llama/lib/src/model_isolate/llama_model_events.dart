/// Something the model worker reports about a request while it is in flight.
sealed class LlamaModelEvent {
  const LlamaModelEvent({required this.requestId});

  /// The request this event belongs to.
  final int requestId;
}

/// A model load advanced.
final class LlamaModelLoadProgressed extends LlamaModelEvent {
  const LlamaModelLoadProgressed({
    required super.requestId,
    required this.fraction,
  });

  /// Load completion in `[0.0, 1.0]`.
  final double fraction;
}
