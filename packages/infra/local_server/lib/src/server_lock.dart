import 'dart:io';

import 'package:local_server_protocol/local_server_protocol.dart';

/// The exclusive lock that keeps one server running per bestie directory.
/// The operating system drops it when the process dies, so a crashed server
/// never blocks the next one.
///
/// The lock covers a single sentinel byte far past the end of the file, not
/// the file's contents. Windows enforces byte-range locks on reads, so
/// locking the record itself would hide it from the clients that need it;
/// locking only the sentinel keeps the record readable everywhere while
/// every server still contends for the same byte.
final class ServerLock {
  ServerLock._(this._file);

  final RandomAccessFile _file;

  /// The sentinel byte every server locks.
  static const int sentinelStart = 1 << 40;

  static const int sentinelEnd = sentinelStart + 1;

  /// Takes the lock at [path] without waiting.
  static ServerLockAcquisition acquire(String path) {
    final RandomAccessFile file;
    try {
      File(path).parent.createSync(recursive: true);
      file = File(path).openSync(mode: FileMode.append);
    } on FileSystemException catch (error) {
      return ServerLockOpenFailed(message: '${error.message}: $path');
    }
    try {
      file.lockSync(FileLock.exclusive, sentinelStart, sentinelEnd);
    } on FileSystemException {
      file.closeSync();
      return ServerLockHeld(holder: _holderAt(path));
    }
    return ServerLockAcquired(ServerLock._(file));
  }

  /// The other server's record, or null when it cannot be read: the holder
  /// may not have written it yet, or the platform may refuse to read a locked
  /// file.
  static ServerLockFile? _holderAt(String path) {
    try {
      return ServerLockFileMapper.fromJson(File(path).readAsStringSync());
    } on Exception {
      return null;
    }
  }

  /// Records where this server listens, for clients to find it.
  void publish(ServerLockFile holder) {
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

sealed class ServerLockAcquisition {
  const ServerLockAcquisition();
}

final class ServerLockAcquired extends ServerLockAcquisition {
  const ServerLockAcquired(this.lock);

  final ServerLock lock;
}

/// Another server holds the lock.
final class ServerLockHeld extends ServerLockAcquisition {
  const ServerLockHeld({required this.holder});

  /// Where the other server listens, or null when its record is unreadable.
  final ServerLockFile? holder;
}

final class ServerLockOpenFailed extends ServerLockAcquisition {
  const ServerLockOpenFailed({required this.message});

  final String message;
}
