import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:process_host_windows/process_host_windows.dart';

/// The process host for [location], built the same way wherever one is
/// needed: at the composition root, and again inside each tool worker.
ProcessHost buildProcessHost(ProcessHostLocation location) =>
    switch (location) {
      PosixProcessHostLocation(:final spawnerBinaryPath) => PosixProcessHost(
        spawnerBinaryPath: spawnerBinaryPath,
      ),
      WindowsProcessHostLocation(:final conptyLibraryPath) =>
        WindowsProcessHost(
          conptyLibraryPath: conptyLibraryPath,
        ),
    };
