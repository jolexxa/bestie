// Standalone probe for the Linux (Landlock) filesystem jail.
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_linux/sandbox_linux.dart';

/// Broad system read roots so `/bin/sh` and coreutils can exec and load libc.
const _systemReadRoots = <String>[
  '/usr',
  '/bin',
  '/sbin',
  '/lib',
  '/lib64',
  '/etc',
  '/opt',
  '/dev',
  '/proc',
  '/sys',
  '/var',
  '/run',
];

/// Args:
///   write      workspace outside
///   devnull    workspace outside
///   read_deny  workspace roRoot denyFile
///   glob_deny  workspace roRoot denyGlob
///   list_hide  workspace roRoot denyDir
///
/// A deny is only carved from a *read-only* root: Landlock cannot subtract a
/// read from a read+write grant, so the deny scenarios read from `roRoot`, not
/// the writable workspace.
Future<void> main(List<String> args) async {
  final scenario = args[0];
  final workspace = args[1];

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
    'read_deny' || 'glob_deny' || 'list_hide' => SandboxSpec(
      workspaceRoot: workspace,
      readableRoots: [..._systemReadRoots, args[2]],
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
    SandboxLinux(fileSystem: const LocalFileSystem()),
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
          'printf outside > "${args[2]}/outside.txt"; true',
    'devnull' => 'printf x > /dev/null && printf NULL_WRITABLE; true',
    'read_deny' =>
      'cat "${args[2]}/sibling.txt"; echo; '
          'cat "${args[3]}" 2>/dev/null; true',
    'glob_deny' =>
      'cat "${args[2]}/secrets/allowed.txt"; echo; '
          'cat "${args[2]}/secrets/blocked.key" 2>/dev/null; true',
    'list_hide' =>
      'ls -A "${args[2]}"; echo; '
          'cat "${args[3]}/id" 2>/dev/null; echo; '
          'cat "${args[2]}/notes.txt"; true',
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
