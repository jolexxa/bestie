/// The POSIX implementation of bestie's `process_host` contract.
library;

export 'src/posix_host_winsize_source.dart'
    show PosixHostWinsizeSource, SigwinchWatcher, defaultSigwinchWatcher;
export 'src/posix_process_host.dart' show PosixProcessHost;
export 'src/posix_running_process.dart' show PosixRunningProcess;
export 'src/posix_sandbox.dart' show PosixSandbox;
export 'src/wait_status.dart'
    show decodeWaitStatus, processExitFromOutcome, spawnFailureFrom;
