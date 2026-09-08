import 'package:intentions/intentions.dart';

/// The platform-specific names the confined shell's executables carry, as two
/// canonical presets.
@model
class ShellExecutables {
  const ShellExecutables({
    required this.multicallName,
    required this.brushName,
    required this.linkExtension,
    required this.pathSeparator,
  });

  /// POSIX (macOS, Linux): bare names, no link suffix.
  static const posix = ShellExecutables(
    multicallName: 'coreutils',
    brushName: 'brush',
    linkExtension: '',
    pathSeparator: ':',
  );

  /// Windows: `.exe` executables and a matching link suffix.
  static const windows = ShellExecutables(
    multicallName: 'coreutils.exe',
    brushName: 'brush.exe',
    linkExtension: '.exe',
    pathSeparator: ';',
  );

  /// The coreutils multicall executable's name.
  final String multicallName;

  /// The confined shell (brush) executable's name.
  final String brushName;

  /// Suffix for per-utility dispatch link names.
  final String linkExtension;

  /// What separates entries in `PATH`.
  final String pathSeparator;
}
