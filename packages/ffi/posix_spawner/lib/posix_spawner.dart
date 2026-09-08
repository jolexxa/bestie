/// posix_spawner — bestie's supervised-spawn PTY machinery.
///
/// The native half is a tiny Rust `spawner` bootstrap (in `spawner/`,
/// built by `tool/build_spawner.dart`) that does the
/// fork+setsid+TIOCSCTTY+dup2+execve dance in pure native code, so the
/// Dart side can `posix_spawn` it kernel-level with no Dart in the
/// child. The Dart half drives it: `PosixSupervisedSpawn` sets up the
/// pty and launches the helper, `StatusChannel` speaks its status-pipe
/// wire protocol.
///
/// Layered on top of posix_dart's raw libc bindings — this package owns
/// the protocol, posix_dart owns the syscalls.
library;

export 'src/supervise/status_channel.dart';
export 'src/supervise/supervised_spawn.dart';
