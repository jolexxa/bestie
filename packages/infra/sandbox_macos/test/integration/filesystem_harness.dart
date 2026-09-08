// Standalone probe for the macOS filesystem jail.
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_macos/sandbox_macos.dart';

/// Broad system read roots so a real binary can exec and load dyld.
const _systemReadRoots = <String>[
  '/usr',
  '/bin',
  '/sbin',
  '/System',
  '/Library',
  '/dev',
  '/private',
  '/var',
  '/etc',
  '/opt',
];

Future<void> main(List<String> args) async {
  final scenario = args[0];
  final workspace = args[1];
  final outside = args[2];

  final spawner = await const RepoSpawnerLocator().locate();
  if (spawner == null) {
    stdout.writeln('SKIP: spawner not built (run melos run build:spawner)');
    return;
  }

  final spec = switch (scenario) {
    'write' || 'devnull' => SandboxSpec(
      workspaceRoot: workspace,
      readableRoots: _systemReadRoots,
      writableRoots: [workspace],
    ),
    'read_deny' || 'glob_deny' => SandboxSpec(
      workspaceRoot: workspace,
      readableRoots: _systemReadRoots,
      writableRoots: [workspace],
      deniedReads: [args[3]],
    ),
    _ => throw ArgumentError('unknown scenario: $scenario'),
  };

  final runner = ProcessRunner(
    host: PosixProcessHost(spawnerBinaryPath: spawner),
    environment: Platform.environment,
  );
  final probe = await ConfinedProbe.tryAcquire(
    SandboxMacos(fileSystem: const LocalFileSystem()),
    runner,
    spec,
  );
  if (probe == null) {
    stdout.writeln('SKIP: sandbox unavailable');
    return;
  }

  final script = switch (scenario) {
    'write' =>
      'printf inside > "$workspace/inside.txt"; '
          'printf outside > "$outside/outside.txt"; true',
    'devnull' => 'printf x > /dev/null && printf NULL_WRITABLE; true',
    'read_deny' =>
      'cat "$workspace/sibling.txt"; echo; cat "${args[3]}" 2>/dev/null; true',
    'glob_deny' =>
      'cat "$workspace/secrets/allowed.txt"; echo; '
          'cat "$workspace/secrets/blocked.key" 2>/dev/null; true',
    _ => 'true',
  };

  final result = await probe.runScript(script);
  switch (result) {
    case ProcessCaptureNotStarted(:final failure):
      stdout.writeln('FAIL: spawn refused ($failure)');
      exitCode = 1;
    case ProcessCaptureCompleted(stdout: final captured):
      stdout
        ..write(utf8.decode(captured, allowMalformed: true))
        ..writeln('\nDONE');
  }
}
