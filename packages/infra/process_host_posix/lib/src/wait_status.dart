import 'package:posix_dart/posix_dart.dart';
import 'package:posix_spawner/posix_spawner.dart';
import 'package:process_host/process_host.dart';

/// Decodes a raw POSIX `waitpid` status word into a [ProcessExit].
///
/// Follows the standard macros:
///
///   * `WIFEXITED(s)  == (s & 0x7f) == 0`
///   * `WEXITSTATUS(s) == (s >> 8) & 0xff`
///   * `WIFSIGNALED(s) == ((s & 0x7f) != 0) && ((s & 0x7f) != 0x7f)`
///   * `WTERMSIG(s)   == s & 0x7f`
ProcessExit decodeWaitStatus(int rawStatus) {
  final low7 = rawStatus & 0x7f;
  if (low7 == 0) {
    return ProcessExited((rawStatus >> 8) & 0xff);
  }
  if (low7 != 0x7f) {
    return ProcessSignaled(low7);
  }
  return const ProcessUnknown();
}

/// Maps a posix_dart supervisor [outcome] to a [ProcessExit]: a reported
/// status is decoded; a lost supervisor becomes [ProcessSupervisorLost].
ProcessExit processExitFromOutcome(PosixSupervisorOutcome outcome) =>
    switch (outcome) {
      PosixSupervisorExited(:final rawStatus) => decodeWaitStatus(rawStatus),
      PosixSupervisorLost() => const ProcessSupervisorLost(),
    };

/// Maps a posix_dart [failure] onto the platform-free [SpawnFailure]
/// the `process_host` contract speaks in.
SpawnFailure spawnFailureFrom(PosixFailure failure) => SpawnFailure(
  function: failure.function,
  message: failure.message,
  code: failure.errno,
);
