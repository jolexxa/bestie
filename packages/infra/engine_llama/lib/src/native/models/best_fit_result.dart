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
    required this.devices,
    required this.nIterations,
    this.errorMessage = '',
  });

  /// Native prediction status.
  final BestFitStatus status;

  /// Whether the native predictor found a fitting context size.
  bool get fits => status == BestFitStatus.success;

  /// Largest fitting context size chosen by the native predictor.
  final int chosenContextSize;

  /// Predicted memory per device at the chosen context, the host last.
  final List<BestFitDeviceUsage> devices;

  /// Predicted bytes used across every device.
  int get usedBytes => devices.fold(0, (sum, device) => sum + device.usedBytes);

  /// Number of native search iterations.
  final int nIterations;

  /// Native error message, when available.
  final String errorMessage;
}

/// Predicted memory for one device at the chosen context.
final class BestFitDeviceUsage {
  /// Creates a device usage prediction.
  const BestFitDeviceUsage({
    required this.name,
    required this.usedBytes,
    required this.freeBytes,
    required this.totalBytes,
  });

  /// Device name reported by the native predictor.
  final String name;

  /// Predicted bytes the model and context use on this device.
  final int usedBytes;

  /// Free bytes the device reported before loading.
  final int freeBytes;

  /// Total bytes the device reported.
  final int totalBytes;
}
