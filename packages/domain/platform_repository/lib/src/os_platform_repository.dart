import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';

/// Repository facade over platform-specific external systems.
@repository
class OSPlatformRepository {
  OSPlatformRepository({
    required this.platform,
    required this.systemInfoDataSource,
    required this.clipboardDataSource,
    required this.diskSpaceDataSource,
    required this.terminalEnvironmentDataSource,
  });

  /// Pure platform configuration and resolved paths.
  final OSPlatform platform;

  final SystemInfoDataSource systemInfoDataSource;
  final ClipboardDataSource clipboardDataSource;
  final DiskSpaceDataSource diskSpaceDataSource;
  final TerminalEnvironmentDataSource terminalEnvironmentDataSource;

  /// Reads a fresh system-information snapshot.
  SystemInfoSnapshot readSystemInfo() => systemInfoDataSource.readSystemInfo();

  /// Copies [text] to the system clipboard.
  Future<void> copyToClipboard(String text) => clipboardDataSource.copy(text);

  /// Returns available bytes on the filesystem containing [path].
  int availableDiskSpaceBytes(String path) =>
      diskSpaceDataSource.availableBytes(path);

  /// See [TerminalEnvironmentDataSource.redirectStderr].
  TerminalOverride? redirectStderr({required String targetPath}) =>
      terminalEnvironmentDataSource.redirectStderr(targetPath: targetPath);

  /// See [TerminalEnvironmentDataSource.captureInput].
  TerminalOverride? captureInput(Set<InputCapture> groups) =>
      terminalEnvironmentDataSource.captureInput(groups);

  /// See [TerminalEnvironmentDataSource.setWindowTitle].
  TerminalOverride? setWindowTitle(String title) =>
      terminalEnvironmentDataSource.setWindowTitle(title);
}
