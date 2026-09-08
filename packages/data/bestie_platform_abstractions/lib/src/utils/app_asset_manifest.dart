import 'package:bestie_platform_abstractions/src/utils/app_asset.dart';
import 'package:intentions/intentions.dart';

/// Assets that ship on every platform.
@model
final class SharedAppAssets {
  const SharedAppAssets({
    required this.caCert,
    required this.credits,
    required this.shellBin,
  });

  /// The CA certificate bundle curl-impersonate verifies TLS peers against.
  final AppAsset caCert;

  /// The `CREDITS.md` attribution document shown on the config overlay's
  /// Credits page.
  final AppAsset credits;

  /// The confined shell userland's `bin/` (brush + the coreutils multicall).
  final AppAsset shellBin;

  /// Every shared asset, for composing each platform's bundle manifest.
  List<AppAsset> get all => [caCert, credits, shellBin];
}

/// The native assets a POSIX platform (macOS, Linux) resolves at runtime and
/// ships in its release bundle. macOS and Linux share this shape; only the
/// concrete library filenames differ.
@model
final class PosixAppAssets {
  const PosixAppAssets({
    required this.curl,
    required this.spawner,
    required this.editor,
    required this.shared,
  });

  final AppAsset curl;

  /// The PTY helper binary.
  final AppAsset spawner;

  /// The `bestie_edit` program behind the edit tool.
  final AppAsset editor;

  final SharedAppAssets shared;

  /// Every asset this platform ships — the single source of truth for both
  /// runtime resolution and release bundling.
  List<AppAsset> get bundleAssets => [curl, spawner, editor, ...shared.all];
}

/// The native assets Windows resolves at runtime and ships in its release
/// bundle.
@model
final class WindowsAppAssets {
  const WindowsAppAssets({
    required this.curl,
    required this.conptyLibrary,
    required this.consoleHostExecutable,
    required this.editor,
    required this.shared,
  });

  final AppAsset curl;

  /// Microsoft's redistributable ConPTY.
  final AppAsset conptyLibrary;

  /// The console host `conpty.dll` launches.
  final AppAsset consoleHostExecutable;

  /// The `bestie_edit` program behind the edit tool.
  final AppAsset editor;

  final SharedAppAssets shared;

  /// Every asset this platform ships — the single source of truth for both
  /// runtime resolution and release bundling.
  List<AppAsset> get bundleAssets => [
    curl,
    conptyLibrary,
    consoleHostExecutable,
    editor,
    ...shared.all,
  ];
}
