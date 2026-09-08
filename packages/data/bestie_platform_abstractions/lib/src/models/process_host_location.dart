import 'package:intentions/intentions.dart';

/// Where the mechanism that spawns supervised processes lives on this
/// platform: plain paths, so any isolate can build its own process host.
@model
sealed class ProcessHostLocation {
  const ProcessHostLocation();
}

/// POSIX spawns through the `spawner` helper binary.
@model
final class PosixProcessHostLocation extends ProcessHostLocation {
  const PosixProcessHostLocation({required this.spawnerBinaryPath});

  /// Absolute path of the `spawner` helper.
  final String spawnerBinaryPath;
}

/// Windows spawns through ConPTY.
@model
final class WindowsProcessHostLocation extends ProcessHostLocation {
  const WindowsProcessHostLocation({required this.conptyLibraryPath});

  /// Absolute path of `conpty.dll`.
  final String conptyLibraryPath;
}
