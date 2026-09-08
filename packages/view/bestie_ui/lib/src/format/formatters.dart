import 'package:humanizer/humanizer.dart';

// humanizer renders binary magnitudes (powers of 1024) with IEC symbols by
// default. We keep the binary math but drop the "i" from the symbol so sizes
// read as KB/MB/GB — the labels desktop users expect — rather than KiB/MiB/GiB.
// The `0.## u` pattern spaces the number from the symbol; the rate is pinned to
// per-second so speeds never drift to /min.
final _sizeFormat = InformationSizeFormat(pattern: '0.## u');
final _sizeFormatConcise = InformationSizeFormat(pattern: '0.# u');

final _rateFormat = InformationRateFormat(
  pattern: "0.## u'/'r",
  permissibleRateUnits: const {RateUnit.second},
);

const _oneSecond = Duration(seconds: 1);

/// Rewrites IEC byte symbols (KiB, MiB, GiB…) to their decimal-looking
/// counterparts (KB, MB, GB…) while leaving the binary magnitude untouched.
String _desktopSymbols(String formatted) => formatted.replaceAll('iB', 'B');

/// Formats byte counts and transfer rates using binary magnitudes, so every
/// size the app shows lives in the same power-of-two ruler as the RAM and
/// VRAM it is compared against.
extension ByteSizeFormatting on int {
  /// Formats this byte count as a human-readable size, e.g. `"4.1 GB"`.
  String get asByteSize => _desktopSymbols(_sizeFormat.format(bytes()));

  /// Formats this byte count as a human-readable size, e.g. `"4.1 GB"`.
  String get asByteSizeConcise =>
      _desktopSymbols(_sizeFormatConcise.format(bytes()));
}

extension ByteRangeFormatting on Iterable<int> {
  /// Formats these byte counts as a single size or a `min-max` span,
  /// e.g. `"1 KB-2 KB"`. Empty input reads `"unknown size"`.
  String get asByteSizeRange {
    final sorted = toList()..sort();
    if (sorted.isEmpty) return 'unknown size';
    final min = sorted.first;
    final max = sorted.last;
    if (min == max) return min.asByteSize;
    return '${min.asByteSize}-${max.asByteSize}';
  }
}

extension ByteRateFormatting on num {
  /// Formats this bytes-per-second rate as a transfer speed,
  /// e.g. `"12.5 MB/s"`.
  String get asByteRate =>
      _desktopSymbols(_rateFormat.format(round().bytes().per(_oneSecond)));
}

/// Compact duration label for a count of milliseconds.
extension MillisFormatting on num {
  /// `< 1000` → `"350ms"`, `>= 1000` → `"1.2s"`.
  String get asDuration {
    if (this < 1000) return '${round()}ms';
    return '${(this / 1000).toStringAsFixed(1)}s';
  }
}

/// Compact clock label for a timestamp.
extension ClockFormatting on DateTime {
  /// Formats as a 12-hour time, e.g. `"3:45 PM"`.
  String get as12HourTime {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

/// Formats a download progress label like `"Downloading...1.2 GB (30%)"`.
String formatDownloadLabel({
  required int receivedBytes,
  required int totalBytes,
}) {
  final percent = totalBytes > 0
      ? (receivedBytes * 100 ~/ totalBytes).clamp(0, 100)
      : 0;
  return '${receivedBytes.asByteSize} ($percent%)';
}

/// Compact and grouped string forms of an integer count.
extension CountFormatting on int {
  /// Compact human count, e.g. `"1.5M"`, `"500.0k"`, `"42"`.
  String get asCompactCount {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}k';
    return toString();
  }

  /// Model parameter count, e.g. `"20B"`, `"1.5B"`, `"500M"`, `"8B"`.
  /// Scales into billions so large models don't read as thousands of
  /// millions (e.g. `"20B"`, not `"20914.8M"`). A trailing `.0` is
  /// trimmed so round counts stay clean.
  String get asParamCount {
    String scale(double value, String suffix) {
      final fixed = value.toStringAsFixed(1);
      final trimmed = fixed.endsWith('.0')
          ? fixed.substring(0, fixed.length - 2)
          : fixed;
      return '$trimmed$suffix';
    }

    if (this >= 1000000000) return scale(this / 1000000000, 'B');
    if (this >= 1000000) return scale(this / 1000000, 'M');
    if (this >= 1000) return scale(this / 1000, 'k');
    return toString();
  }

  /// Compact token count, e.g. `"128k"`, `"1.5M"`, `"512"`.
  String get asCompactTokens {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${this ~/ 1000}k';
    return toString();
  }

  /// This number with comma thousands separators, e.g. `"1,234,567"`.
  String get withCommas {
    final s = toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Ellipsis truncation for display strings.
extension TruncateFormatting on String {
  /// Truncates to [maxLength] characters, appending an ellipsis when longer.
  String truncate({int maxLength = 64}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }
}
