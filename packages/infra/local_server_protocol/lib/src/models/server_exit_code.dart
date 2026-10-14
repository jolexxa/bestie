/// The process exit codes the server ends with, so a client that only has
/// the code can still say what happened.
enum ServerExitCode {
  /// The server stopped the way servers stop; the owner session heard why.
  stopped(0),

  /// It could not listen on loopback.
  bindFailed(69),

  /// The engine could not start, or was lost while serving.
  engineFailed(70),

  /// The native libraries the engine needs are missing.
  librariesMissing(72),

  /// The lock file could not be opened.
  lockFailed(73),

  /// Another server already runs for the bestie directory.
  alreadyRunning(75);

  const ServerExitCode(this.code);

  final int code;

  /// The exit named by [code], or null when the server never ends with it.
  static ServerExitCode? of(int code) {
    for (final exit in values) {
      if (exit.code == code) return exit;
    }
    return null;
  }
}
