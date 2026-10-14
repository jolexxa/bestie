import 'package:intentions/intentions.dart';
import 'package:path_plus/path_plus.dart';

/// The platform-shaped policy a `SandboxSpec` is built from: which system
/// trees a confined program may read and write, whether it reads the home
/// directory and writes the temp directory, and the secrets carved out of
/// that home grant — dotfile credentials and Bestie's own config, which holds
/// the provider API keys.
@model
class SandboxPlatformModel {
  /// Wraps the [systemReadRoots] and [systemWriteRoots], whether the model
  /// [includesHome] and [includesTemp], and the home-relative
  /// [secretHomePaths].
  const SandboxPlatformModel({
    required this.systemReadRoots,
    required this.systemWriteRoots,
    required this.includesHome,
    required this.includesTemp,
    required this.secretHomePaths,
  });

  /// POSIX: the broad system trees a real binary loads from are readable, and
  /// home is readable minus a small set of dotfile secrets. `/tmp` and the
  /// process's own temp directory are writable, since build tools, package
  /// managers, and the Xcode `git` shim all stage files there.
  static const posix = SandboxPlatformModel(
    systemReadRoots: [
      '/usr',
      '/bin',
      '/sbin',
      '/System',
      '/Library',
      '/dev',
      '/private',
      '/var',
      '/etc',
      '/opt',
    ],
    systemWriteRoots: ['/tmp'],
    includesHome: true,
    includesTemp: true,
    secretHomePaths: [
      '.ssh',
      '.aws',
      '.gnupg',
      '.config/gh',
      '.bestie/bestie.json',
    ],
  );

  /// Windows: system trees are already readable via `ALL APPLICATION PACKAGES`,
  /// so none are listed. Home is a broad read root carved of the same secrets
  /// as POSIX plus the Windows credential stores. The broad grant is applied
  /// once to a shared capability, not per launch (see
  /// `SandboxRepositoryForWindows`). Temp needs no grant: an AppContainer
  /// owns a temp folder of its own, and the Windows backend points the
  /// child's `TEMP` at it rather than opening the user's.
  static const windows = SandboxPlatformModel(
    systemReadRoots: [],
    systemWriteRoots: [],
    includesHome: true,
    includesTemp: false,
    secretHomePaths: [
      '.ssh',
      '.aws',
      '.gnupg',
      '.config/gh',
      '.bestie/bestie.json',
      '.azure',
      'AppData/Roaming/gcloud',
      'AppData/Roaming/Microsoft/Credentials',
      'AppData/Local/Microsoft/Credentials',
    ],
  );

  /// System trees granted read directly.
  final List<String> systemReadRoots;

  /// System trees granted write, beyond the workspace.
  final List<String> systemWriteRoots;

  /// Whether the home directory is a readable root.
  final bool includesHome;

  /// Whether the process's temp directory is a writable root.
  final bool includesTemp;

  /// Home-relative secrets carved out of the home read grant, written with
  /// `/`.
  final List<String> secretHomePaths;

  /// The home directory as a readable root, or empty when home is not granted.
  List<String> homeReadRoots(UserPaths paths) =>
      includesHome ? [paths.homeDir] : const [];

  /// The temp directory as a writable root, or empty when temp is not granted.
  List<String> tempWriteRoots(String tempDir) =>
      includesTemp ? [tempDir] : const [];

  /// The concrete secret paths to deny under the user's home.
  List<String> deniedReadsFor(UserPaths paths) => [
    for (final secret in secretHomePaths) paths.underHome(secret),
  ];
}
