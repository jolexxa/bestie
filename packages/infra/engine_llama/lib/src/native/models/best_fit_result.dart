/// Native best_fit prediction status.
enum BestFitStatus {
  /// The requested context fits.
  success,

  /// The requested context does not fit available memory.
  failure,

  /// The native predictor failed before it could produce a fit result.
  error,
}

/// Result for maximum fitting context-size prediction.
final class BestFitMaxContextResult {
  /// Creates a max-context fit result.
  const BestFitMaxContextResult({
    required this.status,
    required this.chosenContextSize,
    required this.usedBytes,
    required this.freeBytes,
    required this.totalBytes,
    required this.nIterations,
    this.errorMessage = '',
  });

  /// Native prediction status.
  final BestFitStatus status;

  /// Whether the native predictor found a fitting context size.
  bool get fits => status == BestFitStatus.success;

  /// Largest fitting context size chosen by the native predictor.
  final int chosenContextSize;

  /// Predicted bytes used by the loaded model and chosen context.
  final int usedBytes;

  /// Free bytes reported by the native predictor.
  final int freeBytes;

  /// Total bytes reported by the native predictor.
  final int totalBytes;

  /// Number of native search iterations.
  final int nIterations;

  /// Native error message, when available.
  final String errorMessage;
}
