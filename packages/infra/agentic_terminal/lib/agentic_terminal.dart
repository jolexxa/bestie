/// High-level API for driving interactive TUI programs from an
/// agent. Composes process_host, vt_parser, and terminal_screen.
library;

export 'package:process_host/process_host.dart'
    show
        ProcessExit,
        ProcessExited,
        ProcessHost,
        ProcessSignaled,
        ProcessSupervisorLost,
        ProcessUnknown,
        ShellLaunchMode,
        SpawnFailure;
export 'package:terminal_screen/terminal_screen.dart'
    show
        CellData,
        Color,
        CursorData,
        Screen,
        ScreenDiff,
        ScreenSnapshot,
        SelectionText;

export 'src/agent_terminal.dart' show AgentTerminal;
export 'src/host_input.dart'
    show
        HostInputParse,
        MouseButton,
        MouseEvent,
        MouseGestureRouter,
        decodeKittySequence,
        parseHostInput,
        stripMouseSequences;
export 'src/terminal_host.dart' show ProcessHostTerminalHost, TerminalHost;
export 'src/terminal_key.dart' show TerminalKey;
export 'src/terminal_spawn_result.dart'
    show TerminalSpawnFailed, TerminalSpawnResult, TerminalSpawnSucceeded;
