import 'package:path/path.dart' as p;

/// Resolves the current user's home directory from [environment].
String resolveHomeDir(Map<String, String> environment) {
  final home =
      _setIn(environment, 'HOME') ?? _setIn(environment, 'USERPROFILE');
  if (home == null) throw StateError('Unable to resolve user home directory.');
  return home;
}

/// Resolves the temporary directory a POSIX process inherits from
/// [environment]: `TMPDIR`, else `/tmp`. macOS ends `TMPDIR` with a slash;
/// the result never does.
String resolvePosixTempDir(Map<String, String> environment) =>
    p.posix.normalize(_setIn(environment, 'TMPDIR') ?? '/tmp');

/// Resolves the temporary directory a Windows process inherits from
/// [environment] the way `GetTempPath` does: `TMP`, then `TEMP`, else the
/// local application data temp under [homeDir].
String resolveWindowsTempDir(
  Map<String, String> environment, {
  required String homeDir,
}) => p.windows.normalize(
  _setIn(environment, 'TMP') ??
      _setIn(environment, 'TEMP') ??
      p.windows.join(homeDir, 'AppData', 'Local', 'Temp'),
);

/// The value of [name] in [environment], treating an empty variable as unset:
/// joining paths onto it would silently produce a relative path rooted at the
/// process's cwd.
String? _setIn(Map<String, String> environment, String name) {
  final value = environment[name];
  return value != null && value.isNotEmpty ? value : null;
}

String bestieDirFor(String homeDir, p.Context context) =>
    context.join(homeDir, '.bestie');
String configFileFor(String bestieDir, p.Context context) =>
    context.join(bestieDir, 'bestie.json');
String conversationsDirFor(String bestieDir, p.Context context) =>
    context.join(bestieDir, 'conversations');

/// The Windows sandbox grants document.
String sandboxesFileFor(String bestieDir, p.Context context) =>
    context.join(bestieDir, 'sandboxes.json');

/// Cached copy of the external model catalog.
String modelCatalogCacheFileFor(String bestieDir, p.Context context) =>
    context.join(bestieDir, 'cache', 'models_dev.json');

/// Directory holding every per-run log file (native stderr capture +
/// managed Dart-side diag). Truncated by each consumer on open.
String logsDirFor(String bestieDir, p.Context context) =>
    context.join(bestieDir, 'logs');

/// Native-stderr capture file. fd 2 (native library panics, FFI asserts) is
/// redirected here for the lifetime of every bestie run; the file is
/// truncated on each open so it only ever holds the most recent run's
/// noise.
String nativeLogFileFor(String bestieDir, p.Context context) =>
    context.join(logsDirFor(bestieDir, context), 'native.log');

/// Managed Dart-side diagnostic log (see `diagnostics`'s `Diagnostics`). Sync
/// writes so breadcrumbs survive segfaults / hard exits that bypass
/// dispose chains. Truncated on init each run.
String managedLogFileFor(String bestieDir, p.Context context) =>
    context.join(logsDirFor(bestieDir, context), 'managed.log');

/// Uncaught-error black box.
String crashLogFileFor(String bestieDir, p.Context context) =>
    context.join(logsDirFor(bestieDir, context), 'crash.log');
