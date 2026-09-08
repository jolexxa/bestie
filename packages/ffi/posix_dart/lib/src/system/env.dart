import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:posix_dart/src/libc.dart';

/// Thin wrapper over libc `setenv(3)` / `getenv(3)`.
///
/// Dart's `Platform.environment` is a cached snapshot and cannot mutate the C
/// environment, so FFI is required when a native dependency reads env vars at
/// runtime.
abstract final class PosixEnv {
  static final int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int) _setenv =
      Libc().dylib.lookupFunction<
        ffi.Int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int),
        int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int)
      >('setenv');

  static final ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>) _getenv = Libc()
      .dylib
      .lookupFunction<
        ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)
      >('getenv');

  /// Sets `name=value` in the process environment. Returns 0 on success. When
  /// [overwrite] is false, an already-set variable is left untouched.
  static int setenv(String name, String value, {bool overwrite = true}) {
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      return _setenv(namePtr, valuePtr, overwrite ? 1 : 0);
    } finally {
      calloc
        ..free(namePtr)
        ..free(valuePtr);
    }
  }

  /// Reads [name] from the process environment, or null when unset. The
  /// returned pointer is owned by libc and must not be freed.
  static String? getenv(String name) {
    final namePtr = name.toNativeUtf8();
    try {
      final value = _getenv(namePtr);
      return value == ffi.nullptr ? null : value.toDartString();
    } finally {
      calloc.free(namePtr);
    }
  }
}
