import 'package:local_server_protocol/src/models/server_exit_code.dart';
import 'package:process_host/process_host.dart';

/// The name bestie shows for its local inference server.
const bestieServerName = 'Bestie Server';

/// Why this bestie can't use the server another bestie holds.
String bestieServerBusyMessage(int ownerPid) =>
    'Another bestie (pid $ownerPid) is using $bestieServerName. '
    'Close it to use it here.';

const _signals = {
  2: 'was interrupted (SIGINT)',
  6: 'aborted (SIGABRT)',
  9: 'was killed (SIGKILL)',
  11: 'crashed (SIGSEGV)',
  15: 'was terminated (SIGTERM)',
};

/// What the server did when its process ended with [exit], said of it:
/// "the server [bestieServerExitMessage]".
String bestieServerExitMessage(ProcessExit exit) => switch (exit) {
  ProcessSignaled(:final signal) =>
    _signals[signal] ?? 'ended by signal $signal',
  ProcessExited(:final code) =>
    ServerExitCode.of(code)?.meaning ?? 'exited with code $code',
  ProcessUnknown() => 'ended in a way bestie could not read',
  ProcessSupervisorLost() => 'ended without its exit being reported',
};
