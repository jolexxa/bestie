import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:posix_dart/src/bindings.dart';

/// Data carrier describing a failed libc call. Held by the `*Failed`
/// variant of every `posix_dart` operation result.
final class PosixFailure {
  const PosixFailure({
    required this.function,
    required this.errno,
    required this.message,
  });

  /// Construct a failure from a libc errno value; message is derived
  /// from `strerror(errno)` when not supplied.
  factory PosixFailure.fromErrno(
    String function,
    int errno, [
    String? message,
  ]) => PosixFailure(
    function: function,
    errno: errno,
    message: message ?? _strerror(errno),
  );

  /// Construct a failure with no associated errno (when a libc
  /// function returns a sentinel like NULL but doesn't set errno).
  factory PosixFailure.withoutErrno(String function, String message) =>
      PosixFailure(function: function, errno: 0, message: message);

  /// Name of the libc function that failed, e.g. `'posix_spawnp'`.
  final String function;

  /// The errno value reported by libc. Zero is reserved for "no
  /// errno set" — see [PosixFailure.withoutErrno].
  final int errno;

  /// Human-readable description (typically from `strerror`).
  final String message;

  @override
  String toString() => errno == 0
      ? 'PosixFailure($function): $message'
      : 'PosixFailure($function, errno=$errno): $message';

  static String _strerror(int errno) {
    if (errno == 0) return '';
    try {
      final ptr = posixBindings.strerror(errno);
      if (ptr == ffi.nullptr) return 'errno $errno';
      return ptr.cast<Utf8>().toDartString();
    } on Object {
      return 'errno $errno';
    }
  }
}
