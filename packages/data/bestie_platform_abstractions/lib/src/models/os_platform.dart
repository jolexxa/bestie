import 'package:bestie_platform_abstractions/src/utils/platform_paths.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

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
  const OSPlatform({
    required this.os,
    required this.architecture,
    required this.homeDir,
    required this.tempDir,
    required this.bestieDir,
    required this.configFile,
    required this.conversationsDir,
    required this.curlLibraryPath,
    required this.caCertPath,
    required this.creditsPath,
  });

  final OSKind os;
  final OSArchitecture architecture;
  final String homeDir;

  /// The temporary directory processes on this host inherit — what `TMPDIR`
  /// (or `TMP`/`TEMP`) names, or the platform default when unset.
  final String tempDir;

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

  /// Path semantics of the OS this platform describes, not of the host.
  p.Context get _pathContext => os == OSKind.windows ? p.windows : p.posix;

  /// The per-run log directory and the individual sinks within it.
  String get logsDir => logsDirFor(bestieDir, _pathContext);

  /// Native fd-2 capture (FFI asserts, native library diagnostics).
  String get nativeLogFile => nativeLogFileFor(bestieDir, _pathContext);

  /// Managed Dart-side diagnostic breadcrumbs.
  String get managedLogFile => managedLogFileFor(bestieDir, _pathContext);

  /// Uncaught-error black box.
  String get crashLogFile => crashLogFileFor(bestieDir, _pathContext);

  /// The Windows sandbox grants document.
  String get sandboxesFile => sandboxesFileFor(bestieDir, _pathContext);

  /// Cached copy of the external model catalog.
  String get modelCatalogCacheFile =>
      modelCatalogCacheFileFor(bestieDir, _pathContext);
}

@model
class MacOSPlatform extends OSPlatform {
  const MacOSPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
  }) : super(os: OSKind.macos);
}

@model
class WindowsPlatform extends OSPlatform {
  const WindowsPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
  }) : super(os: OSKind.windows);
}

@model
class LinuxPlatform extends OSPlatform {
  const LinuxPlatform({
    required super.architecture,
    required super.homeDir,
    required super.tempDir,
    required super.bestieDir,
    required super.configFile,
    required super.conversationsDir,
    required super.curlLibraryPath,
    required super.caCertPath,
    required super.creditsPath,
  }) : super(os: OSKind.linux);
}
