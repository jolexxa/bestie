/// Platform-injected provider for hardware resource detection.
abstract interface class SystemInfoProvider {
  /// Number of logical CPU cores.
  int get logicalCoreCount;

  /// Total physical RAM in bytes.
  int get totalRamBytes;

  /// Available physical RAM in bytes.
  /// Returns 0 if unavailable.
  int get availableRamBytes;

  /// Whether this platform's GPU always shares system memory (e.g. Apple
  /// Silicon). A coarse platform-capability hint only; the authoritative
  /// unified-memory determination is derived from the backend device list once
  /// it is available (an integrated GPU shares host memory).
  bool get platformAlwaysUnified;
}
