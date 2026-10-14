/// The process exit codes the server ends with, so a client that only has
/// the code can still say what happened.
enum ServerExitCode {
  /// The server stopped the way servers stop; the owner session heard why.
  stopped(0, 'exited'),

  bindFailed(69, 'could not listen on loopback'),

  /// The engine could not start, or was lost while serving.
  engineFailed(70, 'lost its engine'),

  librariesMissing(72, 'could not find its llama.cpp libraries'),

  lockFailed(73, 'could not open its lock file'),

  /// Another server already runs for the bestie directory.
  alreadyRunning(75, 'found another server running');

  const ServerExitCode(this.code, this.meaning);

  final int code;

  /// What the server did, said of it: "the server [meaning]".
  final String meaning;

  /// The exit named by [code], or null when the server never ends with it.
  static ServerExitCode? of(int code) {
    for (final exit in values) {
      if (exit.code == code) return exit;
    }
    return null;
  }
}
