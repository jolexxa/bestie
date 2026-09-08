import 'dart:ffi';
import 'dart:io';

import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;

abstract final class PosixSizes {
  static int get termios =>
      Platform.isMacOS ? sizeOf<macos.termios>() : sizeOf<linux.termios>();

  /// macOS typedefs `posix_spawnattr_t` to `void *` (opaque handle);
  /// glibc inlines a struct.
  static int get posixSpawnattr => Platform.isMacOS
      ? sizeOf<Pointer<Void>>()
      : sizeOf<linux.posix_spawnattr_t>();

  static int get posixSpawnFileActions => Platform.isMacOS
      ? sizeOf<Pointer<Void>>()
      : sizeOf<linux.posix_spawn_file_actions_t>();

  /// Darwin `sigset_t` is `unsigned int`; glibc is a 128-byte bitset.
  static int get sigset => Platform.isMacOS
      ? sizeOf<UnsignedInt>()
      : sizeOf<linux.sigset_t_struct>();

  static int get winsize =>
      Platform.isMacOS ? sizeOf<macos.WinSize>() : sizeOf<linux.WinSize>();

  static int get sigaction =>
      Platform.isMacOS ? sizeOf<macos.sigaction>() : sizeOf<linux.sigaction>();
}
