/// Bestie's shell domain: the installed shell userland, and the sessions run
/// against it.
library;

// A session's state answers with these, so reading one means naming them.
export 'package:agentic_terminal/agentic_terminal.dart'
    show
        ProcessExit,
        ProcessExited,
        ProcessSignaled,
        ProcessSupervisorLost,
        ProcessUnknown,
        SpawnFailure;

export 'src/session/recorded_shell.dart';
export 'src/session/shell_session.dart';
export 'src/session/shell_session_input.dart';
export 'src/session/shell_session_logic.dart';
export 'src/session/shell_session_output.dart';
export 'src/session/shell_session_request.dart';
export 'src/session/shell_session_summary.dart';
export 'src/session/shell_write_result.dart';
export 'src/session/terminal_surface.dart';
export 'src/session/transcript_page.dart';
export 'src/shell_repository.dart';
export 'src/userland/provision_result.dart';
export 'src/userland/shell_environment.dart';
export 'src/userland/shell_userland_repository.dart';
