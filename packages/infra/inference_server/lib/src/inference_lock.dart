import 'dart:io';

import 'package:local_inference_protocol/local_inference_protocol.dart';

/// The exclusive lock that keeps one server running per bestie directory.
/// The operating system drops it when the process dies, so a crashed server
/// never blocks the next one.
///
/// The lock covers a single sentinel byte far past the end of the file, not
/// the file's contents. Windows enforces byte-range locks on reads, so
/// locking the record itself would hide it from the clients that need it;
/// locking only the sentinel keeps the record readable everywhere while
/// every server still contends for the same byte.
final class InferenceLock {
  InferenceLock._(this._file);

  final RandomAccessFile _file;

  /// The sentinel byte every server locks.
  static const int sentinelStart = 1 << 40;

  static const int sentinelEnd = sentinelStart + 1;

  /// Takes the lock at [path] without waiting.
  static InferenceLockAcquisition acquire(String path) {
    final RandomAccessFile file;
    try {
      File(path).parent.createSync(recursive: true);
      file = File(path).openSync(mode: FileMode.append);
    } on FileSystemException catch (error) {
      return InferenceLockFailed(message: '${error.message}: $path');
    }
    try {
      file.lockSync(FileLock.exclusive, sentinelStart, sentinelEnd);
    } on FileSystemException {
      file.closeSync();
      return InferenceLockHeld(holder: _holderAt(path));
    }
    return InferenceLockAcquired(InferenceLock._(file));
  }

  /// The other server's record, or null when it cannot be read: the holder
  /// may not have written it yet, or the platform may refuse to read a locked
  /// file.
  static InferenceLockFile? _holderAt(String path) {
    try {
      return InferenceLockFileMapper.fromJson(File(path).readAsStringSync());
    } on Exception {
      return null;
    }
  }

  /// Records where this server listens, for clients to find it.
  void publish(InferenceLockFile holder) {
    _file
      ..truncateSync(0)
      ..setPositionSync(0)
      ..writeStringSync(holder.toJson())
      ..flushSync();
  }

  /// Gives the lock up. The last holder's record is left behind; the lock,
  /// not the record, says whether a server is running.
  void release() {
    _file
      ..unlockSync(sentinelStart, sentinelEnd)
      ..closeSync();
  }
}

sealed class InferenceLockAcquisition {
  const InferenceLockAcquisition();
}

final class InferenceLockAcquired extends InferenceLockAcquisition {
  const InferenceLockAcquired(this.lock);

  final InferenceLock lock;
}

/// Another server holds the lock.
final class InferenceLockHeld extends InferenceLockAcquisition {
  const InferenceLockHeld({required this.holder});

  /// Where the other server listens, or null when its record is unreadable.
  final InferenceLockFile? holder;
}

final class InferenceLockFailed extends InferenceLockAcquisition {
  const InferenceLockFailed({required this.message});

  final String message;
}
