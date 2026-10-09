import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Another process holding an inference lock, as a second server would.
final class LockHolder {
  LockHolder._(this._process);

  final Process _process;

  static Future<LockHolder> hold(String path, {bool silent = false}) async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/helpers/hold_lock.dart',
      path,
      if (silent) '--silent',
    ]);
    final line = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    if (line != 'held') throw StateError('The holder could not lock: $line');
    return LockHolder._(process);
  }

  int get pid => _process.pid;

  Future<void> release() async {
    await _process.stdin.close();
    await _process.exitCode;
  }
}
