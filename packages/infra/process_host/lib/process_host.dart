/// The platform-free process-spawning contract for bestie.
library;

export 'src/host_winsize_source.dart' show HostWinsizeSource;
export 'src/process_capture_result.dart'
    show
        ProcessCaptureCompleted,
        ProcessCaptureNotStarted,
        ProcessCaptureResult;
export 'src/process_exit.dart'
    show
        ProcessExit,
        ProcessExited,
        ProcessSignaled,
        ProcessSupervisorLost,
        ProcessUnknown;
export 'src/process_host.dart' show ProcessHost;
export 'src/process_run_result.dart'
    show ProcessRunCompleted, ProcessRunNotStarted, ProcessRunResult;
export 'src/process_runner.dart' show ProcessRunner;
export 'src/process_spawn_result.dart'
    show ProcessSpawnFailed, ProcessSpawnResult, ProcessSpawnSucceeded;
export 'src/running_process.dart' show RunningProcess;
export 'src/sandbox.dart' show Sandbox;
export 'src/shell_launch_mode.dart' show ShellLaunchMode;
export 'src/spawn_failure.dart' show SpawnFailure;
export 'src/winsize.dart'
    show
        Winsize,
        WinsizeReader,
        currentHostWinsize,
        defaultWinsizeReader,
        winsizeOf;
