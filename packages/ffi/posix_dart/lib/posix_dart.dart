/// posix_dart — bestie's single source of truth for libc FFI on POSIX.
///
/// Wraps a curated subset of POSIX (and Darwin / Linux specifics)
/// the bestie codebase needs end-to-end: termios manipulation, ioctl
/// resize, sysctl, mach, statvfs, fd helpers, and signal helpers. The
/// supervised-spawn PTY machinery that builds on these bindings lives
/// in `posix_spawner`.
///
/// Bindings are ffigen-generated against the host's system headers
/// (Xcode SDK on macOS, /usr/include on Linux), per-platform under
/// `lib/src/bindings/{macos,linux}_bindings.dart`. A runtime selector
/// picks the right binding at startup.
library;

export 'src/bindings.dart'
    show
        darwinBindings,
        linuxStructBindings,
        macosStructBindings,
        posixBindings;
export 'src/bindings_api.dart';
export 'src/constants.dart';
export 'src/fd.dart';
export 'src/libc.dart' show Libc;
export 'src/posix_failure.dart';
export 'src/pty/termios_helpers.dart';
export 'src/pty/winsize.dart';
export 'src/sizes.dart' show PosixSizes;
export 'src/system/env.dart';
export 'src/system/mach.dart';
export 'src/system/statvfs.dart';
export 'src/system/sysctl.dart';
