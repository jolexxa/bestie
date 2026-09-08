import 'package:intentions/intentions.dart';

/// A used/total memory stat with a percentage for color coding.
@model
class MemoryStat {
  const MemoryStat({
    required this.usedBytes,
    required this.totalBytes,
    required this.availablePercent,
  });

  final int usedBytes;
  final int totalBytes;

  /// Available memory as a percentage (0–100). Drives color coding:
  /// high = green, low = red.
  final int availablePercent;
}
