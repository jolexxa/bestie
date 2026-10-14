/// How people read sizes, counts and durations in the model panes.
library;

const int _giga = 1000 * 1000 * 1000;
const int _mega = 1000 * 1000;

/// `4.97 GB`, or `512 MB` below a gigabyte.
String bytesLabel(int bytes) => bytes >= _giga
    ? '${(bytes / _giga).toStringAsFixed(2)} GB'
    : '${(bytes / _mega).round()} MB';

/// `24 GB`, rounded to whole gigabytes.
String wholeGigabytesLabel(int bytes) => '${(bytes / _giga).round()} GB';

/// `48.3 MB/s`.
String speedLabel(double bytesPerSecond) =>
    '${(bytesPerSecond / _mega).toStringAsFixed(1)} MB/s';

/// `2.4M`, `988K` or `612`.
String countLabel(int count) => switch (count) {
  >= 1000000 => '${_short(count / 1000000)}M',
  >= 1000 => '${(count / 1000).round()}K',
  _ => '$count',
};

/// `7.5B`, `20.9B`, `106B`, or `350M` below a billion.
String parametersLabel(int parameters) => parameters >= 1000000000
    ? '${_short(parameters / 1000000000)}B'
    : '${(parameters / 1000000).round()}M';

/// `32,768`.
String groupedLabel(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// `128k`, for a context length.
String contextLabel(int tokens) => '${(tokens / 1024).round()}k';

/// `about 2 min left`.
String remainingLabel(Duration remaining) => switch (remaining.inMinutes) {
  < 1 => 'under a minute left',
  < 60 => 'about ${remaining.inMinutes} min left',
  _ =>
    'about ${remaining.inHours} h ${remaining.inMinutes.remainder(60)} min '
        'left',
};

/// One decimal below a hundred, none from a hundred up.
String _short(double value) =>
    value >= 100 ? '${value.round()}' : value.toStringAsFixed(1);
