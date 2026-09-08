import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings_api.dart';

/// Wraps Darwin's `sysctlbyname(3)` for the keys bestie reads on macOS.
///
/// Linux does not have `sysctlbyname` in any portable form; the
/// methods on this class throw [UnsupportedError] on Linux. Callers
/// should branch on `Platform.isMacOS` before invoking.
class PosixSysctl {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  PosixSysctl({DarwinBindings? bindings}) : _b = bindings ?? darwinBindings;

  final DarwinBindings _b;

  /// Reads an Int64 sysctl. Returns `null` on failure (the C call
  /// returning non-zero).
  int? byNameInt64(String key) {
    final name = key.toNativeUtf8();
    final size = calloc<ffi.Size>();
    final value = calloc<ffi.Int64>();
    try {
      size.value = ffi.sizeOf<ffi.Int64>();
      final rc = _b.sysctlbyname(
        name.cast<ffi.Char>(),
        value.cast<ffi.Void>(),
        size,
        ffi.nullptr,
        0,
      );
      return rc == 0 ? value.value : null;
    } finally {
      calloc
        ..free(name)
        ..free(size)
        ..free(value);
    }
  }

  /// Reads an Int32 sysctl. Returns `null` on failure.
  int? byNameInt32(String key) {
    final name = key.toNativeUtf8();
    final size = calloc<ffi.Size>();
    final value = calloc<ffi.Int32>();
    try {
      size.value = ffi.sizeOf<ffi.Int32>();
      final rc = _b.sysctlbyname(
        name.cast<ffi.Char>(),
        value.cast<ffi.Void>(),
        size,
        ffi.nullptr,
        0,
      );
      return rc == 0 ? value.value : null;
    } finally {
      calloc
        ..free(name)
        ..free(size)
        ..free(value);
    }
  }

  /// Reads a string-typed sysctl (probes size, then reads). Returns
  /// `null` on failure.
  String? byNameString(String key, {int maxBytes = 1024}) {
    final name = key.toNativeUtf8();
    final size = calloc<ffi.Size>();
    final buf = calloc<ffi.Uint8>(maxBytes);
    try {
      size.value = maxBytes;
      final rc = _b.sysctlbyname(
        name.cast<ffi.Char>(),
        buf.cast<ffi.Void>(),
        size,
        ffi.nullptr,
        0,
      );
      if (rc != 0) return null;
      return buf.cast<Utf8>().toDartString(length: size.value - 1);
    } finally {
      calloc
        ..free(name)
        ..free(size)
        ..free(buf);
    }
  }
}

/// [PosixSysctl] over the host's libc.
final PosixSysctl posixSysctl = PosixSysctl();
