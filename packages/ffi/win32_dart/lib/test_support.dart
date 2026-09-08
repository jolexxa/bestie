import 'dart:io';
import 'dart:isolate';

import 'package:meta/meta.dart';

/// Locates the repo-downloaded console host for the tests that drive a real
/// pseudoconsole — win32_dart's own and process_host_windows' live spawns.
/// win32_dart owns `conpty.dll`, so it owns the lookup.
///
/// The asset directory is resolved from the running isolate's package config
/// (`Isolate.resolvePackageUri`), so it is correct from any working directory
/// and encodes no assumption about where a consumer package sits in the tree.
///
/// Production never uses this: bestie resolves the console host as an
/// `AppAsset` and injects the path into `WindowsProcessHost`
/// (`conptyLibraryPath:`). Kept off the main barrel — reach it via
/// `package:win32_dart/test_support.dart` — so it can't be mistaken for library
/// API. `tool/download_openconsole_assets.dart` installs the binaries into this
/// package's `assets/native/windows/x64/` directory — the only architecture
/// bestie runs on Windows.
@visibleForTesting
class RepoConsoleHostLocator {
  /// Creates a locator.
  const RepoConsoleHostLocator();

  /// Returns the absolute `conpty.dll` path, or null when it has not been
  /// downloaded, when the `OpenConsole.exe` it launches is not beside it, or
  /// when the package can't be resolved (e.g. an AOT binary with no package
  /// config).
  ///
  /// A library without its console host resolves to null rather than to the
  /// library: on its own it silently falls back to the `conhost.exe` Windows
  /// came with, which is the behaviour shipping one exists to replace.
  Future<String?> locate() async {
    final libRoot = await Isolate.resolvePackageUri(
      Uri.parse('package:win32_dart/'),
    );
    if (libRoot == null) return null;

    final assets = libRoot.resolve('../assets/native/windows/x64/');
    final library = assets.resolve('conpty.dll').toFilePath();
    final host = assets.resolve('OpenConsole.exe').toFilePath();
    if (!File(library).existsSync() || !File(host).existsSync()) return null;
    return library;
  }
}
