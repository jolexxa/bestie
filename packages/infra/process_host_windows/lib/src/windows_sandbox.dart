import 'package:process_host/process_host.dart';

/// A confinement `CreateProcessW` attaches at creation, as a
/// `PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES` process attribute.
///
/// The host narrows the opaque [Sandbox] to exactly what *applying* it needs:
/// the AppContainer package SID the child runs as, plus the capability SIDs its
/// network tier grants. Both are SDDL strings (`S-1-15-…`), so the sandbox stays
/// a pure value the host rebuilds `SECURITY_CAPABILITIES` from at spawn — the
/// live profile and its ACLs are provisioned and owned by `sandbox_windows`.
abstract interface class WindowsSandbox implements Sandbox {
  /// The AppContainer package SID (SDDL) the child is confined to.
  String get containerSid;

  /// The capability SIDs (SDDL) the child is granted — e.g. `InternetClient`
  /// for the `all` network tier; empty for `none`/`local`.
  List<String> get capabilitySids;

  /// The directory the confined child starts in. It must be one the container
  /// can reach (the workspace): a process whose current directory is denied
  /// cannot spawn children — `CreateProcessW` fails with `ERROR_DIRECTORY`, so
  /// every external command in the shell would fail to launch.
  String get workingDirectory;

  /// The temp directory the confined child owns: the `AC\Temp` folder of its
  /// AppContainer profile, which the package SID can write without any grant.
  /// The user's own `%TEMP%` is not the container's to touch.
  String get tempDir;
}

/// The environment a child confined to a [WindowsSandbox] runs in.
extension WindowsSandboxEnvironment on WindowsSandbox {
  /// [host] with `TEMP` and `TMP` pointed at [tempDir]. Windows environment
  /// blocks are case-insensitive, so the host's spelling of either is dropped
  /// rather than left to race ours.
  Map<String, String> environmentFor(Map<String, String> host) => {
    for (final entry in host.entries)
      if (!_tempNames.contains(entry.key.toLowerCase())) entry.key: entry.value,
    'TEMP': tempDir,
    'TMP': tempDir,
  };

  static const _tempNames = {'temp', 'tmp'};
}
