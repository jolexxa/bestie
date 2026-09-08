import 'dart:ffi' as ffi;

/// Singleton wrapper around the libc `DynamicLibrary` handle for the
/// running process.
///
/// libc symbols are loaded into every Dart process on POSIX
/// (`libSystem.B.dylib` on macOS, `libc.so.6` on Linux), so
/// `DynamicLibrary.process()` is enough — no `DynamicLibrary.open`
/// with a path string is needed. Matches the precedent in
/// `bestie_platform_macos`'s `macos_system_info_data_source.dart:18,
/// 150, 154`.
class Libc {
  factory Libc() => _instance;
  Libc._() : _dylib = ffi.DynamicLibrary.process();

  static final Libc _instance = Libc._();

  final ffi.DynamicLibrary _dylib;

  /// The libc dynamic library handle. Use this when constructing a
  /// platform-specific bindings instance (e.g.
  /// `MacosPosixBindings(Libc().dylib)`).
  ffi.DynamicLibrary get dylib => _dylib;
}
