import 'dart:io';

/// Minimal synchronous diagnostic logger for tracking down hard
/// crashes (native exits, signals) where async logging would be lost.
///
/// File is truncated on `init` so each run starts clean. Every write
/// is sync so bytes hit disk before the next instruction — survives
/// segfaults that bypass dispose chains.
///
/// Usage: call [Diagnostics.init] once at startup, then
/// [Diagnostics.log] from suspect call sites. Call [Diagnostics.close]
/// on graceful shutdown (a missed close is harmless — the file is
/// already flushed).
class Diagnostics {
  Diagnostics._();

  static RandomAccessFile? _file;

  /// Opens [path] for diagnostic writes. Truncates if it exists.
  /// No-op if the path can't be opened.
  static void init(String path) {
    try {
      _file = File(path).openSync(mode: FileMode.write);
      log('diagnostics', 'init path=$path pid=$pid');
    } on Object catch (_) {
      _file = null;
    }
  }

  /// Appends a single line: `[timestamp] rss=<MiB> tag detail`, then fsyncs so
  /// the entry survives a hard freeze/restart, not just a process exit.
  static void log(String tag, [String detail = '']) {
    final f = _file;
    if (f == null) return;
    final ts = DateTime.now().toIso8601String();
    final rss = ProcessInfo.currentRss ~/ (1024 * 1024);
    final line = detail.isEmpty
        ? '[$ts] rss=${rss}MiB $tag\n'
        : '[$ts] rss=${rss}MiB $tag $detail\n';
    try {
      f
        ..writeStringSync(line)
        ..flushSync();
    } on Object catch (_) {
      // Diagnostic must never throw.
    }
  }

  /// Closes the underlying file. Safe to call multiple times.
  static void close() {
    final f = _file;
    if (f == null) return;
    _file = null;
    try {
      f.closeSync();
    } on Object catch (_) {}
  }
}
