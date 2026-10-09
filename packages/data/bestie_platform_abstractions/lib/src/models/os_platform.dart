import 'package:bestie_platform_abstractions/src/models/program_command.dart';
import 'package:bestie_platform_abstractions/src/utils/platform_paths.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:path_plus/path_plus.dart';

/// Supported operating systems for Bestie.
enum OSKind { macos, linux, windows }

/// Supported host architectures for Bestie.
enum OSArchitecture { macosArm64, linuxX64, windowsX64 }

/// Pure platform configuration and resolved runtime paths.
///
/// Abstract — concrete platforms live alongside in [MacOSPlatform] /
/// [LinuxPlatform] and own their own derivations.
@model
abstract class OSPlatform {
  OSPlatform({
    required this.os,
    required this.architecture,
    required this.homeDir,
    required this.tempDir,
    required this.workingDirectory,
    required this.bestieDir,
    required this.configFile,
    required this.conversationsDir,
    required this.curlLibraryPath,
    required this.caCertPath,
    required this.creditsPath,
    required this.serverExecutable,
  }) : paths = UserPaths(homeDir: homeDir, context: _contextOf(os));

  final OSKind os;
  final OSArchitecture architecture;
  final String homeDir;

  /// Paths as the user writes them on the OS this platform describes, not on
  /// the host.
  final UserPaths paths;

  static p.Context _contextOf(OSKind os) =>
      os == OSKind.windows ? p.windows : p.posix;

  p.Context get _context => _contextOf(os);

  /// The temporary directory processes on this host inherit — what `TMPDIR`
  /// (or `TMP`/`TEMP`) names, or the platform default when unset.
  final String tempDir;

  /// The directory Bestie was started in, followed through any symlinks so
  /// every part of the app spells it the same way.
  final String workingDirectory;

  final String bestieDir;
  final String configFile;
  final String conversationsDir;
  final String curlLibraryPath;

  /// Absolute path to the bundled CA certificate bundle (cacert.pem) that
  /// curl-impersonate verifies TLS peers against.
  final String caCertPath;

  /// Absolute path to the bundled `CREDITS.md` attribution document shown
  /// on the config overlay's Credits page.
  final String creditsPath;

  /// How to start the local inference server.
  final ProgramCommand serverExecutable;

  /// The per-run log directory and the individual sinks within it.
  String get logsDir => logsDirFor(bestieDir, _context);

  /// Native fd-2 capture (FFI asserts, native library diagnostics).
  String get nativeLogFile => nativeLogFileFor(bestieDir, _context);

  /// Managed Dart-side diagnostic breadcrumbs.
  String get managedLogFile => managedLogFileFor(bestieDir, _context);

  /// Uncaught-error black box.
  String get crashLogFile => crashLogFileFor(bestieDir, _context);

  /// The Windows sandbox grants document.
  String get sandboxesFile => sandboxesFileFor(bestieDir, _context);

  /// Cached copy of the external model catalog.
  String get modelCatalogCacheFile =>
      modelCatalogCacheFileFor(bestieDir, _context);

  /// Downloaded models and the model index.
  String get modelsDir => modelsDirFor(bestieDir, _context);

  /// Files running helper processes leave for bestie.
  String get runDir => runDirFor(bestieDir, _context);

  /// Where the running local inference server says which port it serves.
  String get inferenceLockFile => inferenceLockFileFor(bestieDir, _context);

  /// The local inference server's log.
  String get serverLogFile => serverLogFileFor(bestieDir, _context);
}

@model
class MacOSPlatform extends OSPlatform {
  MacOSPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.workingDirectory,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
    required super.serverExecutable,
  }) : super(os: OSKind.macos);
}

@model
class WindowsPlatform extends OSPlatform {
  WindowsPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.workingDirectory,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
    required super.serverExecutable,
  }) : super(os: OSKind.windows);
}

@model
class LinuxPlatform extends OSPlatform {
  LinuxPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.workingDirectory,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
    required super.serverExecutable,
  }) : super(os: OSKind.linux);
}
