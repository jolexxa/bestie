/// Type of compute device exposed by llama.cpp.
enum LlamaDeviceType {
  /// CPU device using system memory.
  cpu,

  /// Discrete GPU with dedicated memory.
  gpu,

  /// Integrated GPU sharing host memory.
  integratedGpu,

  /// Accelerator such as BLAS or AMX.
  accelerator,

  /// Meta device for tensor parallelism.
  meta,
}

/// Memory and identity for a compute device reported by llama.cpp.
final class LlamaDeviceInfo {
  /// Creates a [LlamaDeviceInfo].
  const LlamaDeviceInfo({
    required this.name,
    required this.description,
    required this.type,
    required this.freeMemory,
    required this.totalMemory,
    this.deviceId,
  });

  /// Backend-internal device name.
  final String name;

  /// Human-readable device description.
  final String description;

  /// Device kind.
  final LlamaDeviceType type;

  /// Free memory in bytes.
  final int freeMemory;

  /// Total memory in bytes.
  final int totalMemory;

  /// Stable hardware identifier, when exposed by the backend.
  final String? deviceId;

  /// Convenience: `totalMemory - freeMemory`.
  int get usedMemory => totalMemory - freeMemory;
}
