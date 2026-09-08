import 'package:bestie_platform_abstractions/src/models/shell_executables.dart';
import 'package:intentions/intentions.dart';

/// The confined agent shell's resolved userland: where its `bin/` lives plus
/// the platform-specific names its executables carry.
@model
class ShellUserland {
  const ShellUserland({
    required this.binDir,
    required this.shellPath,
    required this.executables,
  });

  /// Absolute path of the userland `bin/` directory.
  final String binDir;

  /// Absolute path of the shell bestie ships and runs.
  final String shellPath;

  /// The platform-specific names the userland's executables carry.
  final ShellExecutables executables;
}
