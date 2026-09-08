/// How the child shell should be launched.
enum ShellLaunchMode {
  /// A login shell, so it reads the host's profile.
  login,

  /// An interactive shell, so it reads the host's rc files but not its
  /// profile.
  interactive,

  /// An interactive login shell, so it reads the host's profile and rc files.
  interactiveLogin,

  /// The child's own arguments, with nothing prepended.
  raw;

  /// The flags this mode prepends before the child's own arguments.
  List<String> get flags => switch (this) {
    login => const ['-l'],
    interactive => const ['-i'],
    interactiveLogin => const ['-l', '-i'],
    raw => const [],
  };
}
