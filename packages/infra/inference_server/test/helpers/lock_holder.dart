import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Another process holding an inference lock, as a second server would.
final class LockHolder {
  LockHolder._(this._process, {required this.pid});

  final Process _process;

  /// The pid in the holder's record.
  final int pid;

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
    final words = line.split(' ');
    if (words.first != 'held') {
      throw StateError('The holder could not lock: $line');
    }
    return LockHolder._(process, pid: int.parse(words.last));
  }

  Future<void> release() async {
    await _process.stdin.close();
    await _process.exitCode;
  }
}
