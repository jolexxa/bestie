import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:shell_repository/src/userland/shell_environment.dart';

/// Everything needed to bring up one shell session: what to run, how to launch
/// it, and the dimensions its screen starts at.
@model
final class ShellSessionRequest {
  const ShellSessionRequest({
    required this.rows,
    required this.cols,
    required this.scrollbackBytes,
    required this.environment,
    this.executable,
    this.arguments = const [],
    this.launchMode = ShellLaunchMode.login,
    this.forwardHostResize = true,
    this.sandbox,
  });

  /// A shell the user drives, running the shell [environment] describes.
  factory ShellSessionRequest.userShell({
    required ShellEnvironment environment,
    required int rows,
    required int cols,
    required int scrollbackBytes,
  }) => ShellSessionRequest(
    rows: rows,
    cols: cols,
    scrollbackBytes: scrollbackBytes,
    executable: environment.shellPath,
    environment: environment.forUserShell(),
    launchMode: ShellLaunchMode.interactive,
    forwardHostResize: false,
  );

  /// A shell an agent drives, running [command] through the shell
  /// [environment] describes, confined by [sandbox] if one is given.
  factory ShellSessionRequest.agentShell({
    required ShellEnvironment environment,
    required String command,
    required int rows,
    required int cols,
    required int scrollbackBytes,
    Sandbox? sandbox,
  }) => ShellSessionRequest(
    rows: rows,
    cols: cols,
    scrollbackBytes: scrollbackBytes,
    executable: environment.shellPath,
    environment: environment.forAgentShell(),
    arguments: ['-c', command],
    launchMode: ShellLaunchMode.raw,
    forwardHostResize: false,
    sandbox: sandbox,
  );

  /// Executable to run. Null asks the platform for its own default, which
  /// only POSIX has — bestie names its bundled shell instead.
  final String? executable;

  /// Arguments passed to [executable].
  final List<String> arguments;

  /// The child's environment.
  final Map<String, String> environment;

  /// How the shell itself is launched — login, interactive, or raw.
  final ShellLaunchMode launchMode;

  /// Rows the screen starts at.
  final int rows;

  /// Columns the screen starts at.
  final int cols;

  /// How many lines of scrollback the screen retains.
  final int scrollbackBytes;

  /// Whether the host terminal's resizes are forwarded to the child.
  final bool forwardHostResize;

  /// Confines the child to the host platform's sandbox, or unconfined if null.
  final Sandbox? sandbox;
}
