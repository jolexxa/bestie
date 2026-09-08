import 'dart:io';

import 'package:posix_dart/src/bindings/linux_bindings.dart';
import 'package:posix_dart/src/bindings/macos_bindings.dart';
import 'package:posix_dart/src/bindings_adapters.dart';
import 'package:posix_dart/src/bindings_api.dart';
import 'package:posix_dart/src/libc.dart';

/// Runtime selector for the host's libc bindings.
///
/// ffigen emits `MacosPosixBindings` and `LinuxPosixBindings` as
/// unrelated classes with no shared supertype, so the adapters in
/// `bindings_adapters.dart` give them a common one. Wrappers in
/// `lib/src/` take the narrow interface they need (`FdBindings`,
/// `TermiosBindings`, …) and default to this, which is also what makes
/// them testable — a test passes a double instead.
///
/// Lazy: nothing resolves libc until the first call, so linking this
/// package on a platform that never uses it costs nothing.
final PosixBindings posixBindings = Platform.isMacOS
    ? MacosBindingsAdapter(MacosPosixBindings(Libc().dylib))
    : LinuxBindingsAdapter(LinuxPosixBindings(Libc().dylib));

/// Calls whose pointee types differ per platform. Each getter throws
/// [UnsupportedError] off its own platform rather than handing back
/// something that would fail at symbol lookup — the per-platform wrapper
/// classes in `system/` and `pty/` are the only callers, and each one
/// only ever reaches for its own.
LinuxStructBindings get linuxStructBindings => _require<LinuxStructBindings>();

/// See [linuxStructBindings].
MacosStructBindings get macosStructBindings => _require<MacosStructBindings>();

/// Darwin-only bindings (mach, sysctl). Linux has no portable equivalent.
DarwinBindings get darwinBindings => _require<DarwinBindings>();

T _require<T>() {
  final selected = posixBindings;
  if (selected is! T) {
    throw UnsupportedError(
      '$T is unavailable on ${Platform.operatingSystem}.',
    );
  }
  return selected as T;
}
