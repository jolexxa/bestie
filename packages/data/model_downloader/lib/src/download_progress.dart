import 'package:intentions/intentions.dart';

@model
enum DownloadPhase { downloading, verifying }

/// How far along a whole job is.
@model
final class DownloadProgress {
  const DownloadProgress({
    required this.phase,
    required this.receivedBytes,
    required this.totalBytes,
    this.speedBytesPerSecond,
  });

  final DownloadPhase phase;

  /// Bytes received across every file in the job, including bytes kept from
  /// an earlier attempt.
  final int receivedBytes;

  final int totalBytes;

  /// Average speed of this attempt, or null before any time has passed.
  final double? speedBytesPerSecond;
}
